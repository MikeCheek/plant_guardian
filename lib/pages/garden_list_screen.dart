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

class _GardenListScreenState extends State<GardenListScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // 🟢 NEW: State and controller for FAB animation
  bool _isFabExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // --- Functions ---
  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _createNewGarden() {
    final user = _auth.currentUser;
    if (user == null) return; // User must be logged in

    _toggleFab(); // Close FAB after action

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

  // 🟢 NEW: Function to navigate to the NewPlantScreen
  void _openNewPlantScreen() {
    _toggleFab(); // Close FAB after action
    Navigator.of(context).pushNamed('/plants');
  }

  void _deleteGarden(String gardenId) async {
    await deleteGarden(_auth.currentUser, gardenId, _firestore, context);
  }

  // --- Widget Building Methods ---

  // 🟢 NEW: Builds a single action button with text label
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return ScaleTransition(
      scale: _scaleAnimation,
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            // Floating Action Button
            FloatingActionButton(
              heroTag: label, // Unique tag is required for multiple FABs
              mini: true,
              backgroundColor: color,
              onPressed: onTap,
              child: Icon(icon),
            ),
          ],
        ),
      ),
    );
  }

  // 🟢 NEW: Builds the column of expanded buttons
  Widget _buildExpandedFab() {
    if (!_isFabExpanded && _scaleAnimation.value == 0.0) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 1. Add New Plant Button
        _buildActionButton(
          icon: Icons.grass,
          label: 'Add New Plant',
          onTap: _openNewPlantScreen,
          color: Colors.green,
        ),
        // 2. Add New Garden Button
        _buildActionButton(
          icon: Icons.add_to_photos,
          label: 'Add New Garden',
          onTap: _createNewGarden,
          color: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(height: 10), // Space above the main toggle button
      ],
    );
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
          // ... (Existing StreamBuilder logic remains the same)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // ... (error handling and empty state)

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
              return Dismissible(
                key: Key(garden.id),
                direction: DismissDirection.endToStart,
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
                onDismissed: (direction) {
                  _deleteGarden(garden.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${garden.name} dismissed')),
                  );
                },
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

      // 🟢 NEW: Custom FAB position using Stack and Align
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildExpandedFab(), // The animated column of action buttons
          FloatingActionButton(
            heroTag: 'mainFab', // Unique tag for the main button
            onPressed: _toggleFab,
            // 🟢 Change icon based on state
            child: Icon(_isFabExpanded ? Icons.close : Icons.add),
          ),
        ],
      ),
    );
  }
}
