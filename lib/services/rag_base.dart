import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class RAGBase {
  static List<dynamic>? _knowledge;

  static Future<void> _load() async {
    if (_knowledge != null) return;
    final data = await rootBundle.loadString('assets/gardening_basics.json');
    _knowledge = jsonDecode(data);
  }

  static Future<String> findKnowledge(String query) async {
    await _load();
    for (final item in _knowledge!) {
      if (query.toLowerCase().contains(item['topic'])) {
        return item['text'];
      }
    }
    return '';
  }
}
