import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sea_glass/sea_glass.dart';
import 'package:sea_glass/src/contour.dart';
import 'package:sea_glass/src/material_field.dart';
import 'package:sea_glass/src/random.dart';

void main() {
  // Generated from the original web reference (web/dist/sea-glass.mjs).
  final fixture = jsonDecode(File('test/fixtures/web_reference.json').readAsStringSync());

  test('seeded random matches the reference stream', () {
    (fixture['random'] as Map).forEach((seed, values) {
      final r = SeaGlassRandom(int.parse(seed));
      for (final v in values) {
        expect(r.nextDouble(), v, reason: 'seed $seed');
      }
    });
  });

  test('random sample/advance agree with nextDouble', () {
    final a = SeaGlassRandom(99), b = SeaGlassRandom(99);
    final peek = b.sample(4);
    for (var i = 0; i < 4; i++) {
      a.nextDouble();
    }
    expect(a.nextDouble(), peek);
    b.advance(5);
    expect(b.nextDouble(), a.nextDouble());
  });

  test('tumbled contour matches the reference outline', () {
    for (final c in fixture['contours']) {
      final shape = SeaGlassShape.values.byName(c['shape']);
      final points = buildContour((c['w'] as num).toDouble(), (c['h'] as num).toDouble(),
          shape: shape, tumble: (c['t'] as num).toDouble(), seed: c['seed']);
      final expected = c['points'] as List;
      expect(points.length, expected.length);
      for (var i = 0; i < points.length; i++) {
        expect(points[i].dx, closeTo((expected[i]['x'] as num).toDouble(), 1e-9), reason: '$shape #$i');
        expect(points[i].dy, closeTo((expected[i]['y'] as num).toDouble(), 1e-9), reason: '$shape #$i');
      }
    }
  });

  test('geometry field is a dome inside the coverage mask', () {
    const w = 40, h = 24;
    final coverage = Uint8List((w + 2) * (h + 2));
    for (var y = 3; y < h - 1; y++) {
      for (var x = 3; x < w - 1; x++) {
        coverage[y * (w + 2) + x] = 255;
      }
    }
    final t = buildGeometryTextures(GeometryRequest(
        widthDp: w.toDouble(), heightDp: h.toDouble(), scale: 1, seed: 42,
        width: w, height: h, coverage: coverage));
    double profileAt(int x, int y) => t.a[(y * w + x) * 4];
    expect(profileAt(20, 12), greaterThan(profileAt(4, 12)));
    for (var i = 0; i < t.a.length; i++) {
      expect(t.a[i], inInclusiveRange(0, 1));
      expect(t.b[i], inInclusiveRange(0, 1));
    }
    expect(t.gradientScaleA, greaterThan(0));
  });

  test('palette from Material 3 scheme', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);
    final p = SeaGlassPalette.fromColorScheme(scheme, SeaGlassColorRole.secondary);
    expect(p.body, scheme.secondaryContainer);
    expect(p.ink, scheme.onSecondaryContainer);
  });

  test('style clamps out-of-range values', () {
    final s = const SeaGlassStyle(frost: 4, tumble: 1, thickness: 99, elevation: -3).normalized();
    expect(s.frost, 1);
    expect(s.tumble, 0.065);
    expect(s.thickness, 14);
    expect(s.elevation, 0);
  });

  testWidgets('button taps, disables and themes', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SeaGlassTheme(
            palette: SeaGlassPalette.mint,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SeaGlassButton(onPressed: () => taps++, child: const Text('Compose')),
              const SeaGlassButton(onPressed: null, child: Text('Off')),
              const SeaGlassSurface(width: 80, height: 80, shape: SeaGlassShape.disc, child: Icon(Icons.add)),
            ]),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Compose'));
    await tester.pump();
    expect(taps, 1);
    await tester.tap(find.text('Off'), warnIfMissed: false);
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
