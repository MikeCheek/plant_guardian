import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// --- Data Models ---

// Represents a single plant instance in the garden
class PlantInstance {
  final String id;
  final String name; // e.g., "Fiddle Leaf Fig"
  final String imagePath; // Asset path for the plant image
  Offset position; // The position on the screen
  double scale; // Scale factor for resizing (optional, but good practice)

  PlantInstance({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.position,
    this.scale = 1.0,
  });

  // 🚨 NEW: Convert PlantInstance to a Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      // Store Offset as a map { 'dx': ..., 'dy': ... }
      'position': {'dx': position.dx, 'dy': position.dy},
      'scale': scale,
    };
  }

  // 🚨 NEW: Create PlantInstance from a Map
  factory PlantInstance.fromJson(Map<String, dynamic> json) {
    return PlantInstance(
      id: json['id'] as String,
      name: json['name'] as String,
      imagePath: json['imagePath'] as String,
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
  String? uid; // 🚨 NEW: Field to link garden to the user UID
  List<PlantInstance> plants;

  Garden({
    required this.id,
    required this.name,
    required this.backgroundPattern,
    this.uid, // Make UID optional for the constructor
    this.plants = const [],
  });

  // Simple factory to create a default new garden
  factory Garden.createDefault(String id, String userUid) {
    // Assuming availableBackgrounds is defined here or imported
    final defaultPath = availableBackgrounds.first['path']!;

    return Garden(
      id: id,
      name: 'New Garden ${id.substring(0, 4)}',
      backgroundPattern: defaultPath,
      uid: userUid, // Set the UID here
      plants: [],
    );
  }

  // 🚨 NEW: Convert Garden to a Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'garden_id': id, // Matching your requested field name
      'garden_name': name, // Matching your requested field name
      'uid': uid, // The user ID
      'backgroundPattern': backgroundPattern,
      // Convert the list of PlantInstance objects to a list of Maps
      'plants': plants.map((p) => p.toJson()).toList(),
      'updatedAt':
          FieldValue.serverTimestamp(), // Optional, but good for tracking
    };
  }

  // 🚨 NEW: Create Garden from a Map
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

// --- Mock Data/Assets (for demonstration) ---
// In a real app, this data would come from Firestore or a local database.

const List<Map<String, String>> availablePlants = [
  {'name': 'Aloe Vera', 'path': 'assets/images/plants/aloe-vera.png'},
  {'name': 'Areca Palm', 'path': 'assets/images/plants/areca-palm.png'},
  {'name': 'Aspargus Fern', 'path': 'assets/images/plants/asparagus-fern.png'},
  {'name': 'Anthurium', 'path': 'assets/images/plants/anthurium.png'},
  {'name': 'African Violet', 'path': 'assets/images/plants/african-violet.png'},
  {'name': 'Alocasia', 'path': 'assets/images/plants/alocasia.png'},
  {'name': 'Fiddle Leaf Fig', 'path': 'assets/images/plants/fig.png'},
  {'name': 'Monstera', 'path': 'assets/images/plants/monstera.png'},
  {'name': 'Peperomia', 'path': 'assets/images/plants/peperromia.png'},
  {'name': 'Spider Plant', 'path': 'assets/images/plants/spider-plant.png'},
  {'name': 'Succulent', 'path': 'assets/images/plants/succulent.png'},
];

const List<Map<String, String>> availableBackgrounds = [
  {'name': 'Pattern 1', 'path': 'assets/images/bgs/pattern_1.png'},
  {'name': 'Pattern 2', 'path': 'assets/images/bgs/pattern_2.png'},
  {'name': 'Pattern 3', 'path': 'assets/images/bgs/pattern_3.png'},
];

void saveGarden(
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
