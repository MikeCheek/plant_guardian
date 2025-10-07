import 'package:flutter/material.dart';
import 'package:plant_guardian/pages/ImageClassifierLiveScreen.dart';
import 'package:plant_guardian/pages/ImageClassifierScreen.dart';

import 'TFLiteHelper.dart';
import 'theme.dart';

import 'package:flutter/services.dart' show rootBundle;

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
  bool _isDarkMode = false;

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
      initialRoute: '/',
      routes: {
        '/': (context) => MainLayout(
          title: 'Plant Guardian',
          isDarkMode: _isDarkMode,
          toggleTheme: _toggleTheme,
          showDrawer: true,
          showBack: false,
          child: const HomeContent(),
        ),
        '/second': (context) => MainLayout(
          title: 'Live camera Classifier',
          isDarkMode: _isDarkMode,
          toggleTheme: _toggleTheme,
          showDrawer: false,
          showBack: true,
          child: ImageClassifierLiveScreen(),
        ),
        '/third': (context) => MainLayout(
          title: 'Image Classifier',
          isDarkMode: _isDarkMode,
          toggleTheme: _toggleTheme,
          showDrawer: false,
          showBack: true,
          child: ImageClassifierScreen(),
        ),
      },
    );
  }
}

class MainLayout extends StatelessWidget {
  final Widget child;
  final bool isDarkMode;
  final VoidCallback toggleTheme;
  final String title;
  final bool showDrawer;
  final bool showBack;

  const MainLayout({
    Key? key,
    required this.child,
    required this.isDarkMode,
    required this.toggleTheme,
    required this.title,
    this.showDrawer = false,
    this.showBack = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: toggleTheme,
          ),
        ],
      ),
      drawer: showDrawer ? const AppDrawer() : null,
      body: child,
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: const Text(
              'Plant Guardian',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Live camera Classifier'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/second');
            },
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Image Classifier'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/third');
            },
          ),
        ],
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
