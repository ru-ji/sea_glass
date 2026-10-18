// Real-async rendering tests, kept apart from sea_glass_test.dart: widget
// tests there start the shader load inside the fake-async zone, where it
// never completes.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sea_glass/sea_glass.dart';
import 'package:sea_glass/src/painter.dart';

void main() {
  testWidgets('precached piece is complete on its first frame', (tester) async {
    const size = Size(200, 64);
    const style = SeaGlassStyle(seed: 9);
    await tester.runAsync(() => SeaGlass.precache(size, style: style));
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: SeaGlass(width: 200, height: 64, style: style)),
    ));
    final paint = tester.widget<CustomPaint>(
        find.descendant(of: find.byType(SeaGlass), matching: find.byType(CustomPaint)));
    final painter = paint.painter! as SeaGlassPainter;
    expect(painter.program, isNotNull);
    expect(painter.controller.displayedFor(size), isNotNull);
  });

  Future<void> settle(SeaGlassGeometryController c, WidgetTester tester) => tester.runAsync(() async {
        final done = Completer<void>();
        void listener() {
          if (!done.isCompleted) done.complete();
        }
        c.addListener(listener);
        await done.future.timeout(const Duration(seconds: 20));
        c.removeListener(listener);
      });

  testWidgets('A -> B(active) -> A keeps A displayed', (tester) async {
    final c = SeaGlassGeometryController();
    const style = SeaGlassStyle(seed: 101);
    const a = Size(150, 50), b = Size(151, 50);
    // Requests run in the real zone so their builds can complete.
    await tester.runAsync(() async => c.request(a, SeaGlassShape.capsule, style));
    await settle(c, tester);
    expect(c.displayedFor(a), isNotNull);
    await tester.runAsync(() async {
      c.request(b, SeaGlassShape.capsule, style); // B starts building
      c.request(a, SeaGlassShape.capsule, style); // back to A before B finishes
    });
    await settle(c, tester);
    expect(c.displayedFor(a), isNotNull, reason: 'the latest request (A) must stay displayed');
    c.dispose();
  });

  testWidgets('a resized piece keeps drawing the previous geometry', (tester) async {
    const style = SeaGlassStyle(seed: 77);
    await tester.runAsync(() => SeaGlass.precache(const Size(120, 48), style: style));
    Widget piece(double w) => Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: SeaGlass(width: w, height: 48, style: style)),
        );
    await tester.pumpWidget(piece(120));
    final painter = tester.widget<CustomPaint>(
        find.descendant(of: find.byType(SeaGlass), matching: find.byType(CustomPaint))).painter! as SeaGlassPainter;
    await tester.pumpWidget(piece(140)); // new size, not built yet
    expect(painter.controller.displayedFor(const Size(140, 48)), isNull);
    expect(painter.controller.displayed, isNotNull, reason: 'stretched while the new size builds');
    expect(tester.takeException(), isNull);
  });

  testWidgets('ground light is rasterized once and reused', (tester) async {
    final c = SeaGlassGeometryController();
    final path = Path()..addRRect(RRect.fromLTRBR(0, 0, 100, 40, const Radius.circular(20)));
    const s = SeaGlassStyle();
    final first = c.groundFor(path, const Size(100, 40), s, SeaGlassPalette.mint, 2);
    expect(identical(c.groundFor(path, const Size(100, 40), s, SeaGlassPalette.mint, 2), first), isTrue);
    expect(first.width, (100 + kSeaGlassPadding * 2) * 2);
    final recolored = c.groundFor(path, const Size(100, 40), s, SeaGlassPalette.rose, 2);
    expect(identical(recolored, first), isFalse);
    c.dispose();
  });
}
