import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text(
            'Plant Guardian',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your personal plant care assistant',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.local_florist, size: 100, color: Colors.green),
          if (user != null) ...[
            const SizedBox(height: 20),
            Text(
              'Logged in as: ${user.displayName}',
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ] else ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/welcome');
              },
              child: const Text('Login'),
            ),
          ],
        ],
      ),
    );
  }
}
