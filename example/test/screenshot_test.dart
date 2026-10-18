// Renders each example page with the real shader and saves PNG screenshots to
// doc/screenshots. Run: flutter test test/screenshot_test.dart
// Fonts come from the Flutter SDK cache (Roboto and Material Icons).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sea_glass_example/main.dart';

Future<void> loadFonts() async {
  final root = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final fonts = Directory('$root/bin/cache/artifacts/material_fonts');
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final file = File('${fonts.path}/$f');
      if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }

  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Light.ttf']);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

void main() {
  setUpAll(loadFonts);

  for (final (index, name) in [(0, 'quick_settings'), (1, 'pill'), (2, 'playground')]) {
    testWidgets('screenshot $name', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: boundary, child: SeaGlassExampleApp(initialPage: index)));
      // Let shader loading and geometry builds finish (they run in the real zone).
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
