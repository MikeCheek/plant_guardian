import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:plant_guardian/widgets/garden_model.dart';

class PlantKnowledgeEntry {
  final String topic;
  final String text;
  final String watering;
  final String sunExposure;
  final String soilType;
  final String idealPeriod;
  final String tips;
  final String cookingUse;
  final String airCleaningPotential;
  final String dustReductionPotential;
  final String petSafety;
  final List<String> usefulHomeBenefits;

  const PlantKnowledgeEntry({
    required this.topic,
    required this.text,
    required this.watering,
    required this.sunExposure,
    required this.soilType,
    required this.idealPeriod,
    required this.tips,
    required this.cookingUse,
    required this.airCleaningPotential,
    required this.dustReductionPotential,
    required this.petSafety,
    required this.usefulHomeBenefits,
  });

  factory PlantKnowledgeEntry.fromJson(Map<String, dynamic> json) {
    final dynamic rawBenefits = json['useful_home_benefits'];
    final List<String> benefits = rawBenefits is List
        ? rawBenefits.map((e) => e.toString()).toList()
        : const [];

    return PlantKnowledgeEntry(
      topic: (json['topic'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      watering: (json['watering'] ?? '').toString(),
      sunExposure: (json['sun_exposure'] ?? '').toString(),
      soilType: (json['soil_type'] ?? '').toString(),
      idealPeriod: (json['ideal_period'] ?? '').toString(),
      tips: (json['tips'] ?? '').toString(),
      cookingUse: (json['cooking_use'] ?? '').toString(),
      airCleaningPotential: (json['air_cleaning_potential'] ?? '').toString(),
      dustReductionPotential: (json['dust_reduction_potential'] ?? '')
          .toString(),
      petSafety: (json['pet_safety'] ?? '').toString(),
      usefulHomeBenefits: benefits,
    );
  }
}

class ExplorePlantData {
  final List<PlantKnowledgeEntry> allPlants;
  final List<PlantKnowledgeEntry> recommendations;
  final Set<String> ownedTopics;

  const ExplorePlantData({
    required this.allPlants,
    required this.recommendations,
    required this.ownedTopics,
  });
}

class PlantRecommender {
  static const String _knowledgePath = 'assets/gardening_basics.json';

  static Future<ExplorePlantData> buildForUser({
    required User user,
    required FirebaseFirestore firestore,
  }) async {
    await fetchAndCacheAvailablePlants(firestore);

    final allKnowledge = await _loadKnowledge();
    final ownedTopics = await _loadOwnedTopics(
      user: user,
      firestore: firestore,
    );

    final recommendations = _recommend(
      allPlants: allKnowledge,
      ownedTopics: ownedTopics,
      ownedPlantDbs: _ownedPlantDbRecords(ownedTopics),
    );

    return ExplorePlantData(
      allPlants: allKnowledge,
      recommendations: recommendations,
      ownedTopics: ownedTopics,
    );
  }

  static Future<List<PlantKnowledgeEntry>> _loadKnowledge() async {
    final data = await rootBundle.loadString(_knowledgePath);
    final List<dynamic> decoded = jsonDecode(data) as List<dynamic>;
    return decoded
        .map((e) => PlantKnowledgeEntry.fromJson(e as Map<String, dynamic>))
        .where((e) => e.topic.trim().isNotEmpty)
        .toList();
  }

  static Future<Set<String>> _loadOwnedTopics({
    required User user,
    required FirebaseFirestore firestore,
  }) async {
    final snapshot = await firestore
        .collection('users')
        .doc(user.uid)
        .collection('gardens')
        .get();

    final Set<String> ownedNames = {};

    for (final doc in snapshot.docs) {
      final garden = Garden.fromJson(doc.data());
      for (final instance in garden.plants) {
        final db = globalPlantsDB[instance.plantDbId];
        if (db == null) continue;
        ownedNames.add(normalizeTopic(db.name));
      }
    }

    return ownedNames;
  }

  static Iterable<PlantDB> _ownedPlantDbRecords(Set<String> ownedTopics) {
    return globalPlantsDB.values.where(
      (p) => ownedTopics.contains(normalizeTopic(p.name)),
    );
  }

  static List<PlantKnowledgeEntry> _recommend({
    required List<PlantKnowledgeEntry> allPlants,
    required Set<String> ownedTopics,
    required Iterable<PlantDB> ownedPlantDbs,
  }) {
    final preferredLight = _majorityLightBucket(ownedPlantDbs);
    final preferredWatering = _majorityWateringBucket(ownedPlantDbs);

    final bool userHasCookingPlants = allPlants.any(
      (p) =>
          ownedTopics.contains(normalizeTopic(p.topic)) &&
          !p.cookingUse.toLowerCase().contains('not for cooking') &&
          !p.cookingUse.toLowerCase().contains(
            'not typically used in home cooking',
          ),
    );

    final scored = <MapEntry<PlantKnowledgeEntry, int>>[];

    for (final plant in allPlants) {
      final normalizedTopic = normalizeTopic(plant.topic);
      if (ownedTopics.contains(normalizedTopic)) continue;

      int score = 0;

      if (_lightBucketFromText(plant.sunExposure) == preferredLight) {
        score += 3;
      }

      if (_wateringBucketFromText(plant.watering) == preferredWatering) {
        score += 3;
      }

      if (plant.airCleaningPotential.toLowerCase() == 'high') score += 2;
      if (plant.dustReductionPotential.toLowerCase() == 'high') score += 2;

      if (userHasCookingPlants &&
          !plant.cookingUse.toLowerCase().contains('not for cooking') &&
          !plant.cookingUse.toLowerCase().contains(
            'not typically used in home cooking',
          )) {
        score += 2;
      }

      if (plant.petSafety.toLowerCase().contains('pet-friendlier')) {
        score += 1;
      }

      scored.add(MapEntry(plant, score));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(10).map((e) => e.key).toList();
  }

  static String _majorityLightBucket(Iterable<PlantDB> plants) {
    final counts = <String, int>{};
    for (final p in plants) {
      final bucket = _lightBucketFromText(p.exposition);
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'medium';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static String _majorityWateringBucket(Iterable<PlantDB> plants) {
    final counts = <String, int>{};
    for (final p in plants) {
      final bucket = _wateringBucketFromDays(p.waterDaysFrequency);
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'moderate';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static String _lightBucketFromText(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('full sun') || value.contains('bright light')) {
      return 'bright';
    }
    if (value.contains('low') || value.contains('shade')) {
      return 'low';
    }
    return 'medium';
  }

  static String _wateringBucketFromText(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('consistently moist') ||
        value.contains('keep soil moist') ||
        value.contains('evenly moist')) {
      return 'frequent';
    }
    if (value.contains('dry completely') ||
        value.contains('water sparingly') ||
        value.contains('allow soil to dry')) {
      return 'low';
    }
    return 'moderate';
  }

  static String _wateringBucketFromDays(int days) {
    if (days <= 3) return 'frequent';
    if (days >= 10) return 'low';
    return 'moderate';
  }

  static String normalizeTopic(String value) {
    var cleaned = value.toLowerCase();
    cleaned = cleaned.split('(').first;
    cleaned = cleaned.replaceAll(RegExp(r'[_-]'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    return cleaned;
  }
}
