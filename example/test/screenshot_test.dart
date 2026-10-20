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

import 'fonts.dart';

void main() {
  setUpAll(loadFonts);

  final pages = <(String, Widget)>[
    ('quick_settings', const SeaGlassExampleApp(initialPage: 0)),
    ('pill', const SeaGlassExampleApp(initialPage: 1)),
    ('playground', const SeaGlassExampleApp(initialPage: 2)),
    ('shadow_directions', const MaterialApp(debugShowCheckedModeBanner: false, home: ShadowDirections())),
  ];
  for (final (name, app) in pages) {
    testWidgets('screenshot $name', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
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

/// The same pill with the ground light in a few directions and tints.
class ShadowDirections extends StatelessWidget {
  const ShadowDirections({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (degrees, tinted, label) in [(180.0, false, '180° down'), (180.0, true, '180° tinted'),
              (135.0, false, '135° down-right'), (90.0, false, '90° right'), (135.0, true, '135° tinted')])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 34),
              child: SeaGlassSurface(
                width: 280,
                height: 64,
                shape: SeaGlassShape.capsule,
                palette: lagoonPill,
                style: pillStyle.copyWith(shadowDegrees: degrees, shadowTinted: tinted, seed: degrees.toInt()),
                child: Text(label, style: const TextStyle(fontSize: 20)),
              ),
            ),
        ]),
      ),
    );
  }
}
