import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:plant_guardian/pages/garden_editor_screen.dart';
import 'package:plant_guardian/services/notification_service.dart';

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
  final int waterDaysFrequency;
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
    required this.waterDaysFrequency,
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
      waterDaysFrequency: data['waterDaysFrequency'] as int,
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
  DateTime? lastWatered;

  PlantInstance({
    required this.id,
    required this.plantDbId, // Requires the DB ID
    required this.position,
    this.scale = 1.0,
    this.lastWatered,
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
      'lastWatered': lastWatered != null
          ? Timestamp.fromDate(lastWatered!)
          : null,
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
      lastWatered: json['lastWatered'] != null
          ? (json['lastWatered'] as Timestamp).toDate()
          : null,
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

  static fromMap(Map<String, dynamic> data, String id) {
    return Garden(
      id: id,
      name: data['garden_name'] as String,
      backgroundPattern: data['backgroundPattern'] as String,
      uid: data['uid'] as String,
      plants: (data['plants'] as List)
          .map((p) => PlantInstance.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

// --- Data Fetching and Caching Logic ---
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

Future<void> preloadGardenInfo(User? user, FirebaseFirestore firestore) async {
  if (user == null) return;

  try {
    print('Preloading garden information...');

    // Preload all available plants
    await fetchAndCacheAvailablePlants(firestore);

    // Preload user's gardens
    await firestore
        .collection('users')
        .doc(user.uid)
        .collection('gardens')
        .get();

    print('Garden information preloaded successfully.');
  } catch (e) {
    print('Error preloading garden information: $e');
  }
}

PlantDB? getPlantByName(String name) {
  if (name.isEmpty) return null;

  // 1. Sanitize the search term: lowercase, trim, and replace underscores/dashes with spaces
  final cleanSearchName = name.toLowerCase().trim().replaceAll(
    RegExp(r'[_-]'),
    ' ',
  );

  // 2. Try Exact Match first (it's the most accurate)
  for (var plant in globalPlantsDB.values) {
    final cleanPlantName = plant.name.toLowerCase().trim().replaceAll(
      RegExp(r'[_-]'),
      ' ',
    );

    if (cleanPlantName == cleanSearchName) {
      return plant;
    }
  }

  // 3. FALLBACK: Fuzzy/Partial Match
  // This helps if the AI says "Tomato Bacterial Spot" but your DB only has "Tomato"
  for (var plant in globalPlantsDB.values) {
    final cleanPlantName = plant.name.toLowerCase().trim().replaceAll(
      RegExp(r'[_-]'),
      ' ',
    );

    if (cleanSearchName.contains(cleanPlantName) ||
        cleanPlantName.contains(cleanSearchName)) {
      debugPrint("Fuzzy match found: AI: $name -> DB: ${plant.name}");
      return plant;
    }
  }

  debugPrint("No match found in DB for: $name");
  return null;
}

Stream<List<Garden>> gardensStream(
  String userId,
  FirebaseFirestore firestore,
) async* {
  yield* firestore
      .collection('users')
      .doc(userId)
      .collection('gardens')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) => Garden.fromJson(doc.data())).toList();
      });
}

void openGardenEditor(BuildContext context, Garden garden) async {
  await Navigator.of(context).push<Garden>(
    MaterialPageRoute(builder: (context) => GardenEditorScreen(garden: garden)),
  );
}

bool isPlantThirsty(PlantInstance plant) {
  final plantDb = globalPlantsDB[plant.plantDbId];
  if (plantDb == null) return false;

  // Extract number of days from frequency string (e.g., "Every 3 days" -> 3)
  final int frequencyDays = plantDb.waterDaysFrequency;

  final lastWatered =
      plant.lastWatered ?? DateTime.fromMillisecondsSinceEpoch(0);
  final difference = DateTime.now().difference(lastWatered).inDays;

  return difference >= frequencyDays;
}

Future<void> checkWateringNeedsAndNotify(String userId) async {
  final firestore = FirebaseFirestore.instance;

  // 1. Ensure DB cache is ready
  await fetchAndCacheAvailablePlants(firestore);

  // 2. Fetch all gardens for this user
  final gardensSnapshot = await firestore
      .collection('users')
      .doc(userId)
      .collection('gardens')
      .get();

  List<String> plantsToWater = [];

  for (var gardenDoc in gardensSnapshot.docs) {
    final garden = Garden.fromJson(gardenDoc.data());

    for (var instance in garden.plants) {
      final plantDb = globalPlantsDB[instance.plantDbId];
      if (plantDb == null) continue;

      // Logic: If never watered, it's thirsty.
      // Otherwise, check if (Now - lastWatered) > frequency
      bool needsWater = isPlantThirsty(instance);

      if (needsWater) {
        plantsToWater.add("${plantDb.name} (${garden.name})");
      }
    }
  }

  if (plantsToWater.isNotEmpty) {
    _showThirstyNotification(plantsToWater);
  }
}

// // Simple parser: looks for numbers in strings like "Every 3 days" or "Once a week"
// int _parseFrequencyToDays(String freq) {
//   final numberMatch = RegExp(r'\d+').firstMatch(freq);
//   if (numberMatch != null) return int.parse(numberMatch.group(0)!);
//   if (freq.toLowerCase().contains('week')) return 7;
//   return 3; // Default fallback
// }

// 2. Show the notification with the button
Future<void> _showThirstyNotification(List<String> names) async {
  const androidDetails = AndroidNotificationDetails(
    'watering_id',
    'Plant Care',
    importance: Importance.max,
    priority: Priority.high,
    actions: [
      AndroidNotificationAction(
        'watered_action',
        'Mark all as Watered',
        showsUserInterface: true,
      ),
    ],
  );

  await NotificationService().showInstantNotification(
    id: 100,
    title: "Time to Water! 💧",
    body: "These plants need love: ${names.join(', ')}",
    notificationDetails: const NotificationDetails(android: androidDetails),
    payload: jsonEncode({
      "type": "bulk_water",
    }), // Pass IDs here to identify which plants
  );
}

Future<void> waterPlant(String gardenId, String plantId, String userId) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('gardens')
      .doc(gardenId)
      .get()
      .then((doc) async {
        if (doc.exists) {
          Garden garden = Garden.fromJson(doc.data()!);
          // Update the specific plant instance
          for (var plant in garden.plants) {
            if (plant.id == plantId) {
              plant.lastWatered = DateTime.now();
            }
          }
          // Save back to Firestore
          await doc.reference.update(garden.toJson());
        }
      });
}
