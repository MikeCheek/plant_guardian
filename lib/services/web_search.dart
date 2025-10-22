import 'package:http/http.dart' as http;
import 'dart:convert';

class WebSearch {
  static Future<List<String>> searchWeb(String query) async {
    final res = await http.get(
      Uri.parse('https://api.duckduckgo.com/?q=$query&format=json'),
    );
    final data = jsonDecode(res.body);
    final List<String> results = [];

    if (data['RelatedTopics'] != null) {
      for (var t in data['RelatedTopics']) {
        if (t['Text'] != null) results.add(t['Text']);
      }
    }
    return results.take(5).toList();
  }
}
