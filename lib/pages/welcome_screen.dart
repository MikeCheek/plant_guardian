// import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:plant_guardian/colors.dart';
import 'package:plant_guardian/widgets/garden_model.dart';
// import 'package:shared_preferences/shared_preferences.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _checking = true;
  Map<String, dynamic>? _userInfo;

  @override
  void initState() {
    super.initState();
    _checkLoggedIn();
  }

  Future<void> _checkLoggedIn() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await user.reload();
        user = FirebaseAuth.instance.currentUser;

        if (!mounted) return;

        setState(() {
          _userInfo = {
            'uid': user!.uid,
            'email': user.email,
            'displayName': user.displayName,
          };
          _checking = false; // <-- stop loading so UI can show email
        });

        await preloadGardenInfo(user, FirebaseFirestore.instance);

        // Wait before navigating
        await Future.delayed(const Duration(seconds: 1));

        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/', arguments: _userInfo);
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _checking = false);
  }

  void _openLogin() {
    Navigator.of(context).pushNamed('/login');
  }

  void _openRegister() {
    Navigator.of(context).pushNamed('/register');
  }

  void _openGoogleSignIn() {
    Navigator.of(context).pushNamed('/googleSignIn');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (_checking) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading your garden workspace...',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (_userInfo != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome back!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                _userInfo!['displayName'] ?? '',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient(isDark),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.eco, color: scheme.primary, size: 56),
                        const SizedBox(height: 12),
                        Text(
                          'Plant Guardian',
                          style: theme.textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Houseplant Care Management',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/guardian.png',
                            width: 150,
                            height: 220,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Monitor watering needs, keep every room thriving, and get instant AI guidance.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _openLogin,
                            child: const Text('Log In'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _openRegister,
                            child: const Text('Create Account'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openGoogleSignIn,
                            icon: const Icon(Icons.account_circle_outlined),
                            label: const Text('Sign In with Google'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed('/');
                          },
                          child: const Text('Continue as Guest'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
