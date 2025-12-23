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

  // 🚨 MODIFIED: Replaced the Future for fetching with a Future that handles caching
  late Future<void> _plantsFuture;

  @override
  void initState() {
    super.initState();
    _currentGarden = widget.garden;
    _currentGarden.uid ??= _auth.currentUser?.uid;

    // 🚨 FIX 1: Start fetching and caching the plant data immediately
    _plantsFuture = fetchAndCacheAvailablePlants(_firestore);
  }

  // 🚨 MODIFIED: Helper to retrieve the PlantDB details from the cache
  PlantDB? _getPlantDB(String plantDbId) {
    return globalPlantsDB[plantDbId];
  }

  // Helper function (left unchanged)
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
    final availablePlants = globalPlantsDB.entries.toList();

    if (availablePlants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plant data is still loading...')),
      );
      return;
    }

    // List for searching
    List<MapEntry<String, PlantDB>> filteredPlants = List.from(availablePlants);

    showDialog<PlantInstance>(
      context: context,
      builder: (context) => StatefulBuilder(
        // Use StatefulBuilder to handle search filtering inside dialog
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Select a Plant'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400, // Fixed height for the scrollable area
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search plants...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        filteredPlants = availablePlants
                            .where(
                              (entry) => entry.value.name
                                  .toLowerCase()
                                  .contains(value.toLowerCase()),
                            )
                            .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  // Scrollable List
                  Expanded(
                    child: filteredPlants.isEmpty
                        ? const Center(child: Text("No plants found"))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredPlants.length,
                            itemBuilder: (context, index) {
                              final plantEntry = filteredPlants[index];
                              final plantDb = plantEntry.value;

                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.memory(
                                    plantDb.decodedImageBytes,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) =>
                                        const Icon(Icons.local_florist),
                                  ),
                                ),
                                title: Text(plantDb.name),
                                subtitle: Text(
                                  plantDb.exposition,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onTap: () {
                                  final newPlantInstance = PlantInstance(
                                    id: DateTime.now().microsecondsSinceEpoch
                                        .toString(),
                                    plantDbId: plantDb.id,
                                    position: Offset(
                                      50 + Random().nextDouble() * 100,
                                      50 + Random().nextDouble() * 200,
                                    ),
                                    scale: 1.7,
                                  );
                                  Navigator.of(context).pop(newPlantInstance);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
            ],
          );
        },
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
    await saveGarden(_auth.currentUser, _currentGarden, _firestore, context);
  }

  void _handleGlobalScale(ScaleUpdateDetails details) {
    if (_selectedPlant == null) {
      return;
    }

    if (details.scale != 1.0) {
      setState(() {
        double newScale = _baseScaleFactor * details.scale;
        _selectedPlant!.scale = max(1.0, min(4.0, newScale));
      });
    }
  }

  void _deleteSelectedPlant() {
    if (_selectedPlantId == null) return;

    setState(() {
      _currentGarden.plants.removeWhere((p) => p.id == _selectedPlantId);
      _selectedPlantId = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Plant removed from garden.')));
  }

  Offset _applyBounds(
    Offset newPosition,
    Size screenSize,
    PlantInstance plant,
  ) {
    final double plantSize = 50 * plant.scale;
    final double minX = 0;
    final double maxX = screenSize.width - plantSize;
    final double minY = 0;
    final double maxY = screenSize.height - kToolbarHeight - plantSize - 100;

    final clampedX = max(minX, min(maxX, newPosition.dx));
    final clampedY = max(minY, min(maxY, newPosition.dy));

    return Offset(clampedX, clampedY);
  }

  Widget _buildPlantImage(PlantInstance plant) {
    final plantDb = _getPlantDB(plant.plantDbId);

    if (plantDb == null) {
      return const Icon(Icons.error, color: Colors.red);
    }

    // 💥 FIX: Use the pre-decoded bytes directly from the PlantDB object 💥
    return Image.memory(
      plantDb.decodedImageBytes, // Now using Uint8List directly
      width: 50 * plant.scale,
      height: 50 * plant.scale,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        // ... (AppBar content - no changes)
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

      // 🚨 FIX 3: Wrap the main body in FutureBuilder to wait for plants cache
      body: FutureBuilder<void>(
        future: _plantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || globalPlantsDB.isEmpty) {
            return const Center(child: Text('Failed to load plant database.'));
          }

          // Once the future is complete, build the interactive garden
          return GestureDetector(
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

                // 🚨 FIX 4: Use the cached PlantDB data to render each plant
                ..._currentGarden.plants.map((plant) {
                  final plantDb = _getPlantDB(plant.plantDbId);
                  if (plantDb == null) {
                    // Skip rendering plants that can't be found in the database
                    return Container();
                  }

                  final isSelected = plant.id == _selectedPlantId;

                  return Positioned(
                    left: plant.position.dx,
                    top: plant.position.dy,
                    child: isSelected
                        ? Draggable(
                            data: plant,
                            feedback: Opacity(
                              opacity: 0.7,
                              child: _buildPlantImage(
                                plant,
                              ), // Use the image builder
                            ),
                            childWhenDragging: Container(),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedPlantId = plant.id;
                                });
                              },
                              onDoubleTap: () {
                                if (_selectedPlant != null) {
                                  Navigator.of(context).pushNamed(
                                    '/plant',
                                    arguments: _selectedPlant!.plantDbId,
                                  );
                                }
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
                                    _buildPlantImage(
                                      plant,
                                    ), // Use the image builder
                                    Text(
                                      plantDb.name,
                                      style: TextStyle(
                                        fontSize: 5 * plant.scale,
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

                                        // make it not going outside the image
                                        // going to new line when needed
                                        overflow: TextOverflow.fade,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            onDraggableCanceled: (velocity, offset) {
                              final double appBarHeight =
                                  AppBar().preferredSize.height +
                                  MediaQuery.of(context).padding.top;

                              final double imageHeight = 50 * plant.scale;

                              final newBodyOffset = Offset(
                                offset.dx,
                                offset.dy - appBarHeight - imageHeight / 2,
                              );

                              setState(() {
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
                              child: _buildPlantImage(
                                plant,
                              ), // Use the image builder
                            ),
                          ),
                  );
                }).toList(),

                if (_selectedPlantId != null)
                  Positioned(
                    bottom: 110,
                    left: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        // 🚨 Use the name from the cached PlantDB object
                        '${_getPlantDB(_selectedPlant!.plantDbId)?.name ?? 'Plant'} selected. Drag to move, or pinch to scale.',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),

      floatingActionButton: SizedBox(
        height: kBottomNavigationBarHeight + 20,
        width: double.maxFinite,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            // Keep spaceBetween to push the Add button to the right
            mainAxisAlignment: _selectedPlantId != null
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.end,
            children: [
              if (_selectedPlantId != null)
                Padding(
                  padding: EdgeInsets.only(left: 32.0),
                  child: FloatingActionButton(
                    heroTag: 'deleteBtn',
                    onPressed: _deleteSelectedPlant,
                    backgroundColor: Colors.red[700],
                    child: const Icon(
                      Icons.delete_forever,
                      color: Colors.white,
                    ),
                  ),
                ),
              FloatingActionButton(
                heroTag: 'addBtn', // Add a heroTag for safety
                onPressed: () => _addNewPlant(context),
                tooltip: 'Add Plant',
                child: const Icon(Icons.local_florist),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
