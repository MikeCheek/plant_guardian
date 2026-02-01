import 'package:flutter/material.dart';
import 'package:plant_guardian/services/notification_service.dart';
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

  await Workmanager().initialize(callbackDispatcher);

  // Register the daily task
  await Workmanager().registerPeriodicTask(
    "watering-check-task", // Unique name
    "checkWateringNeeds", // Task identifier
    frequency: const Duration(hours: 24), // Every day
    constraints: Constraints(
      networkType: NetworkType.connected, // Only run if internet is available
    ),
  );

  runApp(ChangeNotifierProvider(create: (_) => AuthService(), child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: SplashScreen());
  }
}
