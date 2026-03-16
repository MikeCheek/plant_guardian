import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  static const List<IconData> _gardenIcons = [
    Icons.yard_rounded,
    Icons.local_florist,
    Icons.park,
    Icons.eco,
    Icons.grass,
    Icons.spa,
    Icons.forest,
    Icons.compost,
  ];

  // 🟢 NEW: State and controller for FAB animation
  bool _isFabExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  bool _isAnyPlantThirsty(List<PlantInstance> plants) {
    for (var plant in plants) {
      bool thirsty = isPlantThirsty(plant);
      if (thirsty) {
        return true;
      }
    }
    return false;
  }

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

    openGardenEditor(context, newGarden);
  }

  // 🟢 NEW: Function to navigate to the NewPlantScreen
  void _openNewPlantScreen() {
    _toggleFab(); // Close FAB after action
    Navigator.of(context).pushNamed('/plants');
  }

  void _deleteGarden(String gardenId) async {
    await deleteGarden(_auth.currentUser, gardenId, _firestore, context);
  }

  IconData _iconForGarden(Garden garden) {
    return IconData(
      garden.iconCodePoint ?? Icons.yard_rounded.codePoint,
      fontFamily: 'MaterialIcons',
    );
  }

  Future<void> _renameGarden(Garden garden) async {
    final controller = TextEditingController(text: garden.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Garden'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 30,
            decoration: const InputDecoration(labelText: 'Garden name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );

    if (newName == null || newName.isEmpty || newName == garden.name) return;

    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('gardens')
        .doc(garden.id)
        .update({
          'garden_name': newName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> _changeGardenIcon(Garden garden) async {
    final selectedIcon = await showModalBottomSheet<IconData>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: _gardenIcons.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                final icon = _gardenIcons[index];
                final isSelected =
                    garden.iconCodePoint == icon.codePoint ||
                    (garden.iconCodePoint == null &&
                        icon.codePoint == Icons.yard_rounded.codePoint);

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).pop(icon),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Icon(icon, size: 30),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (selectedIcon == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('gardens')
        .doc(garden.id)
        .update({
          'garden_icon': selectedIcon.codePoint,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> _confirmDeleteGarden(Garden garden) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
            "Are you sure you want to delete '${garden.name}'? This cannot be undone.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'DELETE',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _deleteGarden(garden.id);
    }
  }

  Future<void> _showGardenActions(Garden garden) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename garden'),
                onTap: () => Navigator.of(context).pop('rename'),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Change icon'),
                onTap: () => Navigator.of(context).pop('icon'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete garden'),
                textColor: Colors.red,
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            ],
          ),
        );
      },
    );

    if (action == 'rename') {
      await _renameGarden(garden);
    } else if (action == 'icon') {
      await _changeGardenIcon(garden);
    } else if (action == 'delete') {
      await _confirmDeleteGarden(garden);
    }
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
          crossAxisAlignment: CrossAxisAlignment.center,
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
              child: Icon(icon, color: Colors.white),
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
      body: StreamBuilder<List<Garden>>(
        stream: gardensStream(user.uid, _firestore),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading gardens: ${snapshot.error}'),
            );
          }

          final gardens = snapshot.data ?? [];

          if (gardens.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "You haven't created any gardens yet!",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            // SliverGridDelegateWithFixedCrossAxisCount makes them squared
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 2 items per row
              crossAxisSpacing: 16, // Horizontal space between squares
              mainAxisSpacing: 16, // Vertical space between squares
              childAspectRatio: 1, // 1 means perfectly square (width = height)
            ),
            itemCount: gardens.length,
            itemBuilder: (context, index) {
              final garden = gardens[index];
              final bool hasThirstyPlants = _isAnyPlantThirsty(garden.plants);

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    InkWell(
                      onTap: () => openGardenEditor(context, garden),
                      onLongPress: () => _showGardenActions(garden),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Icon or Background Preview
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).secondaryHeaderColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _iconForGarden(garden),
                              size: 40,
                              color: Theme.of(context).secondaryHeaderColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Garden Name
                          Text(
                            garden.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Plant Count
                          Text(
                            '${garden.plants.length} plants',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Long press for options',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasThirstyPlants)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.water_drop, // The drop icon
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
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
