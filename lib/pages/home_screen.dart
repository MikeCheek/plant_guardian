import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plant_guardian/pages/plant_explorer_screen.dart';

import 'package:plant_guardian/colors.dart';
import 'package:plant_guardian/widgets/garden_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Store raw data instead of a single string for better UI mapping
  Map<String, List<String>> _thirstyMap = {};
  List<_UpcomingWateringItem> _upcomingPlants = [];
  bool _isGenerating = true;
  String _statusMessage = "INITIALIZING SYSTEM...";

  @override
  void initState() {
    super.initState();
    _fetchGardenData();
  }

  Future<void> _fetchGardenData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isGenerating = true;
      _statusMessage = "SYNCING TELEMETRY...";
    });

    try {
      // Logic placeholder for your getThirstyMapFromFirestore(user.uid)
      final data = await getThirstyMapFromFirestore(user.uid);
      final upcomingData = await _getUpcomingWateringPlants(user.uid);

      if (mounted) {
        setState(() {
          _thirstyMap = data;
          _upcomingPlants = upcomingData;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "SENSOR OFFLINE";
          _upcomingPlants = [];
          _isGenerating = false;
        });
      }
    }
  }

  Future<List<_UpcomingWateringItem>> _getUpcomingWateringPlants(
    String userId,
  ) async {
    final firestore = FirebaseFirestore.instance;
    await fetchAndCacheAvailablePlants(firestore);

    final gardensSnapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('gardens')
        .get();

    final now = DateTime.now();
    final List<_UpcomingWateringItem> upcoming = [];

    for (final gardenDoc in gardensSnapshot.docs) {
      final garden = Garden.fromJson(gardenDoc.data());
      for (final instance in garden.plants) {
        final plantDb = globalPlantsDB[instance.plantDbId];
        if (plantDb == null) continue;

        final lastWatered = instance.lastWatered ?? now;
        final daysSinceWatering = now.difference(lastWatered).inDays;
        final daysUntilWatering =
            plantDb.waterDaysFrequency - daysSinceWatering;

        if (daysUntilWatering <= 0) {
          continue;
        }

        upcoming.add(
          _UpcomingWateringItem(
            gardenName: garden.name,
            plantName: getPlantDisplayName(instance),
            daysUntilWatering: daysUntilWatering,
          ),
        );
      }
    }

    upcoming.sort((a, b) {
      final urgency = a.daysUntilWatering.compareTo(b.daysUntilWatering);
      if (urgency != 0) return urgency;
      return a.plantName.toLowerCase().compareTo(b.plantName.toLowerCase());
    });

    return upcoming.take(8).toList();
  }

  String _formatDueLabel(int days) {
    if (days <= 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
  }

  Future<void> _openGardenByName(String gardenName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('gardens')
          .where('garden_name', isEqualTo: gardenName)
          .limit(1)
          .get();

      if (!mounted) return;

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Garden '$gardenName' not found.")),
        );
        return;
      }

      final garden = Garden.fromJson(snapshot.docs.first.data());
      openGardenEditor(context, garden);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open garden right now.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.backgroundGradient(isDark),
            ),
          ),
          Positioned(
            top: -80,
            right: -70,
            child: _buildGlowBlob(
              scheme.primary.withValues(alpha: isDark ? 0.22 : 0.14),
              210,
            ),
          ),
          Positioned(
            bottom: 140,
            left: -90,
            child: _buildGlowBlob(
              scheme.tertiary.withValues(alpha: isDark ? 0.18 : 0.1),
              250,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildHeader(user),
                  const SizedBox(height: 32),
                  _buildSystemStatusHeader(),
                  const SizedBox(height: 14),
                  _buildExplorePlantsSection(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isGenerating
                        ? _buildLoadingState()
                        : _buildGardenGrid(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplorePlantsSection() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: scheme.surface.withValues(alpha: 0.66),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.explore, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Explore House Plants',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Browse a large plant knowledge list and get suggestions based on your collection.',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlantExplorerScreen()),
              );
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowBlob(Color color, double size) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _buildSystemStatusHeader() {
    final scheme = Theme.of(context).colorScheme;
    bool isCritical = _thirstyMap.isNotEmpty;
    return Row(
      children: [
        Text(
          "GARDEN HEALTH REPORT",
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.62),
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isCritical
                ? scheme.error.withValues(alpha: 0.14)
                : scheme.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCritical ? scheme.error : scheme.primary,
              width: 0.5,
            ),
          ),
          child: Text(
            isCritical ? "ACTION REQUIRED" : "OPTIMAL",
            style: TextStyle(
              color: isCritical ? scheme.error : scheme.primary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGardenGrid() {
    final scheme = Theme.of(context).colorScheme;

    if (_thirstyMap.isEmpty) {
      return ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 30),
          Icon(
            Icons.check_circle_outline,
            color: scheme.primary.withValues(alpha: 0.4),
            size: 60,
          ),
          const SizedBox(height: 16),
          Text(
            "ALL SECTORS HYDRATED",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.72),
              letterSpacing: 1.5,
            ),
          ),
          if (_upcomingPlants.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'Next plants to water',
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            ..._upcomingPlants.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.66),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 18, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.plantName,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            item.gardenName,
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.65),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _formatDueLabel(item.daysUntilWatering),
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _thirstyMap.length,
      itemBuilder: (context, index) {
        String sector = _thirstyMap.keys.elementAt(index);
        List<String> units = _thirstyMap[sector]!;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _openGardenByName(sector),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.66),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.grid_view_rounded,
                        color: scheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        sector.toUpperCase(),
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: units
                        .map(
                          (unit) => Chip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: scheme.error.withValues(
                              alpha: 0.1,
                            ),
                            side: BorderSide(
                              color: scheme.error.withValues(alpha: 0.35),
                            ),
                            label: Text(
                              unit,
                              style: TextStyle(
                                color: scheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: scheme.primary, strokeWidth: 2),
          const SizedBox(height: 20),
          Text(
            _statusMessage,
            style: TextStyle(
              color: scheme.primary,
              letterSpacing: 2,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(User? user) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome back!",
              style: TextStyle(
                color: scheme.primary.withValues(alpha: 0.85),
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              user?.displayName ?? "GUEST",
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _UpcomingWateringItem {
  final String gardenName;
  final String plantName;
  final int daysUntilWatering;

  const _UpcomingWateringItem({
    required this.gardenName,
    required this.plantName,
    required this.daysUntilWatering,
  });
}
