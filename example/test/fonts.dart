import 'dart:io';

import 'package:flutter/services.dart';

/// Loads real fonts for the rendering tests: Roboto and Material Icons from
/// the Flutter SDK cache, plus a system monospace font when one is present.
Future<void> loadFonts() async {
  final root = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final fonts = '$root/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }

  await load('Roboto', [for (final w in ['Regular', 'Medium', 'Bold', 'Light']) '$fonts/Roboto-$w.ttf']);
  await load('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
  await load('monospace', [
    '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
    '/System/Library/Fonts/SFNSMono.ttf', // macOS
  ]);
}
