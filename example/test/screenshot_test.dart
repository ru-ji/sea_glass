// Renders each example page with the real shader and saves PNG screenshots
// to doc/screenshots. Run: flutter test test/screenshot_test.dart
// Fonts come from the Flutter SDK cache (Roboto and Material Icons).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sea_glass/sea_glass.dart';
import 'package:sea_glass_example/main.dart';
import 'package:sea_glass_example/pages/pill_page.dart';
import 'package:sea_glass_example/pages/messages_page.dart';
import 'package:sea_glass_example/pages/showcase_page.dart';
import 'package:sea_glass_example/pages/toolbars_page.dart';

import 'fonts.dart';

final _theme = ThemeData(fontFamily: 'Google Sans');

void main() {
  setUpAll(loadFonts);

  final pages = <(String, Widget)>[
    ('quick_settings', const SeaGlassExampleApp(initialPage: 0)),
    ('pill', const SeaGlassExampleApp(initialPage: 1)),
    ('playground', const SeaGlassExampleApp(initialPage: 2)),
    ('showcase', MaterialApp(debugShowCheckedModeBanner: false, theme: _theme, home: const ShowcasePage())),
    ('toolbars', MaterialApp(debugShowCheckedModeBanner: false, theme: _theme, home: const ToolbarsPage())),
    ('messages', MaterialApp(debugShowCheckedModeBanner: false, theme: _theme, home: const MessagesPage())),
    ('tumble_levels', MaterialApp(debugShowCheckedModeBanner: false, theme: _theme, home: const TumbleLevels())),
    ('shadow_directions', MaterialApp(debugShowCheckedModeBanner: false, theme: _theme, home: const ShadowDirections())),
  ];
  for (final (name, app) in pages) {
    testWidgets('screenshot $name', (tester) async {
      final wide = name == 'showcase' || name == 'toolbars' || name == 'messages';
      tester.view.physicalSize = name == 'messages' ? const Size(2000, 1400) : wide ? const Size(2000, 1125) : const Size(1080, 2340);
      tester.view.devicePixelRatio = wide ? 2 : 2.625;
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: boundary, child: app));
      // Let shader loading and geometry builds finish; they run in the real zone.
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      final bytes = await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: wide ? 2 : 2.625);
        return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      });
      Directory('../doc/screenshots').createSync(recursive: true);
      File('../doc/screenshots/$name.png').writeAsBytesSync(bytes!);
      expect(tester.takeException(), isNull);
    });
  }
}

/// New pieces with the ground light in a few directions, tints and alphas.
class ShadowDirections extends StatelessWidget {
  const ShadowDirections({super.key});

  static const blue = SeaGlassPalette(body: Color(0xFF63B4F2), edge: Color(0xFFC4E8FF), ink: Color(0xFF0B3A6B));
  static const lemon = SeaGlassPalette(body: Color(0xFFE6E58A), edge: Color(0xFFFFFBC0), ink: Color(0xFF5C5200));
  static const peach = SeaGlassPalette(body: Color(0xFFF5B27A), edge: Color(0xFFFFD9B0), ink: Color(0xFF7A3A10));
  static const berry = SeaGlassPalette(body: Color(0xFFD81B7A), edge: Color(0xFFFF9FD0), ink: Colors.white);
  static const lilac = SeaGlassPalette(body: Color(0xFFE3A8F5), edge: Color(0xFFF8DBFF), ink: Color(0xFF5E1F80));

  @override
  Widget build(BuildContext context) {
    Widget piece(SeaGlassPalette p, double w, double h, SeaGlassShape shape, SeaGlassStyle style, IconData icon,
            String label) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 26),
          child: SeaGlassSurface(
            width: w,
            height: h,
            shape: shape,
            palette: p,
            style: style,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 24), const SizedBox(width: 10), Text(label, style: const TextStyle(fontSize: 19)),
            ]),
          ),
        );
    return Material(
      color: Colors.white,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          piece(blue, 260, 64, SeaGlassShape.capsule, pillStyle.copyWith(seed: 1), Icons.south, '180° down'),
          piece(lemon, 260, 64, SeaGlassShape.capsule, pillStyle.copyWith(shadowDegrees: 135, shadowTinted: true, seed: 2),
              Icons.south_east, '135° tinted'),
          piece(peach, 200, 96, SeaGlassShape.squircle, pillStyle.copyWith(shadowDegrees: 90, seed: 3), Icons.east,
              '90° right'),
          piece(berry, 260, 64, SeaGlassShape.capsule, pillStyle.copyWith(shadowDegrees: 225, shadowTinted: true, seed: 4),
              Icons.south_west, '225° tinted'),
          piece(lilac, 260, 64, SeaGlassShape.capsule,
              pillStyle.copyWith(shadowColor: Colors.black.withValues(alpha: .4), seed: 5), Icons.opacity, 'alpha 0.4'),
          piece(lilac, 260, 64, SeaGlassShape.capsule,
              pillStyle.copyWith(shadowColor: Colors.transparent, transmission: 0, seed: 6), Icons.block, 'No shadow'),
        ]),
      ),
    );
  }
}

/// The same piece from a clean outline (tumble 0) to the most worn (0.065).
class TumbleLevels extends StatelessWidget {
  const TumbleLevels({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (tumble, label) in [(0.0, 'tumble: 0'), (.02, 'tumble: 0.02'), (.04, 'tumble: 0.04'), (.065, 'tumble: 0.065')])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: SeaGlassSurface(
                width: 260,
                height: 96,
                shape: SeaGlassShape.capsule,
                palette: lagoonPill,
                style: pillStyle.copyWith(tumble: tumble, seed: 7),
                child: Text(label, style: const TextStyle(fontSize: 22)),
              ),
            ),
        ]),
      ),
    );
  }
}
