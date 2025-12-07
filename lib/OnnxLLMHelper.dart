import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:tiktoken/tiktoken.dart';

class OnnxLLMHelper {
  static late OrtSession _session;
  static bool _isInitialized = false;
  static late Tiktoken _tokenizer;

  // --- Model / Configuration ---
  static const String modelFile = 'assets/llm/gpt2-small124M-sft.onnx';
  static const int vocabSize = 50257;
  static const int maxSequenceLength = 1024;
  static const int FIXED_SEQ_LENGTH = 34;
  static const int PADDING_TOKEN_ID = 50256;
  static const List<String> inputNames = ['input'];
  static const List<String> outputNames = ['output'];

  // --- Generation Settings ---
  static const int maxNewTokens = 100;
  static const int eosTokenId = 50256; // <|endoftext|>

  // ... (init and dispose methods remain unchanged)

  static Future<void> init() async {
    try {
      print("🔹 Initializing ONNX Runtime Environment...");
      OrtEnv.instance.init();

      final raw = await rootBundle.load(modelFile);
      final bytes = raw.buffer.asUint8List();

      final sessionOptions = OrtSessionOptions();
      _session = OrtSession.fromBuffer(bytes, sessionOptions);

      final gpt2Base = encodingForModel("gpt2");
      _tokenizer = Tiktoken(
        name: "gpt2_with_eot",
        patStr: gpt2Base.patStr,
        mergeableRanks: gpt2Base.mergeableRanks,
        specialTokens: {...gpt2Base.specialTokens, "<|endoftext|>": eosTokenId},
      );

      _isInitialized = true;
      print(
        "✅ ONNX Session and Tokenizer loaded successfully! (Fixed Length: $FIXED_SEQ_LENGTH)",
      );
    } catch (e, stack) {
      print("❌ Failed to initialize ONNX runtime or load model: $e");
      print(stack);
      try {
        OrtEnv.instance.release();
      } catch (_) {}
      _isInitialized = false;
    }
  }

  static void dispose() {
    if (_isInitialized) {
      try {
        _session.release();
      } catch (_) {}
      try {
        OrtEnv.instance.release();
      } catch (_) {}
      _isInitialized = false;
      print("🗑️ ONNX Session disposed.");
    }
  }

  // --- Core Generation Function (FIXED) ---
  static Stream<String> generate(dynamic promptOrTokens) async* {
    // CHANGED: from Future<String> to Stream<String>
    if (!_isInitialized) throw Exception("ONNX Session not initialized");

    List<int> currentTokens;

    // 1. Tokenize initial prompt or use provided tokens
    if (promptOrTokens is String) {
      currentTokens = _tokenizer.encode(promptOrTokens).toList();
    } else if (promptOrTokens is List<int>) {
      currentTokens = List.of(promptOrTokens);
    } else {
      throw Exception("Error: Input must be a String or List<int>.");
    }

    final initialLength = currentTokens.length;
    if (initialLength == 0)
      return; // Exit if prompt is empty (use 'return' for streams)

    print("⏳ Running ONNX inference loop for up to $maxNewTokens tokens...");

    for (int i = 0; i < maxNewTokens; i++) {
      // 2. Manage context window and padding (Unchanged)
      final int inputLength = currentTokens.length;
      List<int> inputTokens = inputLength > maxSequenceLength
          ? currentTokens.sublist(inputLength - maxSequenceLength)
          : currentTokens;

      final int currentInputLength = inputTokens.length;

      if (currentInputLength < FIXED_SEQ_LENGTH) {
        final int paddingNeeded = FIXED_SEQ_LENGTH - currentInputLength;
        final List<int> padding = List<int>.filled(
          paddingNeeded,
          PADDING_TOKEN_ID,
        );
        inputTokens = [...padding, ...inputTokens];
      } else if (currentInputLength > FIXED_SEQ_LENGTH) {
        inputTokens = inputTokens.sublist(
          currentInputLength - FIXED_SEQ_LENGTH,
        );
      }

      final int sequenceLength = FIXED_SEQ_LENGTH;
      final List<int> shape = [1, sequenceLength];

      // 3. Prepare Input Tensor (Unchanged)
      final inputTokensInt64 = Int64List.fromList(inputTokens);
      final inputIdsOrt = OrtValueTensor.createTensorWithDataList(
        inputTokensInt64,
        shape,
      );

      final inputs = {inputNames[0]: inputIdsOrt};

      // 4. Run Inference (Unchanged)
      List<OrtValue?>? outputs;
      final runOptions = OrtRunOptions();

      try {
        outputs = await _session.runAsync(runOptions, inputs);
      } catch (e) {
        print("❌ Inference error during generation step: $e");
        rethrow; // Re-throw the error so the stream consumer can catch it
      } finally {
        try {
          inputIdsOrt.release();
          runOptions.release();
        } catch (_) {}
      }

      // 5. Process Logits Output (Unchanged)
      if (outputs == null ||
          outputs.isEmpty ||
          outputs.first is! OrtValueTensor) {
        for (final o in outputs ?? []) {
          try {
            o?.release();
          } catch (_) {}
        }
        throw Exception("Model returned invalid output.");
      }

      final OrtValueTensor logitsOutput = outputs.first! as OrtValueTensor;
      final Float32List logitsData;

      // ... (Logits extraction logic remains the same)

      try {
        final dynamic nestedValue = logitsOutput.value;
        List<double> rawLogitsList = [];

        if (nestedValue is List) {
          for (final sequenceLogits in nestedValue) {
            if (sequenceLogits is List) {
              for (final tokenLogits in sequenceLogits) {
                if (tokenLogits is List) {
                  rawLogitsList.addAll(tokenLogits.cast<double>());
                } else if (tokenLogits is double) {
                  rawLogitsList.add(tokenLogits);
                }
              }
            }
          }
        }
        logitsData = Float32List.fromList(rawLogitsList);
        if (logitsData.length != FIXED_SEQ_LENGTH * vocabSize) {
          throw Exception(
            "Logits size mismatch. Got ${logitsData.length}, expected ${FIXED_SEQ_LENGTH * vocabSize}.",
          );
        }
      } catch (e) {
        print("❌ Logits data extraction failed: $e");
        for (final o in outputs) {
          try {
            o?.release();
          } catch (_) {}
        }
        rethrow;
      }

      // Release output tensor
      for (final o in outputs) {
        try {
          o?.release();
        } catch (_) {}
      }

      // 6. Select the next token (Greedy Search)
      final int lastTokenIndexInInput = FIXED_SEQ_LENGTH - 1;
      final int lastTokenLogitsStart = lastTokenIndexInInput * vocabSize;

      int nextTokenId = -1;
      double maxLogit = double.negativeInfinity;

      for (int k = 0; k < vocabSize; k++) {
        final currentLogit = logitsData[lastTokenLogitsStart + k];
        if (currentLogit > maxLogit) {
          maxLogit = currentLogit;
          nextTokenId = k;
        }
      }

      // 7. Check for EOS and Append
      if (nextTokenId == -1 || nextTokenId == eosTokenId) {
        print("Model generated EOS token or finished.");
        break;
      }

      currentTokens.add(nextTokenId);

      // *** CRITICAL CHANGE: YIELD THE NEWLY GENERATED TEXT ***
      // Decode the new token (from currentTokens list) and send it immediately.
      final generatedTokens = currentTokens.sublist(initialLength);
      final decodedText = _tokenizer.decode(generatedTokens);

      // Use 'yield' to send the current decoded text down the stream
      yield decodedText;
    }
  }
}
