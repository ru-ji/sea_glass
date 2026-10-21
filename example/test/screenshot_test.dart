// Renders each example page with the real shader and saves PNG screenshots
// to doc/screenshots. Run: flutter test test/screenshot_test.dart
// Fonts come from the Flutter SDK cache (Roboto and Material Icons).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sea_glass/sea_glass.dart';
import 'package:sea_glass_example/pages/everyday_pages.dart';

import 'fonts.dart';

final _theme = ThemeData(fontFamily: 'Google Sans');

void main() {
  setUpAll(loadFonts);

  final pages = <(String, Widget)>[
    ('music', MaterialApp(debugShowCheckedModeBanner: false, theme: _theme, home: const MusicPage())),
    ('post', MaterialApp(debugShowCheckedModeBanner: false, theme: _theme, home: const PostPage())),
    ('nori', MaterialApp(debugShowCheckedModeBanner: false, theme: _theme, home: const NoriPage())),
    ('tumble_levels', MaterialApp(debugShowCheckedModeBanner: false, theme: _theme, home: const TumbleLevels())),
    ('shadow_directions', MaterialApp(debugShowCheckedModeBanner: false, theme: _theme, home: const ShadowDirections())),
  ];
  for (final (name, app) in pages) {
    testWidgets('screenshot $name', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      // Phone insets, so the everyday screens sit below a real status bar.
      if (['music', 'post', 'nori'].contains(name)) {
        tester.view.padding = const FakeViewPadding(top: 40 * 2.625, bottom: 24 * 2.625);
      }
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
        final image = await render.toImage(pixelRatio: 2.625);
        return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      });
      Directory('../doc/screenshots').createSync(recursive: true);
      File('../doc/screenshots/$name.png').writeAsBytesSync(bytes!);
      expect(tester.takeException(), isNull);
    });
  }
}

/// A label in the screens' serif, small and muted.
Text _label(String text) => Text(text, style: serif(17, color: const Color(0xFF8A908C)));

/// Quiet glass pieces with the ground light in a few directions, tints and alphas.
class ShadowDirections extends StatelessWidget {
  const ShadowDirections({super.key});

  @override
  Widget build(BuildContext context) {
    // Taller and stronger than the screens' glass, so each direction is easy to see.
    final style = quietGlass.copyWith(elevation: 18, thickness: 8, transmission: .5);
    Widget piece(SeaGlassPalette p, SeaGlassShape shape, double w, SeaGlassStyle s, IconData icon, String label) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 150, child: _label(label)),
            SeaGlassSurface(
              width: w, height: 60, shape: shape, palette: p, style: s,
              child: Icon(icon, size: 24),
            ),
            SizedBox(width: 170 - w),
          ]),
        );
    return Material(
      color: paper,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          piece(sky, SeaGlassShape.capsule, 170, style.copyWith(seed: 1), Icons.south, '180° down'),
          piece(mint, SeaGlassShape.capsule, 170, style.copyWith(shadowDegrees: 135, shadowTinted: true, seed: 2),
              Icons.south_east, '135° tinted'),
          piece(peach, SeaGlassShape.squircle, 60, style.copyWith(shadowDegrees: 90, seed: 3), Icons.east, '90° right'),
          piece(lilac, SeaGlassShape.capsule, 170, style.copyWith(shadowDegrees: 225, shadowTinted: true, seed: 4),
              Icons.south_west, '225° tinted'),
          piece(sky, SeaGlassShape.capsule, 170,
              style.copyWith(shadowColor: Colors.black.withValues(alpha: .4), seed: 5), Icons.opacity, 'alpha 0.4'),
          piece(mint, SeaGlassShape.capsule, 170,
              style.copyWith(shadowColor: Colors.transparent, transmission: 0, seed: 6), Icons.block, 'No shadow'),
        ]),
      ),
    );
  }
}

/// The same quiet pieces, clean (tumble 0) and fully worn (0.065).
class TumbleLevels extends StatelessWidget {
  const TumbleLevels({super.key});

  @override
  Widget build(BuildContext context) {
    Widget set(double tumble) {
      final style = quietGlass.copyWith(tumble: tumble, frost: .7);
      return Column(mainAxisSize: MainAxisSize.min, children: [
        _label(tumble == 0 ? 'tumble: 0' : 'tumble: $tumble'),
        const SizedBox(height: 30),
        SeaGlassSurface(
          width: 230,
          height: 64,
          shape: SeaGlassShape.capsule,
          palette: sky,
          style: style.copyWith(seed: 33),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.edit_outlined, size: 20), SizedBox(width: 10), Text('Compose', style: TextStyle(fontSize: 17)),
          ]),
        ),
        const SizedBox(height: 32),
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (i, p) in [mint, lilac, peach].indexed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SeaGlassSurface(
                width: 64,
                height: 64,
                shape: SeaGlassShape.disc,
                palette: p,
                style: style.copyWith(seed: 12 + i),
                child: Icon([Icons.play_arrow, Icons.favorite_border, Icons.auto_awesome][i], size: 22),
              ),
            ),
        ]),
      ]);
    }

    return Material(
      color: paper,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [set(0), const SizedBox(height: 90), set(.065)]),
      ),
    );
  }
}
