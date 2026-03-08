import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:plant_guardian/pages/garden_list_screen.dart';
import 'package:plant_guardian/pages/google_sign_in_screen.dart';
import 'package:plant_guardian/pages/home_screen.dart';
// import 'package:plant_guardian/pages/image_classifier_live_screen.dart';
import 'package:plant_guardian/pages/image_classifier_screen.dart';
import 'package:plant_guardian/pages/chat_screen_online.dart';
import 'package:plant_guardian/pages/login_screen.dart';
import 'package:plant_guardian/pages/new_plant_screen.dart';
import 'package:plant_guardian/pages/plant_info_screen.dart';
import 'package:plant_guardian/pages/reset_password_screen.dart';
import 'package:plant_guardian/pages/register_screen.dart';
import 'package:plant_guardian/pages/user_screen.dart';

import '../colors.dart';
import '../pages/welcome_screen.dart';
import '../theme.dart';

class MyAppScaffold extends StatefulWidget {
  const MyAppScaffold({Key? key}) : super(key: key);

  @override
  State<MyAppScaffold> createState() => _MyAppScaffoldState();
}

class _MyAppScaffoldState extends State<MyAppScaffold> {
  int _selectedIndex = 0;
  late bool _isDarkMode = true;

  final List<Widget> _pages = [
    const HomeScreen(),
    GardenListScreen(),
    ImageClassifierScreen(),
    const ChatScreenOnline(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Gardens',
    'Vision',
    'GreenThumb AI',
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
    final bool isDark = _isDarkMode;
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return MaterialApp(
      title: 'Plant Guardian',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/resetPassword': (context) => const ResetPasswordScreen(),
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_titles[_selectedIndex]),
              // Text(
              //   'Houseplant Care Management',
              //   style: TextStyle(
              //     fontSize: 11,
              //     letterSpacing: 0.4,
              //     color: isDark ? Colors.white70 : Colors.black54,
              //   ),
              // ),
            ],
          ),
          automaticallyImplyLeading: false,
          toolbarHeight: 72,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: AppColors.shellGradient(isDark),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: _buildAppBarAction(),
            ),
          ],
        ),
        body: _pages[_selectedIndex],
        bottomNavigationBar: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isKeyboardOpen
              ? const SizedBox.shrink()
              : ClipRRect(
                  child: NavigationBar(
                    height: 70,
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _onItemTapped,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.local_florist_outlined),
                        selectedIcon: Icon(Icons.local_florist),
                        label: 'Garden',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.image_search_outlined),
                        selectedIcon: Icon(Icons.image_search),
                        label: 'Vision',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.chat_bubble_outline),
                        selectedIcon: Icon(Icons.chat_bubble),
                        label: 'Chat',
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
