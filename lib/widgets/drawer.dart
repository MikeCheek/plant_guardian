import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: const Text(
              'Plant Guardian',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Live camera Classifier'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/second');
            },
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Image Classifier'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/third');
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('Chat with Plant Guardian'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/chat');
            },
          ),
        ],
      ),
    );
  }
}
