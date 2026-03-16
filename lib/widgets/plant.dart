import 'package:flutter/material.dart';
import 'package:plant_guardian/widgets/garden_model.dart';

class _PlantImage extends StatelessWidget {
  final PlantInstance plant;
  final PlantDB plantDb;

  const _PlantImage({required this.plant, required this.plantDb});

  @override
  Widget build(BuildContext context) {
    final bool thirsty = isPlantThirsty(plant);
    final double size = 50 * plant.scale;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              plantDb.decodedImageBytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
          if (thirsty)
            Positioned(
              top: -5,
              right: -5,
              child: Icon(
                Icons.water_drop,
                color: Colors.blueAccent,
                size: 20 * (plant.scale * 0.8).clamp(1.0, 2.0),
              ),
            ),
        ],
      ),
    );
  }
}

class PlantWidget extends StatelessWidget {
  final PlantInstance plant;
  final PlantDB plantDb;
  final bool isSelected;
  final Size screenSize;
  final bool isWateringMode;
  final VoidCallback onPlantTap;
  final VoidCallback onPlantDoubleTap;
  final Function(Offset) onPositionChanged;

  const PlantWidget({
    required this.plant,
    required this.plantDb,
    required this.isSelected,
    required this.screenSize,
    required this.isWateringMode,
    required this.onPlantTap,
    required this.onPlantDoubleTap,
    required this.onPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: plant.position.dx,
      top: plant.position.dy,
      child: isSelected && !isWateringMode
          ? _DraggablePlant(
              plant: plant,
              plantDb: plantDb,
              onPlantTap: onPlantTap,
              onPlantDoubleTap: onPlantDoubleTap,
              onPositionChanged: onPositionChanged,
              screenSize: screenSize,
            )
          : _StaticPlant(
              plant: plant,
              plantDb: plantDb,
              onPlantTap: onPlantTap,
            ),
    );
  }
}

class _DraggablePlant extends StatelessWidget {
  final PlantInstance plant;
  final PlantDB plantDb;
  final VoidCallback onPlantTap;
  final VoidCallback onPlantDoubleTap;
  final Function(Offset) onPositionChanged;
  final Size screenSize;

  const _DraggablePlant({
    required this.plant,
    required this.plantDb,
    required this.onPlantTap,
    required this.onPlantDoubleTap,
    required this.onPositionChanged,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    return Draggable(
      data: plant,
      feedback: Opacity(
        opacity: 0.7,
        child: _PlantImage(plant: plant, plantDb: plantDb),
      ),
      childWhenDragging: Container(),
      child: GestureDetector(
        onTap: onPlantTap,
        onDoubleTap: onPlantDoubleTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blueAccent, width: 3),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlantImage(plant: plant, plantDb: plantDb),
              Text(
                getPlantDisplayName(plant),
                style: TextStyle(
                  fontSize: 4 * plant.scale,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                  shadows: const [
                    Shadow(color: Colors.blueAccent, blurRadius: 2),
                  ],
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
            AppBar().preferredSize.height + MediaQuery.of(context).padding.top;
        final double imageHeight = 50 * plant.scale;
        final newBodyOffset = Offset(
          offset.dx,
          offset.dy - appBarHeight - imageHeight / 2,
        );
        onPositionChanged(newBodyOffset);
      },
    );
  }
}

class _StaticPlant extends StatelessWidget {
  final PlantInstance plant;
  final PlantDB plantDb;
  final VoidCallback onPlantTap;

  const _StaticPlant({
    required this.plant,
    required this.plantDb,
    required this.onPlantTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPlantTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: _PlantImage(plant: plant, plantDb: plantDb),
      ),
    );
  }
}
