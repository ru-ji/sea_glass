import 'package:flutter/material.dart';

import 'pages/pill_page.dart';
import 'pages/playground_page.dart';
import 'pages/quick_settings_page.dart';
import 'promo/promo_scene.dart';

void main() => runApp(const SeaGlassExampleApp());

class SeaGlassExampleApp extends StatelessWidget {
  const SeaGlassExampleApp({super.key, this.initialPage = 0});

  final int initialPage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sea Glass',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1E6F7C), useMaterial3: true),
      home: ExampleHome(initialPage: initialPage),
    );
  }
}

class ExampleHome extends StatefulWidget {
  const ExampleHome({super.key, this.initialPage = 0});

  final int initialPage;

  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  late int page = widget.initialPage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: page,
        sizing: StackFit.expand,
        children: const [QuickSettingsPage(), PillPage(), PlaygroundPage(), PromoPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (i) => setState(() => page = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.tune), label: 'Quick settings'),
          NavigationDestination(icon: Icon(Icons.smart_button_outlined), label: 'Pill'),
          NavigationDestination(icon: Icon(Icons.science_outlined), label: 'Playground'),
          NavigationDestination(icon: Icon(Icons.movie_outlined), label: 'Promo'),
        ],
      ),
    );
  }
}
