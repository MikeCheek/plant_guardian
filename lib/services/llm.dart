import 'dart:async';
import 'package:flutter/material.dart';
import 'package:plant_guardian/OnnxLLMHelper.dart';

/// A minimal LLM interface focused solely on initialization and single-turn inference.
/// It wraps the OnnxLLMHelper and removes all Agent/Tool logic.
class OnnxInferenceLLM {
  // Use your custom helper class directly
  bool _initialized = false;
  bool _isInitializing = false;

  set uiContext(BuildContext uiContext) {}

  // --- Initialization ---

  /// Initialize the ONNX model helper.
  Future<void> init() async {
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
      // Call the init method on your ONNX Helper
      // await OnnxLLMHelper.init();
      _initialized = true;
      debugPrint('✅ ONNX Inference LLM initialized successfully!');
    } catch (e) {
      debugPrint('❌ Failed to load ONNX model: $e');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  // --- Core Inference ---

  /// Sends a single prompt to the ONNX model and streams the result.
  ///
  /// NOTE: This implementation simulates streaming since your core ONNX
  /// helper currently performs a single, synchronous generation step.
  Future<void> ask(
    String userMessage, {
    required void Function(String) onThinking,
    required void Function(String) onPartialResponse,
    required void Function(String) onCompleted,
    void Function(String error)? onError,
    Duration typingDelay = const Duration(milliseconds: 5),
  }) async {
    if (!_initialized) {
      try {
        await init();
      } catch (e) {
        onError?.call("Model failed to initialize: $e");
        return;
      }
    }

    try {
      onThinking("💭 Running inference...");

      // 🚨 CRITICAL CHANGE: FORMAT THE INPUT STRING
      final String formattedPrompt =
          """
Below is an instruction that describes a task. Write a response that appropriately completes the request.

### Instruction:
$userMessage

### Response:
"""; // Note the empty response section. The model will complete this.
      print("Formatted Prompt: $formattedPrompt");

      String finalResponse = '';

      // 1. Call the helper function with the formatted prompt
      final Stream<String> responseStream = OnnxLLMHelper.generate(
        formattedPrompt,
      );

      // 2. Consume the stream
      await for (final partialText in responseStream) {
        // 🚨 IMPORTANT: You need to strip the input formatting from the streamed output.
        // The model's stream will include the full prompt as it was passed in,
        // followed by the generated text.

        // Find the start of the '### Response:' tag in the stream output.
        // We look for the part of the prompt that we expect the model to immediately precede the response.
        const responseTag = "### Response:";

        final int startIndex = partialText.lastIndexOf(responseTag);

        if (startIndex != -1) {
          // Calculate where the actual generated response starts (after the tag and the newline/space)
          final int responseStartIndex = startIndex + responseTag.length;

          // The current generated chunk is the text starting *after* the Response tag.
          final currentGeneratedText = partialText
              .substring(responseStartIndex)
              .trimLeft();

          onPartialResponse(currentGeneratedText);
          finalResponse = currentGeneratedText;
        } else {
          // If the tag isn't found, it's either an error or the stream hasn't produced enough text yet.
          // For simplicity, we just skip updating the UI until the tag appears.
          continue;
        }
      }

      print("Final Response: $finalResponse");

      // 3. Complete the process
      if (finalResponse.isNotEmpty) {
        onCompleted(finalResponse);
      } else {
        onCompleted("Generation finished without producing text.");
      }
    } catch (e) {
      debugPrint('❌ Inference error: $e');
      onError?.call("⚠️ Sorry, inference failed: ${e.toString()}");
    }
  }

  /// Disposes of the ONNX Runtime resources.
  void dispose() {
    OnnxLLMHelper.dispose();
    _initialized = false;
    debugPrint("🗑️ ONNX Inference LLM disposed.");
  }
}
