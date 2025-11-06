import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class RAGBase {
  static List<dynamic>? _knowledge;

  /// Load knowledge from JSON asset once
  static Future<void> _load() async {
    if (_knowledge != null) return;
    final data = await rootBundle.loadString('assets/gardening_basics.json');
    _knowledge = jsonDecode(data);
  }

  /// Find relevant knowledge entries for a query.
  /// Returns concatenated results for all matches (or empty string if none).
  static Future<String> findKnowledge(String query) async {
    print("🔍 [RAGBase] Finding knowledge for query: $query");
    await _load();
    final lowerQuery = query.toLowerCase();

    // Collect all matches
    final matches = _knowledge!
        .where(
          (item) => lowerQuery.contains(item['topic'].toString().toLowerCase()),
        )
        .map((item) => item['text'].toString())
        .toList();

    if (matches.isEmpty) return '';

    // Combine multiple matches for a stronger response
    return matches.join('\n\n');
  }
}
