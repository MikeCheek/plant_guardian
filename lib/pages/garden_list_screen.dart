import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:plant_guardian/pages/garden_editor_screen.dart';
import 'package:plant_guardian/widgets/garden_model.dart';

class GardenListScreen extends StatefulWidget {
  const GardenListScreen({super.key});

  @override
  State<GardenListScreen> createState() => _GardenListScreenState();
}

class _GardenListScreenState extends State<GardenListScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // --- Functions ---
  void _createNewGarden() {
    final user = _auth.currentUser;
    if (user == null) return; // User must be logged in

    final String newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newGarden = Garden.createDefault(newId, user.uid);

    _openGardenEditor(newGarden);
  }

  void _openGardenEditor(Garden garden) async {
    await Navigator.of(context).push<Garden>(
      MaterialPageRoute(
        builder: (context) => GardenEditorScreen(garden: garden),
      ),
    );
  }

  // 🚨 NEW FUNCTION: Deletes the garden from Firestore
  void _deleteGarden(String gardenId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
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

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to manage your gardens.")),
      );
    }

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(user.uid)
            .collection('gardens')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading gardens: ${snapshot.error}'),
            );
          }

          final gardens = snapshot.data!.docs.map((doc) {
            return Garden.fromJson(doc.data() as Map<String, dynamic>);
          }).toList();

          if (gardens.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "You haven't created any gardens yet!",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _createNewGarden,
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Garden'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
            itemCount: gardens.length,
            itemBuilder: (context, index) {
              final garden = gardens[index];

              // 🚨 NEW: Wrap the item in Dismissible for the slide gesture
              return Dismissible(
                key: Key(garden.id), // Unique key is required for Dismissible
                direction: DismissDirection
                    .endToStart, // Only allow swiping right-to-left
                // Background shown when sliding
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20.0),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),

                // Action to perform when dismissed
                onDismissed: (direction) {
                  // Call the function to delete from Firestore
                  _deleteGarden(garden.id);
                  // Optional: Show a temporary message to confirm the deletion
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${garden.name} dismissed')),
                  );
                },

                // The actual list item content (your existing Card)
                child: Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.grass),
                    title: Text(garden.name),
                    subtitle: Text('${garden.plants.length} plants'),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _openGardenEditor(garden),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewGarden,
        child: const Icon(Icons.add),
      ),
    );
  }
}
