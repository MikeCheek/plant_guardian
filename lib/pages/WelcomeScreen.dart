// import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

        // Wait 2 seconds before navigating
        await Future.delayed(const Duration(seconds: 2));

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
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to Plant Guardian',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            Image.asset('assets/images/guardian.png', width: 200, height: 300),
            const SizedBox(height: 12),
            const Text(
              'Please log in to your account or register a new one to continue.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _openLogin,
                child: const Text('Log in'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _openRegister,
                child: const Text('Register'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _openGoogleSignIn,
                child: const Text('Sign in with Google'),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                // Optionally allow guest access to home without stored credentials
                Navigator.of(context).pushReplacementNamed('/');
              },
              child: const Text('Continue without logging in'),
            ),
          ],
        ),
      ),
    );
  }
}
