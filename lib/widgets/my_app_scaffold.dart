import 'package:flutter/material.dart';
import 'package:plant_guardian/pages/garden_list_screen.dart';
import 'package:plant_guardian/pages/google_sign_in_screen.dart';
import 'package:plant_guardian/pages/home_screen.dart';
import 'package:plant_guardian/pages/image_classifier_live_screen.dart';
import 'package:plant_guardian/pages/image_classifier_screen.dart';
import 'package:plant_guardian/pages/chat_screen.dart';
import 'package:plant_guardian/pages/login_screen.dart';
import 'package:plant_guardian/pages/new_plant_screen.dart';
import 'package:plant_guardian/pages/plant_info_screen.dart';
import 'package:plant_guardian/pages/register_screen.dart';
import 'package:plant_guardian/pages/user_screen.dart';

import '../pages/welcome_screen.dart';
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
    const HomeScreen(),
    GardenListScreen(),
    ImageClassifierScreen(),
    const ChatScreen(),
    UserScreen(),
  ];

  final List<String> _titles = [
    'Plant Guardian',
    'Garden',
    'Image Classifier',
    '🤖 GuardAI 🪴',
    'Profile',
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
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/googleSignIn': (context) => GoogleSignInScreen(),
        '/plants': (context) => NewPlantScreen(),
        '/plant': (context) => PlantInfoScreen(
          plantDbId: ModalRoute.of(context)!.settings.arguments as String,
        ),
      },
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
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_florist),
              label: 'Garden',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.image), label: 'Gallery'),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
