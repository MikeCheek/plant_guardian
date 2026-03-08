import 'dart:typed_data';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:tiktoken/tiktoken.dart';

class InferenceRequest {
  final String prompt;
  final Uint8List modelBytes;

  InferenceRequest(this.prompt, this.modelBytes);
}

Future<String> runInference(InferenceRequest req) async {
  OrtEnv.instance.init();

  final sessionOptions = OrtSessionOptions();

  final session = OrtSession.fromBuffer(req.modelBytes, sessionOptions);

  final tokenizer = getEncoding("gpt2");

  final tokens = tokenizer.encode(req.prompt);
  final generated = List<int>.from(tokens);

  const int maxNewTokens = 100;
  const int fixedLength = 34;
  const int eosTokenId = 50256;

  for (int i = 0; i < maxNewTokens; i++) {
    final inputIds = _buildInput(generated, fixedLength);

    final inputTensor = OrtValueTensor.createTensorWithDataList(
      Int64List.fromList(inputIds),
      [1, fixedLength],
    );

    final outputs = session.run(OrtRunOptions(), {'input': inputTensor});

    final logits = outputs.first!.value as List<List<List<double>>>;

    final lastLogits = logits[0].last;

    final next = _argMax(lastLogits);

    inputTensor.release();

    if (next == eosTokenId) break;

    generated.add(next);
  }

  session.release();

  return tokenizer.decode(generated.sublist(tokens.length)).trim();
}

List<int> _buildInput(List<int> tokens, int size) {
  if (tokens.length >= size) {
    return tokens.sublist(tokens.length - size);
  }

  final result = List<int>.filled(size, 0);
  final start = size - tokens.length;

  for (int i = 0; i < tokens.length; i++) {
    result[start + i] = tokens[i];
  }

  return result;
}

int _argMax(List<double> list) {
  double maxVal = -double.infinity;
  int maxIdx = 0;

  for (int i = 0; i < list.length; i++) {
    if (list[i] > maxVal) {
      maxVal = list[i];
      maxIdx = i;
    }
  }

  return maxIdx;
}
