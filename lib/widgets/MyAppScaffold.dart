import 'package:flutter/material.dart';
import 'package:plant_guardian/pages/HomeScreen.dart';
import 'package:plant_guardian/pages/ImageClassifierLiveScreen.dart';
import 'package:plant_guardian/pages/ImageClassifierScreen.dart';
import 'package:plant_guardian/pages/ChatScreen.dart';

import '../pages/WelcomeScreen.dart';
import '../theme.dart';
import 'drawer.dart';

class MyAppScaffold extends StatefulWidget {
  const MyAppScaffold({Key? key}) : super(key: key);

  @override
  State<MyAppScaffold> createState() => _MyAppScaffoldState();
}

class _MyAppScaffoldState extends State<MyAppScaffold> {
  int _selectedIndex = 0;
  late bool _isDarkMode;

  final List<Widget> _pages = [
    const WelcomeScreen(),
    const HomeScreen(),
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
