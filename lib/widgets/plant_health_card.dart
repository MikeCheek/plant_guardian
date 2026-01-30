import 'package:flutter/material.dart';

class PlantHealthCard extends StatelessWidget {
  final String diseaseResult;
  final double confidence;

  const PlantHealthCard({
    super.key,
    required this.diseaseResult,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    final bool isHealthy = diseaseResult.trim().toLowerCase().endsWith(
      'healthy',
    );

    // Aesthetic configuration
    final Color themeColor = isHealthy ? Colors.green : Colors.red;
    final IconData icon = isHealthy
        ? Icons.verified_user_rounded
        : Icons.sick_rounded; // Or use Icons.coronavirus if available
    final String label = isHealthy ? "OPTIMAL HEALTH" : "HEALTH ALERT";

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [themeColor.withOpacity(0.15), themeColor.withOpacity(0.05)],
        ),
        border: Border.all(color: themeColor.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background Decorative Icon
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(icon, size: 100, color: themeColor.withOpacity(0.05)),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: themeColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        label,
                        style: TextStyle(
                          color: themeColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    diseaseResult,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Confidence Meter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Analysis Confidence",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      Text(
                        "${(confidence * 100).toStringAsFixed(0)}%",
                        style: TextStyle(
                          color: themeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: confidence,
                      minHeight: 8,
                      backgroundColor: themeColor.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
