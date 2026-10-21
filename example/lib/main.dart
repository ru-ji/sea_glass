import 'package:flutter/material.dart';

import 'pages/everyday_pages.dart';
import 'pages/playground_page.dart';
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
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3B7D66),
        useMaterial3: true,
        fontFamily: 'Google Sans',
        scaffoldBackgroundColor: paper,
        navigationBarTheme: const NavigationBarThemeData(backgroundColor: paper),
      ),
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
        children: const [MusicPage(), PostPage(), NoriPage(), PlaygroundPage(), PromoPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (i) => setState(() => page = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.music_note_outlined), label: 'Music'),
          NavigationDestination(icon: Icon(Icons.mail_outline), label: 'Mail'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), label: 'Nori'),
          NavigationDestination(icon: Icon(Icons.science_outlined), label: 'Playground'),
          NavigationDestination(icon: Icon(Icons.movie_outlined), label: 'Promo'),
        ],
      ),
    );
  }
}
