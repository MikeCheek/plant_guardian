import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
    );
  }
}
