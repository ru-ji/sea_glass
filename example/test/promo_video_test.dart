// Renders the promo loop frame by frame with the real shader.
// Opt-in, because it writes 240 frames: use tool/render_promo.sh, or
//   flutter test test/promo_video_test.dart --dart-define=RENDER_PROMO=true
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sea_glass_example/promo/promo_scene.dart';

import 'fonts.dart';

const render = bool.fromEnvironment('RENDER_PROMO');
const fps = 30;
const pixelRatio = 2.0; // 360 x 640 logical -> 720 x 1280

void main() {
  setUpAll(loadFonts);

  testWidgets('render promo frames', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(tester.view.reset);
    final out = Directory('build/promo_frames')..createSync(recursive: true);
    for (final f in out.listSync()) {
      f.deleteSync();
    }
    final boundary = GlobalKey();
    Future<void> show(double t) => tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(key: boundary, child: PromoScene(t: t)),
        ));
    // Let geometry builds (real zone) finish so each frame is complete.
    Future<void> settle([int rounds = 2]) async {
      for (var i = 0; i < rounds; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump();
      }
    }

    final frames = promoDuration.inMilliseconds * fps ~/ 1000;
    // Warm-up pass: load the shader and build every geometry once.
    for (var i = 0; i < frames; i += 6) {
      await show(i / fps);
      await settle(i == 0 ? 20 : 2);
    }
    for (var i = 0; i < frames; i++) {
      await show(i / fps);
      await settle();
      final png = await tester.runAsync(() async {
        final boundaryObject = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundaryObject.toImage(pixelRatio: pixelRatio);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      File('${out.path}/frame_${i.toString().padLeft(4, '0')}.png').writeAsBytesSync(png!);
    }
    expect(tester.takeException(), isNull);
  }, skip: !render, timeout: const Timeout(Duration(minutes: 20)));
}
