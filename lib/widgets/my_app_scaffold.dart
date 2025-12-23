import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  ];

  final List<String> _titles = [
    'Plant Guardian',
    'Garden',
    'Image Classifier',
    '🤖 GuardAI 🪴',
  ];

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged =
        () {
          _loadThemePreference();
        };
  }

  Future<void> _loadThemePreference() async {
    final user = FirebaseAuth.instance.currentUser;
    bool darkMode;

    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          darkMode = userDoc.data()!['darkMode'] ?? false;
        } else {
          darkMode =
              WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark;
        }
      } catch (e) {
        darkMode =
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
      }
    } else {
      darkMode =
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }

    setState(() {
      _isDarkMode = darkMode;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleTheme() {
    var newMode = !_isDarkMode;

    setState(() {
      _isDarkMode = newMode;
    });

    // add or update preference on user document
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid);
      userDoc.set({'darkMode': newMode}, SetOptions(merge: true));
    }
  }

  Widget _buildAppBarAction() {
    final user = FirebaseAuth.instance.currentUser;

    // 2. If we are on any other page, show User Image
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        ImageProvider imageProvider = const AssetImage(
          "assets/images/user-placeholder.jpg",
        );

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String? photoData = data["photoUrl"];

          // Reuse your Base64 check logic
          if (photoData != null && photoData.startsWith('data:image')) {
            final base64String = photoData.split(',').last;
            imageProvider = MemoryImage(base64Decode(base64String));
          }
        }

        return GestureDetector(
          onTap: () => Navigator.of(context).pushNamed(
            '/user',
            arguments: {
              'isDarkMode': _isDarkMode,
              'onToggleTheme': _toggleTheme,
            },
          ),
          child: CircleAvatar(radius: 20, backgroundImage: imageProvider),
        );
      },
    );
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
        '/user': (context) =>
            UserScreen(isDarkMode: _isDarkMode, onToggleTheme: _toggleTheme),
      },
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text(_titles[_selectedIndex]),
          toolbarHeight: 60.0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: _buildAppBarAction(),
            ),
          ],
        ),
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
            BottomNavigationBarItem(
              icon: Icon(Icons.image),
              label: 'Recognizer',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          ],
        ),
      ),
    );
  }
}
