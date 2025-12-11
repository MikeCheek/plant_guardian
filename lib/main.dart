import 'package:flutter/material.dart';
import 'package:plant_guardian/widgets/auth_service.dart';
import 'package:provider/provider.dart';

import 'pages/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'widgets/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print(firebaseOptions);
  await Firebase.initializeApp(options: firebaseOptions);
  runApp(ChangeNotifierProvider(create: (_) => AuthService(), child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: SplashScreen());
  }
}
