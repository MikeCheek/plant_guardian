import 'package:flutter/material.dart';

// Assuming this path holds your PlantDB model and globalPlantsDB cache
import 'package:plant_guardian/widgets/garden_model.dart';

class PlantInfoScreen extends StatelessWidget {
  final String plantDbId;

  // Requires the ID of the plant in the central 'plants' collection
  const PlantInfoScreen({super.key, required this.plantDbId});

  // Helper to retrieve the PlantDB details from the cache
  PlantDB? _getPlantDB(String id) {
    return globalPlantsDB[id];
  }

  // Reusing the robust image builder logic from the editor screen
  Widget _buildPlantImage(PlantDB plantDb, {double scale = 4.0}) {
    // Check if the decoded bytes are available
    if (plantDb.decodedImageBytes.isEmpty) {
      return const Icon(Icons.broken_image, color: Colors.grey, size: 80);
    }

    // Use the pre-decoded bytes for fast rendering
    return Image.memory(
      plantDb.decodedImageBytes,
      width: 50 * scale, // Make it larger for the detail screen
      height: 50 * scale,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.error, size: 80),
    );
  }

  // Helper to build a styled info row
  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.green[300], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green[300],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Retrieve the plant data from the cached global state
    final PlantDB? plantDb = _getPlantDB(plantDbId);

    if (plantDb == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Plant Not Found')),
        body: const Center(
          child: Text('Error: Plant data could not be loaded from cache.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(plantDb.name),
        // backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Plant Image ---
            Container(
              height: 250,
              // color: Colors.grey[200],
              alignment: Alignment.center,
              child: _buildPlantImage(plantDb, scale: 4.0),
            ),

            // --- Description ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    plantDb.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plantDb.description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),

            const Divider(height: 20, thickness: 1), // Visual separation
            // --- Care Guide ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Care Requirements',
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 1. Water
            _buildInfoRow(
              context,
              Icons.water_drop,
              'Water Frequency',
              plantDb.waterFrequency,
            ),

            // 2. Sunlight
            _buildInfoRow(
              context,
              Icons.wb_sunny,
              'Sunlight Exposition',
              plantDb.exposition,
            ),

            // 3. Soil Type
            _buildInfoRow(context, Icons.grass, 'Soil Type', plantDb.soilType),

            // 4. Ideal Period
            _buildInfoRow(
              context,
              Icons.schedule,
              'Ideal Growth Period',
              plantDb.idealPeriod,
            ),

            const Divider(height: 20, thickness: 1),

            // --- Curiosity ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Curiosity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plantDb.curiosity,
                    style: const TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
