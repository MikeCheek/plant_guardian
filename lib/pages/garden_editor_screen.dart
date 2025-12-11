import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import 'package:plant_guardian/widgets/garden_model.dart';

class GardenEditorScreen extends StatefulWidget {
  final Garden garden;
  const GardenEditorScreen({super.key, required this.garden});

  @override
  State<GardenEditorScreen> createState() => _GardenEditorScreenState();
}

class _GardenEditorScreenState extends State<GardenEditorScreen> {
  late Garden _currentGarden;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? _selectedPlantId;

  double _baseScaleFactor = 1.0;

  @override
  void initState() {
    super.initState();
    _currentGarden = widget.garden;

    _currentGarden.uid ??= _auth.currentUser?.uid;
  }

  PlantInstance? firstWhereOrNull(
    Iterable<PlantInstance> plants,
    bool Function(PlantInstance) test,
  ) {
    for (final plant in plants) {
      if (test(plant)) return plant;
    }
    return null;
  }

  PlantInstance? get _selectedPlant {
    if (_selectedPlantId == null) return null;
    // Using where/firstWhere to safely find the selected plant
    return firstWhereOrNull(
      _currentGarden.plants,
      (p) => p.id == _selectedPlantId,
    );
  }

  void _changeBackground(BuildContext context) {
    showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Background Pattern'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableBackgrounds.map((pattern) {
            final String? name = pattern['name'];
            final String? path = pattern['path'];

            return ListTile(
              title: Text(name ?? 'Unknown'),
              leading: path != null
                  ? Image.asset(path, width: 40, height: 40, fit: BoxFit.cover)
                  : const Icon(Icons.image),
              onTap: () => Navigator.of(context).pop(path),
            );
          }).toList(),
        ),
      ),
    ).then((selectedPattern) {
      if (selectedPattern != null) {
        setState(() {
          _currentGarden.backgroundPattern = selectedPattern;
        });
      }
    });
  }

  // 1. Adds a new plant to the garden
  void _addNewPlant(BuildContext context) {
    showDialog<PlantInstance>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select a Plant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availablePlants.map((plantData) {
            return ListTile(
              title: Text(plantData['name']!),
              leading: const Icon(Icons.local_florist),
              onTap: () {
                final newPlant = PlantInstance(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  name: plantData['name']!,
                  imagePath: plantData['path']!,
                  // Initial position random in the screen
                  position: Offset(
                    50 + Random().nextDouble() * 200,
                    50 + Random().nextDouble() * 400,
                  ),
                  scale: 1.7,
                );
                Navigator.of(context).pop(newPlant);
              },
            );
          }).toList(),
        ),
      ),
    ).then((newPlant) {
      if (newPlant != null) {
        setState(() {
          _currentGarden.plants = [..._currentGarden.plants, newPlant];
          _selectedPlantId = newPlant.id;
        });
      }
    });
  }

  void _saveGarden() async {
    saveGarden(_auth.currentUser, _currentGarden, _firestore, context);
  }

  void _handleGlobalScale(ScaleUpdateDetails details) {
    if (_selectedPlant == null) {
      return; // Pinch does nothing if nothing is selected
    }

    if (details.scale != 1.0) {
      setState(() {
        double newScale = _baseScaleFactor * details.scale;
        _selectedPlant!.scale = max(1.0, min(4.0, newScale));
      });
    }
  }

  // 4. Deletes the currently selected plant
  void _deleteSelectedPlant() {
    if (_selectedPlantId == null) return;

    setState(() {
      _currentGarden.plants.removeWhere((p) => p.id == _selectedPlantId);
      _selectedPlantId = null; // Deselect after deletion
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Plant removed from garden.')));
  }

  // 5. Helper to apply screen bounds
  Offset _applyBounds(
    Offset newPosition,
    Size screenSize,
    PlantInstance plant,
  ) {
    // Approximate size of the plant widget (50 * scale, centered)
    final double plantSize = 50 * plant.scale;
    final double halfPlantSize = plantSize / 2;

    // Calculate effective bounds:
    // Min X (Left side): Can't go less than 0
    final double minX = 0;
    // Max X (Right side): Screen width minus the width of the plant
    final double maxX = screenSize.width - plantSize;

    // Min Y (Top side): Can't go less than the top safe area (like AppBar)
    final double minY = 0;
    // Max Y (Bottom side): Screen height minus the height of the plant and some bottom margin
    final double maxY =
        screenSize.height -
        kToolbarHeight -
        plantSize -
        100; // 100 for FAB/Bottom Padding

    // Clamp the new position
    final clampedX = max(minX, min(maxX, newPosition.dx));
    final clampedY = max(minY, min(maxY, newPosition.dy));

    return Offset(clampedX, clampedY);
  }

  // Omitted: _changeBackground, _saveGarden, _handleGlobalScale (unchanged)

  // --- Widget Building Methods ---

  Widget _buildDeleteButton() {
    if (_selectedPlantId == null) {
      return Container();
    }

    return Positioned(
      bottom: 20, // Positioned above the FAB on the left
      left: 16,
      child: FloatingActionButton(
        heroTag: 'deleteBtn',
        onPressed: _deleteSelectedPlant,
        backgroundColor: Colors.red[700],
        child: const Icon(Icons.delete_forever, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the screen size for bounding calculations
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: TextFormField(
          initialValue: _currentGarden.name,
          onChanged: (newName) => _currentGarden.name = newName,
          style: const TextStyle(color: Colors.white, fontSize: 20),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Garden Name',
            hintStyle: TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          // Omitted: AppBar actions
          IconButton(
            icon: const Icon(Icons.wallpaper),
            tooltip: 'Change Background',
            onPressed: () => _changeBackground(context),
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Garden',
            onPressed: _saveGarden,
          ),
        ],
      ),
      // --- Interactive Garden Area ---
      body: GestureDetector(
        // When tapping the background, deselect the plant
        onTap: () {
          setState(() {
            _selectedPlantId = null;
          });
        },

        onScaleStart: (details) {
          if (_selectedPlant != null) {
            _baseScaleFactor = _selectedPlant!.scale;
          }
        },
        onScaleUpdate: _handleGlobalScale,

        child: Stack(
          children: [
            Positioned.fill(
              child: _currentGarden.backgroundPattern.isNotEmpty
                  ? Image.asset(
                      _currentGarden.backgroundPattern,
                      fit: BoxFit.cover,
                    )
                  : Container(color: Colors.green[100]),
            ),

            ..._currentGarden.plants.map((plant) {
              final isSelected = plant.id == _selectedPlantId;

              return Positioned(
                left: plant.position.dx,
                top: plant.position.dy,
                // 🛑 CORRECTED FIX: Remove IgnorePointer and use isDragEnabled on Draggable
                child: isSelected
                    ? Draggable(
                        data: plant,
                        // 🟢 New: Only allow drag functionality when the plant is selected
                        feedback: Opacity(
                          opacity: 0.7,
                          child: Image.asset(
                            plant.imagePath,
                            width: 50 * plant.scale,
                            height: 50 * plant.scale,
                          ),
                        ),
                        childWhenDragging: Container(),

                        child: GestureDetector(
                          // The GestureDetector is always enabled to handle selection
                          onTap: () {
                            setState(() {
                              // Tapping a plant always selects it
                              _selectedPlantId = plant.id;
                            });
                          },
                          child: Container(
                            decoration: isSelected
                                ? BoxDecoration(
                                    border: Border.all(
                                      color: Colors.blueAccent,
                                      width: 3,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  )
                                : null,
                            padding: const EdgeInsets.all(5),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  plant.imagePath,
                                  width: 50 * plant.scale,
                                  height: 50 * plant.scale,
                                ),
                                Text(
                                  plant.name,
                                  style: TextStyle(
                                    fontSize: 6 * plant.scale,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.blueAccent
                                        : Colors.white,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.blueAccent,
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),

                        onDraggableCanceled: (velocity, offset) {
                          // ... (existing DraggableCanceled logic for boundary application)
                          final double appBarHeight =
                              AppBar().preferredSize.height +
                              MediaQuery.of(context)
                                  .padding
                                  .top; // Total space taken by app bar and safe area

                          final newBodyOffset = Offset(
                            offset.dx,
                            offset.dy - appBarHeight,
                          );

                          setState(() {
                            // Apply bounds to the new position
                            plant.position = _applyBounds(
                              newBodyOffset,
                              screenSize,
                              plant,
                            );
                          });
                        },
                      )
                    : GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPlantId = plant.id;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            plant.imagePath,
                            width: 50 * plant.scale,
                            height: 50 * plant.scale,
                          ),
                        ),
                      ),
              );
            }),

            // OPTIONAL: Overlay hint for the user (Keep this, but it will be slightly above the delete button)
            if (_selectedPlantId != null)
              Positioned(
                bottom: 90, // Raised higher to clear the new Delete FAB
                left: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_selectedPlant?.name ?? 'Plant'} selected. Drag to move, or pinch to scale.',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // 🛑 FIX 3: Add the delete button conditionally
            _buildDeleteButton(),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNewPlant(context),
        tooltip: 'Add Plant',
        child: const Icon(Icons.local_florist),
      ),
    );
  }
}
