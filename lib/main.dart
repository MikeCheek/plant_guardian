import 'package:flutter/material.dart';
import 'package:plant_guardian/pages/ImageClassifierLiveScreen.dart';
import 'package:plant_guardian/pages/ImageClassifierScreen.dart';

import 'TFLiteHelper.dart';

import 'package:flutter/services.dart' show rootBundle;

Future<void> listAssets() async {
  try {
    // This gets the asset manifest, which lists all bundled assets
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    print('Asset Manifest:');
    print(manifestContent);
  } catch (e) {
    print('Error loading asset manifest: $e');
  }
}

// function to trigger build when the app is run
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await listAssets(); // <-- Check your assets here
  await TFLiteHelper.init();
  runApp(
    MaterialApp(
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeRoute(),
        '/second': (context) => ImageClassifierLiveScreen(),
        '/third': (context) => ImageClassifierScreen(),
      },
      debugShowCheckedModeBanner: false,
    ),
  ); //MaterialApp
}

class HomeRoute extends StatelessWidget {
  const HomeRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Guardian'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ), // AppBar
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.green),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              child: const Text('Live camera Classifier'),
              onPressed: () {
                Navigator.pushNamed(context, '/second');
              },
            ), // ElevatedButton
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.green),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              child: const Text('Image Classifier'),
              onPressed: () {
                Navigator.pushNamed(context, '/third');
              },
            ), // ElevatedButton
          ], // <Widget>[]
        ), // Column
      ), // Center
    ); // Scaffold
  }
}
