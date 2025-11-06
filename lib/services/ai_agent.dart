import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import 'rag_base.dart';
import 'web_search.dart'; // <-- added: adjust path if needed

typedef ToolHandler =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> args);

class AIAgent {
  dynamic _model;
  InferenceChat? _chat;
  bool _initialized = false;
  bool _isInitializing = false;
  final List<String> _chatHistory = [];

  // Built-in tools (can be overridden by registerToolHandler)
  final List<Tool> tools = [
    // Added web search tool
    const Tool(
      name: 'web_search',
      description:
          'Search the web for a query and return summarized results. Provide a "query" string and optional "limit" integer.',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': 'Search query'},
          'limit': {'type': 'integer', 'description': 'Max results (optional)'},
        },
        'required': ['query'],
      },
    ),

    const Tool(
      name: 'local_knowledge',
      description:
          'Search the local gardening plant knowledge base for relevant information.',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': 'Search plant query'},
        },
        'required': ['query'],
      },
    ),
  ];

  // External handlers for tools (app code can register to run UI operations)
  final Map<String, ToolHandler> _toolHandlers = {};

  // Optional context for UI operations (not required). If provided, default handlers that need BuildContext can use it.
  BuildContext? uiContext;

  AIAgent({this.uiContext});

  /// Register a custom handler for a tool name. Overrides built-in behavior.
  void registerToolHandler(String name, ToolHandler handler) {
    _toolHandlers[name] = handler;
  }

  /// Initialize model. You can pass additional runtime options if needed.
  Future<void> init({
    int maxTokens = 1024,
    PreferredBackend preferredBackend = PreferredBackend.cpu,
    bool supportImage = false,
    int maxNumImages = 1,
  }) async {
    if (_initialized) return;
    if (_isInitializing) {
      // Wait if another init is in progress
      while (_isInitializing && !_initialized) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }
    _isInitializing = true;
    try {
      _model = await FlutterGemma.getActiveModel(
        maxTokens: maxTokens,
        preferredBackend: preferredBackend,
        supportImage: supportImage,
        maxNumImages: maxNumImages,
      );
      _initialized = true;
      debugPrint('✅ Model loaded successfully!');
    } catch (e) {
      debugPrint('❌ Failed to load model: $e');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Create a chat with optional runtime parameters (temperature, function-calls, tools...)
  Future<void> createChat({
    double temperature = 0.8,
    int? randomSeed = 42,
    int? topK = 64,
    double? topP = 0.95,
    int tokenBuffer = 256,
    bool supportImage = false,
    bool supportsFunctionCalls = true,
    bool isThinking = true,
    ModelType? modelType = ModelType.gemmaIt,
  }) async {
    if (!_initialized) await init();
    if (_model == null) {
      throw StateError('Model not initialized');
    }
    _chat = await _model.createChat(
      temperature: temperature,
      randomSeed: randomSeed ?? 1,
      topK: topK,
      topP: topP,
      tokenBuffer: tokenBuffer,
      supportImage: supportImage,
      supportsFunctionCalls: supportsFunctionCalls,
      tools: tools,
      isThinking: isThinking,
      modelType: modelType,
    );
    await _chat?.addQueryChunk(
      Message.text(
        text: '''
    You are a helpful assistant that helps the user with gardening advice.
    ''',
        isUser: false,
      ),
    );
    // You are a helpful assistant that helps the user with gardening advice.
    //     If a question about gardening, plants, or similar topics is asked to you:
    // - First check the local knowledge base by using the "local_knowledge" tool.
    // - If the local knowledge is insufficient or you get {"message":"No relevant local knowledge found."}, perform a "web_search" to find relevant information.
  }

  // /// Send a single user message and return the final text response from the model.
  // /// If the model makes a function call, the agent will attempt to execute it
  // /// using registered tool handlers (or built-in fallbacks) and then provide the tool's
  // /// response back to the model before returning the final text.
  // Future<String> ask(String userMessage) async {
  //   if (!_initialized) await init();
  //   if (_chat == null) {
  //     await createChat();
  //   }
  //   InferenceChat? chat = _chat;
  //   if (chat == null) {
  //     return "Agent not ready.";
  //   }

  //   try {
  //     // Append new user message with Gemma turn tokens
  //     _chatHistory.add("<start_of_turn>user\n$userMessage<end_of_turn>");

  //     // Combine history + model token start for next generation
  //     final prompt = '${_chatHistory.join('\n')}\n<start_of_turn>model\n';

  //     // Send the combined history as one chunk
  //     await _chat!.addQueryChunk(Message.text(text: userMessage, isUser: true));

  //     final response = await _chat!.generateChatResponse();

  //     // If the model requested a function call, handle it
  //     if (response is FunctionCallResponse) {
  //       return await _handleFunctionCall(response);
  //     }

  //     // If it's a text response, try to extract best available text
  //     if (response is TextResponse) {
  //       final text = response.token.replaceAll(RegExp(r'\\n'), '\n').trim();
  //       _chatHistory.add("<start_of_turn>model\n$text<end_of_turn>");
  //       return text;
  //     }

  //     return '';
  //   } catch (e) {
  //     debugPrint('❌ Inference error: $e');
  //     try {
  //       // InferenceChat does not expose a `close()` method; remove explicit close call.
  //       // Clear the agent chat reference so it can be recreated on the next request.
  //       _chat = null;
  //     } catch (_) {}
  //     return "Sorry, I couldn't generate a response right now.";
  //   }
  // }

  /// Ask the AI a question and progressively stream the text output
  /// to create a typing effect in the UI.
  Future<void> ask(
    String userMessage, {
    required void Function(String) onThinking,
    required void Function(String) onPartialResponse,
    required void Function(String) onCompleted,
    void Function(String error)? onError,
    Duration typingDelay = const Duration(milliseconds: 5),
  }) async {
    if (!_initialized) await init();
    if (_chat == null) {
      await createChat();
    }

    final chat = _chat;
    if (chat == null) {
      onError?.call("Agent not ready.");
      return;
    }

    try {
      // Add user message to conversation history
      _chatHistory.add("<start_of_turn>user\n$userMessage<end_of_turn>");

      // Notify UI that the agent is thinking
      onThinking("💭 ");

      await chat.addQueryChunk(Message.text(text: userMessage, isUser: true));

      // Use the async streaming API to progressively receive tokens
      final stream = chat.generateChatResponseAsync();

      String buffer = '';
      await for (final part in stream) {
        // If the model requests a function call mid-stream, handle it immediately
        if (part is FunctionCallResponse) {
          final result = await _handleFunctionCall(part);
          onCompleted(result);
          // Update history with tool result as model turn if desired
          _chatHistory.add("<start_of_turn>model\n$result<end_of_turn>");
          return;
        }

        // Accumulate text tokens (partial responses)
        if (part is TextResponse) {
          // TextResponse may contain incremental tokens; append and emit partials
          final chunk = part.token.replaceAll(RegExp(r'\\n'), '\n');
          buffer += chunk;
          onPartialResponse(buffer);
          // Small delay to create a typing effect in UI
          await Future.delayed(typingDelay);
        }
        // Other event types can be ignored or handled here if needed
      }

      // Stream completed; finalize response
      final finalText = buffer.trim();
      if (finalText.isNotEmpty) {
        _chatHistory.add("<start_of_turn>model\n$finalText<end_of_turn>");
      }
      onCompleted(finalText);
    } catch (e) {
      debugPrint('❌ Inference error: $e');
      _chat = null;
      onError?.call("⚠️ Sorry, I couldn't generate a response right now.");
    }
  }

  Future<String> _handleFunctionCall(FunctionCallResponse functionCall) async {
    final name = functionCall.name;
    final args = Map<String, dynamic>.from(functionCall.args);

    // Execute the tool (custom handler overrides built-ins)
    Map<String, dynamic> toolResult;
    try {
      toolResult = await _executeToolByName(name, args);
    } catch (e) {
      toolResult = {'error': 'Tool execution failed: ${e.toString()}'};
    }

    // Send tool response back to model
    try {
      await _chat?.addQuery(
        Message.toolResponse(toolName: name, response: toolResult),
      );
      final followUp = await _chat?.generateChatResponse();
      if (followUp is TextResponse) {
        return followUp.token.trim();
      }
    } catch (_) {
      // ignore and fall back to returning toolResult summary below
    }

    // If no textual follow-up, return a summary from the tool
    if (toolResult.containsKey('message')) {
      return toolResult['message'].toString();
    }
    if (toolResult.containsKey('error')) {
      return 'Tool error: ${toolResult['error']}';
    }
    return 'Tool executed.';
  }

  /// Execute a tool by name: prefer a registered handler, otherwise fall back to built-in behaviors.
  Future<Map<String, dynamic>> _executeToolByName(
    String name,
    Map<String, dynamic> args,
  ) async {
    // Custom handler registered by the app overrides built-ins
    final handler = _toolHandlers[name];
    if (handler != null) {
      return await handler(args);
    }

    // Built-in tool implementations (lightweight defaults)
    switch (name) {
      case 'web_search':
        final query = args['query']?.toString() ?? '';
        final limitRaw = args['limit'];
        int limit = 5;
        if (limitRaw is int) {
          limit = limitRaw;
        } else if (limitRaw != null) {
          limit = int.tryParse(limitRaw.toString()) ?? 5;
        }

        if (query.isEmpty) {
          return {'error': 'Missing query parameter for web_search.'};
        }

        try {
          // Assumes web_search.dart exposes a WebSearch.search(String query, {int limit})
          // Adjust call if your API is different.
          final summary = await WebSearch.searchSummary(query, limit: limit);

          return {'message': summary};
        } catch (e) {
          return {'error': 'Web search failed: ${e.toString()}'};
        }

      case 'local_knowledge':
        final query = args['query']?.toString() ?? '';
        if (query.isEmpty) {
          return {'error': 'Missing query parameter for local_knowledge.'};
        }

        try {
          final knowledge = await RAGBase.findKnowledge(query);
          if (knowledge.isEmpty) {
            return {'message': 'No relevant local knowledge found.'};
          }
          return {'message': knowledge};
        } catch (e) {
          return {'error': 'Local knowledge search failed: ${e.toString()}'};
        }

      default:
        return {'error': 'Unknown tool: $name'};
    }
  }
}
