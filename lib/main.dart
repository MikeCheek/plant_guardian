import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:plant_guardian/services/notification_service.dart';
import 'package:plant_guardian/theme.dart';
import 'package:plant_guardian/widgets/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';

import 'pages/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'widgets/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  final notificationService = NotificationService();
  await notificationService.initNotification();
  // Request POST_NOTIFICATIONS runtime permission (required on Android 13+)
  await notificationService.requestNotificationPermission();

  await Workmanager().initialize(callbackDispatcher);

  // Only register the daily watering-check task if the user has it enabled in
  // their profile. This prevents re-registering a task the user has disabled.
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final thirstyAlerts = (userDoc.data()?['thirstyAlerts'] as bool?) ?? false;
    if (thirstyAlerts) {
      await Workmanager().registerPeriodicTask(
        "watering-check-task",
        "checkWateringNeeds",
        frequency: const Duration(hours: 24),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    }
  }

  runApp(ChangeNotifierProvider(create: (_) => AuthService(), child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    ThemeMode resolvedMode = ThemeMode.system;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final dynamic rawDarkMode = userDoc.data()?['darkMode'];
        if (rawDarkMode is bool) {
          resolvedMode = rawDarkMode ? ThemeMode.dark : ThemeMode.light;
        }
      }
    } catch (_) {
      resolvedMode = ThemeMode.system;
    }

    if (!mounted) return;
    setState(() {
      _themeMode = resolvedMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: SplashScreen(),
    );
  }
}
