import 'package:flutter/material.dart';

import 'drawer.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final bool isDarkMode;
  final VoidCallback toggleTheme;
  final String title;
  final bool showDrawer;
  final bool showBack;

  const MainLayout({
    Key? key,
    required this.child,
    required this.isDarkMode,
    required this.toggleTheme,
    required this.title,
    this.showDrawer = false,
    this.showBack = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: toggleTheme,
          ),
        ],
      ),
      drawer: showDrawer ? const AppDrawer() : null,
      body: child,
    );
  }
}
