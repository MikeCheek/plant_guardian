import 'dart:io';
import 'package:flutter/services.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path_provider/path_provider.dart';

class AIInferenceService {
  LlamaParent? _llamaParent;

  Future<void> initModel() async {
    if (_llamaParent != null) return;

    // 1. Prepare model file path
    final dir = await getApplicationDocumentsDirectory();
    final modelFile = File('${dir.path}/smollm2.gguf');

    if (!await modelFile.exists()) {
      final data = await rootBundle.load(
        'assets/llm/SmolLM2-135M-Instruct-Q2_K.gguf',
      );
      await modelFile.writeAsBytes(data.buffer.asUint8List());
    }

    // 2. Setup Load Configuration
    final loadCommand = LlamaLoad(
      path: modelFile.path,
      modelParams: ModelParams(),
      contextParams: ContextParams.fromJson({
        'nCtx': 512,
        'nThreads': Platform.numberOfProcessors,
      }),
      samplingParams: SamplerParams(), // v0.2.2 uses SamplerParams
      // format: ChatMLFormat(), // Specifically for SmolLM2/ChatML models
    );

    // 3. Initialize the Managed Isolate
    _llamaParent = LlamaParent(loadCommand);
    await _llamaParent!.init();
  }

  /// Elaborates plant data into a suggestion
  Stream<String> getPlantSuggestion(String status) {
    // Note: We don't use async* here because LlamaParent.stream is already a stream
    if (_llamaParent == null) {
      initModel();
    }

    // Send the prompt to the isolate
    _llamaParent!.sendPrompt(status);

    // Return the output stream directly
    return _llamaParent!.stream;
  }

  void dispose() {
    // LlamaParent handles the shutdown of the background isolate
    _llamaParent?.dispose();
  }
}
