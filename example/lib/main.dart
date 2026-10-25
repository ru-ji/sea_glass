import 'package:flutter/material.dart';

import 'pages/everyday_pages.dart';

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
      ),
      home: ExampleHome(initialPage: initialPage),
    );
  }
}

/// The three screens, full screen. Swipe to move between them.
class ExampleHome extends StatefulWidget {
  const ExampleHome({super.key, this.initialPage = 0});

  final int initialPage;

  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  late final PageController controller = PageController(initialPage: widget.initialPage);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: controller,
        children: const [MusicPage(), PostPage(), NoriPage()],
      ),
    );
  }
}
