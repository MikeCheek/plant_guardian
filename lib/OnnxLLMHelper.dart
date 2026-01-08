import 'dart:async';
import 'dart:typed_data';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:tiktoken/tiktoken.dart';

class OnnxLLMHelper {
  static late OrtSession _session;
  static bool _isInitialized = false;
  static late Tiktoken _tokenizer;

  // Preallocated reusable buffers
  static late OrtValueTensor reusableInputTensor;
  static late Int64List reusableInt64Buffer;
  static late Float32List reusableLogitsBuffer;

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
  static const int eosTokenId = 50256;
  static const int topK = 50; // Limit greedy search to top candidates

  static Future<void> initWithBytes(Uint8List bytes) async {
    try {
      OrtEnv.instance.init();

      // OPTIMIZED: Configure session with graph optimizations
      final sessionOptions = OrtSessionOptions();

      sessionOptions.setSessionGraphOptimizationLevel(
        GraphOptimizationLevel.ortEnableBasic,
      ); // ORT_ENABLE_EXTENDED

      _session = OrtSession.fromBuffer(bytes, sessionOptions);

      // Initialize tokenizer
      final gpt2Base = encodingForModel("gpt2");
      _tokenizer = Tiktoken(
        name: "gpt2_with_eot",
        patStr: gpt2Base.patStr,
        mergeableRanks: gpt2Base.mergeableRanks,
        specialTokens: {...gpt2Base.specialTokens, "<|endoftext|>": eosTokenId},
      );

      // Preallocate reusable buffers ONCE
      _allocateReusableBuffers();

      _isInitialized = true;
    } catch (e) {
      print("Error in Isolate Init: $e");
      rethrow;
    }
  }

  static void _allocateReusableBuffers() {
    final shape = [1, FIXED_SEQ_LENGTH];

    // Input buffer
    reusableInt64Buffer = Int64List(FIXED_SEQ_LENGTH);
    reusableInputTensor = OrtValueTensor.createTensorWithDataList(
      reusableInt64Buffer,
      shape,
    );

    reusableLogitsBuffer = Float32List(1 * FIXED_SEQ_LENGTH * vocabSize);
  }

  static void dispose() {
    if (_isInitialized) {
      try {
        reusableInputTensor.release();
      } catch (_) {}
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

  static int _selectNextToken(Float32List logits, int lastRealTokenIndex) {
    final offset = lastRealTokenIndex * vocabSize;

    int maxIdx = 0;
    double maxVal = -double.infinity;

    for (int i = 0; i < vocabSize; i++) {
      final v = logits[offset + i];
      if (v > maxVal) {
        maxVal = v;
        maxIdx = i;
      }
    }
    return maxIdx;
  }

  static Stream<String> generate(dynamic promptOrTokens) async* {
    if (!_isInitialized) throw Exception("ONNX Session not initialized");

    List<int> currentTokens;
    if (promptOrTokens is String) {
      currentTokens = _tokenizer.encode(promptOrTokens).toList();
    } else if (promptOrTokens is List<int>) {
      currentTokens = List.of(promptOrTokens);
    } else {
      throw Exception("Input must be a String or List<int>.");
    }

    final initialLength = currentTokens.length;
    if (initialLength == 0) return;

    print("⏳ Running optimized ONNX inference loop...");

    for (int i = 0; i < maxNewTokens; i++) {
      print("Generating token ${i + 1}/$maxNewTokens...");
      // Prepare fixed-length input using REUSABLE buffers
      final inputLength = currentTokens.length;
      List<int> inputTokens = inputLength > maxSequenceLength
          ? currentTokens.sublist(inputLength - maxSequenceLength)
          : currentTokens;

      final currentInputLength = inputTokens.length;

      // Update reusable buffer in-place (NO allocations)
      if (currentInputLength < FIXED_SEQ_LENGTH) {
        reusableInt64Buffer.setRange(0, currentInputLength, inputTokens);
        reusableInt64Buffer.fillRange(
          currentInputLength,
          FIXED_SEQ_LENGTH,
          PADDING_TOKEN_ID,
        );
      } else {
        reusableInt64Buffer.setRange(
          0,
          FIXED_SEQ_LENGTH,
          inputTokens.sublist(currentInputLength - FIXED_SEQ_LENGTH),
        );
      }

      final inputs = {inputNames[0]: reusableInputTensor};

      // Run inference
      List<OrtValue?>? outputs;
      try {
        outputs = await _session.runAsync(OrtRunOptions(), inputs);
      } catch (e) {
        print("❌ Inference error: $e");
        rethrow;
      }

      // Process output using preallocated buffer
      final OrtValueTensor logitsOutput = outputs!.first! as OrtValueTensor;
      final Float32List flatLogits = logitsOutput.value as Float32List;

      final lastRealTokenIndex = (currentInputLength - 1).clamp(
        0,
        FIXED_SEQ_LENGTH - 1,
      );
      print("Selecting next token from index: $lastRealTokenIndex");

      final int nextTokenId = _selectNextToken(flatLogits, lastRealTokenIndex);

      // // Copy to reusable buffer once (avoid repeated tensor access)
      // reusableLogitsBuffer.setAll(0, flatLogits);

      print("Next token ID: $nextTokenId");

      for (final o in outputs) o?.release();

      print("Yielding token...");

      // Fast token selection
      // final int nextTokenId = _selectNextToken(reusableLogitsBuffer);

      if (nextTokenId == eosTokenId) {
        print("Model generated EOS token.");
        break;
      }

      print("Appending token ID to sequence.");
      currentTokens.add(nextTokenId);

      yield _tokenizer.decode([nextTokenId]);
    }
  }
}
