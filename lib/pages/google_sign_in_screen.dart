import 'package:flutter/material.dart';
import 'package:plant_guardian/widgets/auth_service.dart';

class GoogleSignInScreen extends StatefulWidget {
  @override
  _GoogleSignInScreenState createState() => _GoogleSignInScreenState();
}

class _GoogleSignInScreenState extends State<GoogleSignInScreen> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Google Sign In')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              await _authService.signInWithGoogle();
              Navigator.pushReplacementNamed(context, '/home');
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error signing in with Google: $e')),
              );
            }
          },
          child: Text('Sign In with Google'),
        ),
      ),
    );
  }
}
