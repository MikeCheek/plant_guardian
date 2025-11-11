import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final prefs = await SharedPreferences.getInstance();
    final logged = prefs.getBool('isLoggedIn') ?? false;
    if (logged) {
      final rawUser = prefs.getString('userInfo');
      if (rawUser != null) {
        try {
          _userInfo = jsonDecode(rawUser) as Map<String, dynamic>;
        } catch (_) {
          _userInfo = null;
        }
      }
      if (!mounted) return;
      // Replace route with home and pass loaded user info as arguments (optional)
      Navigator.of(context).pushReplacementNamed('/home', arguments: _userInfo);
      return;
    }

    if (!mounted) return;
    setState(() {
      _checking = false;
    });
  }

  void _openLogin() {
    Navigator.of(context).pushNamed('/login');
  }

  void _openRegister() {
    Navigator.of(context).pushNamed('/register');
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                // Optionally allow guest access to home without stored credentials
                Navigator.of(context).pushReplacementNamed('/home');
              },
              child: const Text('Continue without logging in'),
            ),
          ],
        ),
      ),
    );
  }
}
