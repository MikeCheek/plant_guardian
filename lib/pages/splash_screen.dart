import 'package:flutter/material.dart';
// import 'package:flutter_gemma/flutter_gemma.dart';
// import 'package:flutter_gemma/mobile/flutter_gemma_mobile.dart';
import 'package:plant_guardian/OnnxLLMHelper.dart';

import '../TFLiteHelper.dart';
import '../widgets/my_app_scaffold.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double progress = 0.0;
  String status = "Initializing...";

  @override
  void initState() {
    super.initState();
    initializeApp();
  }

  Future<void> initializeApp() async {
    // const token = String.fromEnvironment('HUGGINGFACE_TOKEN');

    final steps = [
      // {
      //   "status": "Downloading AI model...",
      //   "action": () async {
      //     await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
      //         .fromNetwork(
      //           "https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task",
      //           // "https://huggingface.co/litert-community/DeepSeek-R1-Distill-Qwen-1.5B/resolve/main/deepseek_q8_ekv1280.task",
      //           token: token.isNotEmpty ? token : null,
      //         )
      //         .withProgress((prog) {
      //           setState(() {
      //             progress = 0.2 + (prog / 100) * 0.6;
      //           });
      //         })
      //         .install();
      //   },
      // },
      // {
      //   "status": "Initializing TFLite...",
      //   "action": () async => await TFLiteHelper.init(),
      // },
      // {
      //   "status": "Initializing ONNX LLM...",
      //   "action": () async => await OnnxLLMHelper.init(),
      // },
    ];

    for (final entry in steps.asMap().entries) {
      final index = entry.key;
      final step = entry.value;
      setState(() {
        status = step["status"] as String;
      });
      final action = step["action"] as Future<void> Function();
      await action();
      setState(() {
        progress = (index + 1) / steps.length;
      });
    }

    // After a short delay, navigate to your main app
    await Future.delayed(Duration(milliseconds: 500));
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => MyAppScaffold()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Welcome to Plant Guardian",
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.green,
              minHeight: 5,
            ),
            const SizedBox(height: 16),
            Text(status),
          ],
        ),
      ),
    );
  }
}
