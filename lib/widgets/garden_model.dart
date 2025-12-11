import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// --- Global State for Available Plants (The in-app cache) ---
// This map will store the available plants from the 'plants' collection:
// Key: Plant Document ID (String)
// Value: PlantDB object (The full plant details)
Map<String, PlantDB> _globalPlantsDB = {};

// Getter to access the cached plant data
Map<String, PlantDB> get globalPlantsDB => _globalPlantsDB;

// --- Data Models ---

class PlantDB {
  final String id;
  final String name;
  final String
  rawBase64Url; // 🚨 Store the original string for debugging if needed
  final Uint8List decodedImageBytes; // 🚨 NEW: Store the decoded bytes
  final String description;
  final String waterFrequency;
  final String exposition;
  final String idealPeriod;
  final String soilType;
  final String curiosity;

  PlantDB({
    required this.id,
    required this.name,
    required this.rawBase64Url, // Updated
    required this.decodedImageBytes, // Added
    required this.description,
    required this.waterFrequency,
    required this.exposition,
    required this.idealPeriod,
    required this.soilType,
    required this.curiosity,
  });

  // 🚨 NEW: Create PlantDB from a Firestore Document Snapshot
  factory PlantDB.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final String base64Url = data['imageUrl'] as String;

    // Split and get the raw Base64 string
    final String rawBase64 = base64Url.split(',').last;

    // 💥 PERFORM DECODING ONCE HERE! 💥
    final Uint8List imageBytes = base64Decode(rawBase64);

    return PlantDB(
      id: doc.id,
      name: data['name'] as String,
      rawBase64Url: base64Url,
      decodedImageBytes: imageBytes, // Store the decoded bytes
      description: data['description'] as String,
      waterFrequency: data['waterFrequency'] as String,
      exposition: data['exposition'] as String,
      idealPeriod: data['idealPeriod'] as String,
      soilType: data['soilType'] as String,
      curiosity: data['curiosity'] as String,
    );
  }
}

// 🚨 MODIFIED MODEL: Represents a single plant instance in the garden
// Now only stores position, scale, and the ID linking to PlantDB
class PlantInstance {
  final String
  id; // Unique ID for this instance in the garden (timestamp/unique key)
  final String
  plantDbId; // 🚨 NEW: The ID of the plant in the central 'plants' DB
  Offset position; // The position on the screen
  double scale; // Scale factor for resizing

  PlantInstance({
    required this.id,
    required this.plantDbId, // Requires the DB ID
    required this.position,
    this.scale = 1.0,
  });

  // 🚨 MODIFIED: Convert PlantInstance to a Map for Firestore
  // Only saves 'plantDbId', 'position', and 'scale'
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plantDbId': plantDbId, // The reference ID
      // Store Offset as a map { 'dx': ..., 'dy': ... }
      'position': {'dx': position.dx, 'dy': position.dy},
      'scale': scale,
    };
  }

  // 🚨 MODIFIED: Create PlantInstance from a Map
  factory PlantInstance.fromJson(Map<String, dynamic> json) {
    return PlantInstance(
      id: json['id'] as String,
      plantDbId: json['plantDbId'] as String, // Load the reference ID
      position: Offset(
        (json['position']['dx'] as num).toDouble(),
        (json['position']['dy'] as num).toDouble(),
      ),
      scale: (json['scale'] as num).toDouble(),
    );
  }
}

// Represents a single virtual garden
class Garden {
  final String id;
  String name;
  String backgroundPattern; // Asset path for the background
  String? uid;
  List<PlantInstance> plants;

  // ... (Garden constructor and createDefault remain mostly the same, no changes needed)
  Garden({
    required this.id,
    required this.name,
    required this.backgroundPattern,
    this.uid,
    this.plants = const [],
  });

  factory Garden.createDefault(String id, String userUid) {
    final defaultPath = availableBackgrounds.first['path']!;

    return Garden(
      id: id,
      name: 'New Garden ${id.substring(0, 4)}',
      backgroundPattern: defaultPath,
      uid: userUid,
      plants: [],
    );
  }

  // 🚨 MODIFIED: Convert Garden to a Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'garden_id': id,
      'garden_name': name,
      'uid': uid,
      'backgroundPattern': backgroundPattern,
      // Convert the list of PlantInstance objects (which now only store IDs)
      'plants': plants.map((p) => p.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // 🚨 MODIFIED: Create Garden from a Map
  factory Garden.fromJson(Map<String, dynamic> json) {
    return Garden(
      id: json['garden_id'] as String,
      name: json['garden_name'] as String,
      backgroundPattern: json['backgroundPattern'] as String,
      uid: json['uid'] as String,
      plants: (json['plants'] as List)
          .map((p) => PlantInstance.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

// --- Data Fetching and Caching Logic ---

// 🚨 MODIFIED: Fetches all plants and populates the global cache
Future<void> fetchAndCacheAvailablePlants(FirebaseFirestore firestore) async {
  if (_globalPlantsDB.isNotEmpty) {
    // Already fetched, return early
    return;
  }
  try {
    print('Fetching and caching available plants from Firestore...');
    final snapshot = await firestore.collection('plants').get();

    // Clear the map before populating, just in case
    _globalPlantsDB = {};

    for (var doc in snapshot.docs) {
      final plantDb = PlantDB.fromFirestore(doc);
      _globalPlantsDB[plantDb.id] = plantDb;
    }
    print('Successfully cached ${_globalPlantsDB.length} plants.');
  } catch (e) {
    print('Error fetching and caching plants: $e');
    // Keep map empty on error
    _globalPlantsDB = {};
  }
}

// --- Mock Data/Assets (for demonstration) ---
const List<Map<String, String>> availableBackgrounds = [
  {'name': 'Pattern 1', 'path': 'assets/images/bgs/pattern_1.png'},
  {'name': 'Pattern 2', 'path': 'assets/images/bgs/pattern_2.png'},
  {'name': 'Pattern 3', 'path': 'assets/images/bgs/pattern_3.png'},
];

Future<void> saveGarden(
  User? user,
  Garden garden,
  FirebaseFirestore firestore,
  BuildContext context,
) async {
  if (user == null || garden.uid == null) {
    return;
  }

  try {
    await firestore
        .collection('users')
        .doc(user.uid)
        .collection('gardens')
        .doc(garden.id)
        .set(garden.toJson());

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Garden saved successfully!')));

    Navigator.of(context).pop(garden);
  } catch (e) {
    print("Error saving garden: $e");
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Error saving garden: $e')));
  }
}

Future<void> deleteGarden(
  User? user,
  String gardenId,
  FirebaseFirestore firestore,
  BuildContext context,
) async {
  if (user == null) return;

  try {
    await firestore
        .collection('users')
        .doc(user.uid)
        .collection('gardens')
        .doc(gardenId)
        .delete();

    // The StreamBuilder will automatically update the UI after deletion.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Garden deleted successfully!')),
    );
  } catch (e) {
    print('Error deleting garden: $e');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Failed to delete garden.')));
  }
}
