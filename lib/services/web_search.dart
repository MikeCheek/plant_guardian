import 'dart:async';
import 'package:duckduckgo_search/duckduckgo_search.dart';

class WebSearch {
  /// Performs a web search using the duckduckgo_search package.
  /// Returns a list of result summaries (title + URL).
  /// Adds a timeout for network requests (default 5 seconds).
  static Future<List<Map<String, String>>> searchWeb(
    String query, {
    int limit = 5,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    print(
      "🌐 [WebSearch] Searching for: $query (timeout: ${timeout.inSeconds}s)",
    );

    final results = <Map<String, String>>[];

    try {
      final search = DuckDuckGoSearch();

      try {
        final entries = await search
            .text(query, maxResults: limit)
            .timeout(timeout);

        for (final entry in entries) {
          final title = (entry.title ?? entry.body ?? '').toString().trim();
          final link = (entry.link ?? '').toString();
          if (title.isNotEmpty || link.isNotEmpty) {
            results.add({'title': title, 'url': link});
          }
        }
      } on TimeoutException {
        print(
          "⏱️ [WebSearch] DuckDuckGo search timed out after ${timeout.inSeconds}s",
        );
      } catch (e) {
        print("⚠️ [WebSearch] DuckDuckGo search failed: $e");
      }
    } catch (e) {
      print("⚠️ [WebSearch] Error: $e");
    }

    return results.take(limit).toList();
  }

  /// Returns formatted Markdown summary suitable for chat display
  static Future<String> searchSummary(String query, {int limit = 5}) async {
    final results = await searchWeb(query, limit: limit);
    if (results.isEmpty) return "❌ No web results found for **$query**.";

    final buffer = StringBuffer("🔎 **Search results for \"$query\":**\n\n");
    for (final r in results) {
      final title = r['title']?.replaceAll(RegExp(r'\n'), ' ') ?? '';
      final url = r['url'] ?? '';
      buffer.writeln(url.isNotEmpty ? "- [$title]($url)" : "- $title");
    }
    return buffer.toString().trim();
  }
}
