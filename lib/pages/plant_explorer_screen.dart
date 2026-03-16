import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:plant_guardian/services/plant_recommender.dart';

class PlantExplorerScreen extends StatefulWidget {
  const PlantExplorerScreen({super.key});

  @override
  State<PlantExplorerScreen> createState() => _PlantExplorerScreenState();
}

class _PlantExplorerScreenState extends State<PlantExplorerScreen> {
  late Future<ExplorePlantData> _future;
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  _ExplorerFilter _activeFilter = _ExplorerFilter.all;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<ExplorePlantData> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const ExplorePlantData(
        allPlants: [],
        recommendations: [],
        ownedTopics: {},
      );
    }

    return PlantRecommender.buildForUser(
      user: user,
      firestore: FirebaseFirestore.instance,
    );
  }

  bool _matchesFilter(PlantKnowledgeEntry entry) {
    switch (_activeFilter) {
      case _ExplorerFilter.all:
        return true;
      case _ExplorerFilter.cooking:
        return !entry.cookingUse.toLowerCase().contains('not for cooking') &&
            !entry.cookingUse.toLowerCase().contains(
              'not typically used in home cooking',
            );
      case _ExplorerFilter.airCleaning:
        return entry.airCleaningPotential.toLowerCase() == 'high';
      case _ExplorerFilter.dustReduction:
        return entry.dustReductionPotential.toLowerCase() == 'high';
      case _ExplorerFilter.petSafer:
        return entry.petSafety.toLowerCase().contains('pet-friendlier');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explore House Plants')),
      body: FutureBuilder<ExplorePlantData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Unable to load plant knowledge.'));
          }

          final data = snapshot.data!;

          final filtered = data.allPlants.where((entry) {
            final searchable = [
              entry.topic,
              entry.text,
              entry.sunExposure,
              entry.watering,
              entry.cookingUse,
              entry.airCleaningPotential,
              entry.dustReductionPotential,
            ].join(' ').toLowerCase();

            final matchesQuery = _query.isEmpty || searchable.contains(_query);
            return matchesQuery && _matchesFilter(entry);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText:
                        'Search by plant, light, cooking, or air benefits...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              _FilterStrip(
                activeFilter: _activeFilter,
                onChanged: (value) => setState(() => _activeFilter = value),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  children: [
                    Text(
                      'Suggested for your current collection',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (data.recommendations.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 14),
                        child: Text(
                          'Add plants to your gardens to unlock personalized suggestions.',
                        ),
                      )
                    else
                      ...data.recommendations
                          .take(5)
                          .map((entry) => _RecommendationCard(entry: entry)),
                    const SizedBox(height: 18),
                    Text(
                      'Plant knowledge library (${filtered.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...filtered.map(
                      (entry) => _PlantKnowledgeCard(
                        entry: entry,
                        owned: data.ownedTopics.contains(
                          PlantRecommender.normalizeTopic(entry.topic),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _ExplorerFilter { all, cooking, airCleaning, dustReduction, petSafer }

class _FilterStrip extends StatelessWidget {
  final _ExplorerFilter activeFilter;
  final ValueChanged<_ExplorerFilter> onChanged;

  const _FilterStrip({required this.activeFilter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _chip(context, _ExplorerFilter.all, 'All'),
          _chip(context, _ExplorerFilter.cooking, 'Cooking'),
          _chip(context, _ExplorerFilter.airCleaning, 'Air Cleaning'),
          _chip(context, _ExplorerFilter.dustReduction, 'Dust Reduction'),
          _chip(context, _ExplorerFilter.petSafer, 'Pet Safer'),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, _ExplorerFilter value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        selected: activeFilter == value,
        label: Text(label),
        onSelected: (_) => onChanged(value),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final PlantKnowledgeEntry entry;

  const _RecommendationCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.auto_awesome)),
        title: Text(_prettyName(entry.topic)),
        subtitle: Text(
          '${entry.sunExposure} • ${entry.watering}\nAir: ${entry.airCleaningPotential}, Dust: ${entry.dustReductionPotential}',
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _PlantKnowledgeCard extends StatelessWidget {
  final PlantKnowledgeEntry entry;
  final bool owned;

  const _PlantKnowledgeCard({required this.entry, required this.owned});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(_prettyName(entry.topic)),
        subtitle: Text(
          '${entry.airCleaningPotential} air cleaning • ${entry.dustReductionPotential} dust reduction',
        ),
        trailing: owned
            ? const Chip(
                label: Text('In your garden'),
                visualDensity: VisualDensity.compact,
              )
            : null,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          _line(context, 'Overview', entry.text),
          _line(context, 'Cooking use', entry.cookingUse),
          _line(context, 'Sun exposure', entry.sunExposure),
          _line(context, 'Watering', entry.watering),
          _line(context, 'Soil', entry.soilType),
          _line(context, 'Ideal period', entry.idealPeriod),
          _line(context, 'Tips', entry.tips),
          _line(context, 'Pet safety', entry.petSafety),
          if (entry.usefulHomeBenefits.isNotEmpty)
            _line(
              context,
              'Useful at home',
              entry.usefulHomeBenefits.join(' | '),
            ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text.rich(
        TextSpan(
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

String _prettyName(String value) {
  return value
      .split(' ')
      .where((w) => w.trim().isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
