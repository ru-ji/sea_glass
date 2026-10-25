// Run on a device: flutter test integration_test/perf_test.dart -d <device>
// ignore_for_file: avoid_print, implementation_imports
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sea_glass/sea_glass.dart';
import 'package:sea_glass/src/painter.dart';

/// Longest gap between UI event-loop turns while [work] runs, i.e. the worst
/// UI-thread stall it causes.
Future<(Duration total, Duration stall)> measure(Future<void> Function() work) async {
  var worst = Duration.zero;
  var last = DateTime.now();
  var running = true;
  void tick() {
    final now = DateTime.now();
    if (now.difference(last) > worst) worst = now.difference(last);
    last = now;
    if (running) Timer(Duration.zero, tick);
  }

  final sw = Stopwatch()..start();
  tick();
  await work();
  sw.stop();
  running = false;
  return (sw.elapsed, worst);
}

String ms(Duration d) => (d.inMicroseconds / 1000).toStringAsFixed(1);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('geometry build: total time and worst UI stall', (tester) async {
    for (final size in const [Size(200, 56), Size(400, 400), Size(800, 600)]) {
      final totals = <Duration>[], stalls = <Duration>[];
      for (var run = 0; run < 6; run++) {
        SeaGlassGeometryCache.clear();
        final key = SeaGlassGeometryController.keyFor(size, SeaGlassShape.rounded, SeaGlassStyle.reference.normalized());
        final (total, stall) = await measure(() async => (await SeaGlassGeometryCache.obtain(key))?.dispose());
        if (run > 0) {
          totals.add(total);
          stalls.add(stall);
        } // run 0 is warm-up
      }
      totals.sort();
      stalls.sort();
      print('PERF build ${size.width.toInt()}x${size.height.toInt()}: '
          'median ${ms(totals[2])} ms, worst UI stall median ${ms(stalls[2])} ms (max ${ms(stalls.last)} ms)');
    }
  });

  testWidgets('outline during a 60-frame resize', (tester) async {
    final controller = SeaGlassGeometryController();
    final style = SeaGlassStyle.reference.normalized();
    const start = Size(300, 120);
    final done = Completer<void>();
    controller.addListener(() {
      if (!done.isCompleted) done.complete();
    });
    controller.request(start, SeaGlassShape.rounded, style);
    if (controller.displayedFor(start) == null) await done.future;
    final sw = Stopwatch()..start();
    for (var i = 1; i <= 60; i++) {
      controller.pathFor(Size(300 + i * 2, 120 + i.toDouble()), SeaGlassShape.rounded, style);
    }
    sw.stop();
    print('PERF resize pathFor x60: total ${ms(sw.elapsed)} ms, per frame ${(sw.elapsed.inMicroseconds / 60000).toStringAsFixed(2)} ms');
    controller.dispose();
  });
}
