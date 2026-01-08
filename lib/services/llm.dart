import 'dart:async';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:plant_guardian/OnnxLLMHelper.dart';

void _llmWorker(SendPort mainSendPort) async {
  final workerReceivePort = ReceivePort();
  mainSendPort.send(workerReceivePort.sendPort);

  workerReceivePort.listen((message) async {
    if (message is Map && message.containsKey('modelBytes')) {
      final Uint8List bytes = message['modelBytes'];
      final SendPort initReplyPort = message['replyPort'];
      await OnnxLLMHelper.initWithBytes(bytes);
      initReplyPort.send(true);
      return;
    }

    final String prompt = message['prompt'];
    final SendPort replyPort = message['replyPort'];

    try {
      await for (final token in OnnxLLMHelper.generate(prompt)) {
        replyPort.send({'status': 'partial', 'text': token});
      }
      replyPort.send({'status': 'complete'});
    } catch (e) {
      replyPort.send({'status': 'error', 'text': e.toString()});
    }
  });
}

class OnnxInferenceLLM {
  SendPort? _workerSendPort;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    final data = await rootBundle.load(OnnxLLMHelper.modelFile);
    final bytes = data.buffer.asUint8List();

    final receivePort = ReceivePort();
    await Isolate.spawn(_llmWorker, receivePort.sendPort);
    _workerSendPort = await receivePort.first as SendPort;

    final initReplyPort = ReceivePort();
    _workerSendPort?.send({
      'modelBytes': bytes,
      'replyPort': initReplyPort.sendPort,
    });

    await initReplyPort.first;
    _initialized = true;
  }

  Future<void> ask(
    String userMessage, {
    required void Function(String) onThinking,
    required void Function(String) onPartialResponse,
    required void Function(String) onCompleted,
    void Function(String error)? onError,
  }) async {
    if (!_initialized) await init();

    onThinking("💭 I'm thinking...");
    final responsePort = ReceivePort();

    _workerSendPort?.send({
      'prompt': userMessage,
      'replyPort': responsePort.sendPort,
    });

    responsePort.listen((message) {
      final status = message['status'] as String;
      if (status == 'partial') {
        onPartialResponse(message['text'] as String);
      } else if (status == 'complete') {
        onCompleted("");
        responsePort.close();
      } else if (status == 'error' && onError != null) {
        onError(message['text'] as String);
        responsePort.close();
      }
    });
  }

  void dispose() {
    OnnxLLMHelper.dispose();
  }
}
