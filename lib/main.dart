import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/mobile/flutter_gemma_mobile.dart';
import 'package:plant_guardian/pages/ImageClassifierLiveScreen.dart';
import 'package:plant_guardian/pages/ImageClassifierScreen.dart';
import 'package:plant_guardian/pages/ChatScreen.dart';

import 'TFLiteHelper.dart';
import 'pages/WelcomeScreen.dart';
import 'theme.dart';

import 'package:flutter/services.dart' show rootBundle;

import 'widgets/drawer.dart';

Future<void> listAssets() async {
  try {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    print('Asset Manifest:');
    print(manifestContent);
  } catch (e) {
    print('Error loading asset manifest: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const token = const String.fromEnvironment('HUGGINGFACE_TOKEN');

  FlutterGemma.initialize(huggingFaceToken: token.isNotEmpty ? token : null);

  // Install an inference model first so FlutterGemma has an active model for inference.
  await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
      .fromNetwork(
        // 'https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma3-270m-it-q8.task',
        "https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task",
        token: token.isNotEmpty ? token : null,
      )
      .withProgress((progress) {
        print('Downloading model: ${progress}%');
      })
      .install();

  // await FlutterGemma.installEmbedder()
  //     .modelFromNetwork(
  //       'https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/embeddinggemma-300M_seq1024_mixed-precision.tflite',
  //       token: token.isNotEmpty ? token : null,
  //     )
  //     .tokenizerFromNetwork(
  //       'https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/sentencepiece.model',
  //     )
  //     .withModelProgress((progress) => print('Model: $progress%'))
  //     .withTokenizerProgress((progress) => print('Tokenizer: $progress%'))
  //     .install();

  await listAssets();
  await TFLiteHelper.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;
  late bool _isDarkMode;

  final List<Widget> _pages = [
    const WelcomeScreen(),
    const HomeContent(),
    ImageClassifierLiveScreen(),
    ImageClassifierScreen(),
    const ChatScreen(),
  ];

  final List<String> _titles = [
    "Welcome",
    'Plant Guardian',
    'Live Camera Classifier',
    'Image Classifier',
    '🤖 GuardAI 🪴',
  ];

  @override
  void initState() {
    super.initState();
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _isDarkMode = brightness == Brightness.dark;
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged =
        () {
          final newBrightness =
              WidgetsBinding.instance.platformDispatcher.platformBrightness;
          setState(() {
            _isDarkMode = newBrightness == Brightness.dark;
          });
        };
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plant Guardian',
      theme: _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text(_titles[_selectedIndex]),
          actions: [
            IconButton(
              icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: _toggleTheme,
            ),
          ],
        ),
        drawer: _selectedIndex == 0 ? const AppDrawer() : null,
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Welcome'),
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt),
              label: 'Live',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.image), label: 'Gallery'),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          ],
        ),
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Image.asset('assets/images/guardian.png', width: 200, height: 300),
          const SizedBox(height: 20),
          const Text(
            'Welcome to Plant Guardian',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your personal plant care assistant',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
