import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tokenizer_parser/tokenizer_parser.dart';

class TokenizerHelper {
  late Map<int, String> idToToken = {};
  late Map<String, int> tokenToId = {};

  TokenizerHelper();

  Future<void> loadVocab(String vocabPath) async {
    final vocabJson = await rootBundle.loadString(vocabPath);
    final Map<String, dynamic> vocabMap = json.decode(vocabJson);
    tokenToId = vocabMap.map((k, v) => MapEntry(k, v as int));
    idToToken = vocabMap.map((k, v) => MapEntry(v as int, k));
  }

  String detokenize(List<int> tokenIds) {
    // Simple detokenize by joining tokens; customize for BPE if needed
    return tokenIds
        .map((id) => idToToken[id] ?? '')
        .join(' ')
        .replaceAll('##', '');
  }
}

class AIAgent {
  Interpreter? _interpreter;
  late TokenizerHelper _tokenizer;
  bool _initialized = false;

  final int sequenceLength = 64;
  final int vocabSize = 50257;

  Future<void> init() async {
    if (_initialized) return;

    try {
      // Load TensorFlow Lite model with options (e.g., threads)
      var options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        'assets/llm/distilgpt2.tflite',
        options: options,
      );

      // Load tokenizer vocab for detokenization
      _tokenizer = TokenizerHelper();
      await _tokenizer.loadVocab('assets/llm/vocab.json');

      _initialized = true;
      print("✅ Model loaded successfully!");
    } catch (e) {
      print("❌ Failed to load model or vocab: $e");
      rethrow;
    }
  }

  List<int> _prepareInput(List<int> tokenIds) {
    final padded = List<int>.from(tokenIds);
    if (padded.length > sequenceLength) {
      return padded.sublist(0, sequenceLength);
    }
    if (padded.length < sequenceLength) {
      padded.addAll(List.filled(sequenceLength - padded.length, 0));
    }
    return padded;
  }

  List<int> _logitsToTokens(List<List<double>> logits) {
    return logits.map((logitRow) {
      double maxVal = logitRow[0];
      int maxIdx = 0;
      for (int i = 1; i < logitRow.length; i++) {
        if (logitRow[i] > maxVal) {
          maxVal = logitRow[i];
          maxIdx = i;
        }
      }
      return maxIdx;
    }).toList();
  }

  Future<String> ask(String userMessage) async {
    if (!_initialized) await init();

    try {
      // Tokenize user input (use your tokenizer)
      final rawTokenIds = Tokenizer.tokenize(userMessage, []).$1.cast<int>();

      // Pad or truncate to fixed length
      final inputTokens = _prepareInput(rawTokenIds);

      // Prepare input tensor as List<List<int>> shape [1, sequenceLength]
      var input = [inputTokens];

      // Prepare output tensor as List<List<List<double>>> shape [1, sequenceLength, vocabSize]
      var output = List.generate(
        1,
        (_) =>
            List.generate(sequenceLength, (_) => List.filled(vocabSize, 0.0)),
      );

      if (_interpreter == null) {
        throw Exception('Interpreter is null');
      }

      // Run inference
      _interpreter!.run(input, output);

      // Convert logits to token indices
      final outputTokens = _logitsToTokens(output[0]);

      // Detokenize output tokens back to string
      final response = _tokenizer.detokenize(outputTokens);

      return response;
    } catch (e) {
      print('❌ Inference error: $e');
      return "Sorry, I couldn't generate a response right now.";
    }
  }
}
