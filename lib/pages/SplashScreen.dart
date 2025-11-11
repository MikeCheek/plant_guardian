import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/mobile/flutter_gemma_mobile.dart';

import '../TFLiteHelper.dart';
import '../widgets/MyAppScaffold.dart';

class SplashScreen extends StatefulWidget {
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
    const token = String.fromEnvironment('HUGGINGFACE_TOKEN');

    setState(() {
      status = "Downloading AI model...";
      progress = 0.2;
    });

    await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
        .fromNetwork(
          "https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task",
          // "https://huggingface.co/litert-community/DeepSeek-R1-Distill-Qwen-1.5B/resolve/main/deepseek_q8_ekv1280.task",
          token: token.isNotEmpty ? token : null,
        )
        .withProgress((prog) {
          setState(() {
            progress = 0.2 + (prog / 100) * 0.6;
          });
        })
        .install();

    setState(() {
      status = "Loading assets...";
      progress = 0.85;
    });

    setState(() {
      status = "Initializing TFLite...";
      progress = 0.93;
    });
    await TFLiteHelper.init();

    setState(() {
      progress = 1.0;
    });

    // After a short delay, navigate to your main app
    await Future.delayed(Duration(milliseconds: 500));
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => MyAppScaffold()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Welcome to Plant Guardian",
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 16),
            Text(status),
          ],
        ),
      ),
    );
  }
}
