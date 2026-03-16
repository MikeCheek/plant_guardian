import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OnlineAgent {
  static const String baseUrl = String.fromEnvironment('SERVER_URL');
  static const String apiKey = String.fromEnvironment('API_KEY');

  bool _initialized = false;
  final List<Map<String, String>> _chatHistory = [];

  BuildContext? uiContext;
  OnlineAgent({this.uiContext});

  /// Checks the /health endpoint to see if the server/model is ready
  Future<bool> isServerHealthy() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Health check failed: $e');
      return false;
    }
  }

  /// In the remote version, init just checks connectivity
  Future<void> init() async {
    if (_initialized) return;

    bool healthy = await isServerHealthy();
    if (healthy) {
      _initialized = true;
      debugPrint('✅ Remote Agent connected successfully!');
    } else {
      throw Exception("Server not reachable or still loading model.");
    }
  }

  /// Send a message to the remote server and stream the response
  Future<void> ask(
    String userMessage, {
    String? uid,
    required void Function(String) onThinking,
    required void Function(String) onPartialResponse,
    required void Function(String) onCompleted,
    void Function(String error)? onError,
    Duration typingDelay = const Duration(milliseconds: 10),
  }) async {
    try {
      if (!_initialized) await init();

      onThinking("💭 Agent is thinking...");

      // Prepare the request
      final url = Uri.parse('$baseUrl/chat');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': apiKey, // Your custom security header
        },
        body: jsonEncode({
          'message': userMessage,
          'uid': uid,
          // 'history': _chatHistory, // Optional: if your backend handles history
        }),
      );

      if (response.statusCode == 200) {
        // Decode the full response
        final data = jsonDecode(response.body);
        final String fullText = data['response'] ?? "";

        // Simulate a typing effect for the UI
        String displayedText = "";
        for (int i = 0; i < fullText.length; i++) {
          displayedText += fullText[i];
          onPartialResponse(displayedText);
          await Future.delayed(typingDelay);
        }

        // Add to history for context (optional)
        _chatHistory.add({"user": userMessage, "assistant": fullText});
        onCompleted(fullText);
      } else {
        onError?.call(
          "Error: ${response.statusCode} - ${response.reasonPhrase}",
        );
      }
    } catch (e) {
      debugPrint('❌ Request error: $e');
      onError?.call("⚠️ Could not reach the gardening agent.");
    }
  }
}
