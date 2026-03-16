import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import 'package:plant_guardian/widgets/garden_model.dart';
import 'package:plant_guardian/widgets/plant.dart';

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
  bool _isWateringMode = false;

  late Future<void> _plantsFuture;

  @override
  void initState() {
    super.initState();
    _currentGarden = widget.garden;
    _currentGarden.uid ??= _auth.currentUser?.uid;
    _plantsFuture = fetchAndCacheAvailablePlants(_firestore);
  }

  PlantDB? _getPlantDB(String plantDbId) {
    return globalPlantsDB[plantDbId];
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

  void _markAsWatered(PlantInstance plant) {
    waterPlant(
      _currentGarden.id,
      plant.id,
      _currentGarden.uid ?? _auth.currentUser?.uid ?? '',
    );
    setState(() {
      plant.lastWatered = DateTime.now();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${getPlantDisplayName(plant)} watered! 💧')),
    );
  }

  Future<String?> _askForNickname({
    String? initialNickname,
    required String basePlantName,
    bool isEditing = false,
  }) async {
    final controller = TextEditingController(text: initialNickname ?? '');

    final nickname = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isEditing ? 'Edit plant nickname' : 'Give your plant a nickname',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Optional (e.g., $basePlantName Jr.)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(isEditing ? 'Keep Current' : 'Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final cleaned = nickname?.trim();
    if (cleaned == null || cleaned.isEmpty) return null;
    return cleaned;
  }

  Future<void> _editSelectedPlantNickname() async {
    final plant = _selectedPlant;
    if (plant == null) return;

    final plantDb = _getPlantDB(plant.plantDbId);
    final basePlantName = plantDb?.name.split('(')[0].trim() ?? 'Plant';

    final newNickname = await _askForNickname(
      initialNickname: plant.nickname,
      basePlantName: basePlantName,
      isEditing: true,
    );

    if (!mounted) return;

    setState(() {
      plant.nickname = newNickname;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nickname updated for ${getPlantDisplayName(plant)}.'),
      ),
    );
  }

  void _addNewPlant(BuildContext context) {
    final availablePlants = globalPlantsDB.entries.toList();

    if (availablePlants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plant data is still loading...')),
      );
      return;
    }

    List<MapEntry<String, PlantDB>> filteredPlants = List.from(availablePlants);

    showDialog<PlantInstance>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Select a Plant'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
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
                                title: Text(plantDb.name.split('(')[0].trim()),
                                subtitle: Text(
                                  plantDb.description,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onTap: () async {
                                  final nickname = await _askForNickname(
                                    basePlantName: plantDb.name
                                        .split('(')[0]
                                        .trim(),
                                  );
                                  if (!context.mounted) return;

                                  final newPlantInstance = PlantInstance(
                                    id: DateTime.now().microsecondsSinceEpoch
                                        .toString(),
                                    plantDbId: plantDb.id,
                                    position: Offset(
                                      50 + Random().nextDouble() * 100,
                                      50 + Random().nextDouble() * 200,
                                    ),
                                    scale: 1.7,
                                    nickname: nickname,
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
    if (_selectedPlant == null || details.scale == 1.0) {
      return;
    }

    setState(() {
      double newScale = _baseScaleFactor * details.scale;
      _selectedPlant!.scale = max(1.0, min(4.0, newScale));
    });
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: _GardenAppBar(
        gardenName: _currentGarden.name,
        isWateringMode: _isWateringMode,
        onNameChanged: (newName) => _currentGarden.name = newName,
        onBackgroundPressed: () => _changeBackground(context),
        onSavePressed: _saveGarden,
      ),
      body: FutureBuilder<void>(
        future: _plantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || globalPlantsDB.isEmpty) {
            return const Center(child: Text('Failed to load plant database.'));
          }

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
                _GardenBackground(
                  backgroundPattern: _currentGarden.backgroundPattern,
                ),
                ..._currentGarden.plants.map((plant) {
                  final plantDb = _getPlantDB(plant.plantDbId);
                  if (plantDb == null) return Container();

                  final isSelected = plant.id == _selectedPlantId;

                  return PlantWidget(
                    plant: plant,
                    plantDb: plantDb,
                    isSelected: isSelected,
                    screenSize: screenSize,
                    isWateringMode: _isWateringMode,
                    onPlantTap: () {
                      if (_isWateringMode) {
                        _markAsWatered(plant);
                      } else {
                        setState(() => _selectedPlantId = plant.id);
                      }
                    },
                    onPlantDoubleTap: () {
                      if (_selectedPlant != null) {
                        Navigator.of(context).pushNamed(
                          '/plant',
                          arguments: _selectedPlant!.plantDbId,
                        );
                      }
                    },
                    onPositionChanged: (newPosition) {
                      setState(() {
                        plant.position = _applyBounds(
                          newPosition,
                          screenSize,
                          plant,
                        );
                      });
                    },
                  );
                }).toList(),
                if (_isWateringMode) const _WateringModeIndicator(),
                if (_selectedPlantId != null)
                  _SelectedPlantInfo(
                    plant: _selectedPlant!,
                    plantDb: _getPlantDB(_selectedPlant!.plantDbId),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _ControlButtons(
        isWateringMode: _isWateringMode,
        hasSelectedPlant: _selectedPlantId != null,
        onWateringToggle: () {
          setState(() {
            _isWateringMode = !_isWateringMode;
            if (_isWateringMode) _selectedPlantId = null;
          });
        },
        onDeletePressed: _deleteSelectedPlant,
        onEditNicknamePressed: _editSelectedPlantNickname,
        onAddPressed: () => _addNewPlant(context),
      ),
    );
  }
}

// ============ REUSABLE WIDGETS ============

class _GardenAppBar extends AppBar {
  _GardenAppBar({
    required String gardenName,
    required bool isWateringMode,
    required Function(String) onNameChanged,
    required VoidCallback onBackgroundPressed,
    required VoidCallback onSavePressed,
  }) : super(
         title: TextFormField(
           initialValue: isWateringMode
               ? 'Watering Mode: Tap Plants'
               : gardenName,
           onChanged: onNameChanged,
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
             onPressed: onBackgroundPressed,
           ),
           IconButton(
             icon: const Icon(Icons.save),
             tooltip: 'Save Garden',
             onPressed: onSavePressed,
           ),
         ],
       );
}

class _GardenBackground extends StatelessWidget {
  final String backgroundPattern;

  const _GardenBackground({required this.backgroundPattern});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: backgroundPattern.isNotEmpty
          ? Image.asset(backgroundPattern, fit: BoxFit.cover)
          : Container(color: Colors.green[100]),
    );
  }
}

class _WateringModeIndicator extends StatelessWidget {
  const _WateringModeIndicator();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            "🚿 Water Mode Active: Tap plants to water them",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _SelectedPlantInfo extends StatelessWidget {
  final PlantInstance plant;
  final PlantDB? plantDb;

  const _SelectedPlantInfo({required this.plant, required this.plantDb});

  @override
  Widget build(BuildContext context) {
    return Positioned(
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
          '${getPlantDisplayName(plant)} selected. Drag to move, or pinch to scale.',
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ControlButtons extends StatelessWidget {
  final bool isWateringMode;
  final bool hasSelectedPlant;
  final VoidCallback onWateringToggle;
  final VoidCallback onDeletePressed;
  final VoidCallback onEditNicknamePressed;
  final VoidCallback onAddPressed;

  const _ControlButtons({
    required this.isWateringMode,
    required this.hasSelectedPlant,
    required this.onWateringToggle,
    required this.onDeletePressed,
    required this.onEditNicknamePressed,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FloatingActionButton(
            heroTag: 'waterModeBtn',
            onPressed: onWateringToggle,
            backgroundColor: isWateringMode ? Colors.blueAccent : Colors.white,
            child: Icon(
              Icons.opacity,
              color: isWateringMode ? Colors.white : Colors.blueAccent,
            ),
          ),
          Row(
            children: [
              if (hasSelectedPlant)
                FloatingActionButton(
                  heroTag: 'editNicknameBtn',
                  onPressed: onEditNicknamePressed,
                  backgroundColor: Colors.amber[700],
                  child: const Icon(Icons.edit, color: Colors.white),
                ),
              if (hasSelectedPlant) const SizedBox(width: 12),
              if (hasSelectedPlant)
                FloatingActionButton(
                  heroTag: 'deleteBtn',
                  onPressed: onDeletePressed,
                  backgroundColor: Colors.red[700],
                  child: const Icon(Icons.delete_forever, color: Colors.white),
                ),
              if (hasSelectedPlant) const SizedBox(width: 12),
              FloatingActionButton(
                heroTag: 'addBtn',
                onPressed: onAddPressed,
                child: const Icon(Icons.local_florist),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
