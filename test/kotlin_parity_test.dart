// Parity checks against the original Kotlin implementation (mttmcknn/sea-glass).
// The fixtures in test/fixtures/kotlin (revision in REVISION) come from
// tool/kotlin_reference, which compiles the original geometry sources
// unchanged and renders the original SeaGlassBodyShader through Skia.
// Regenerate them by rerunning the harness in tool/kotlin_reference.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sea_glass/sea_glass.dart';
import 'package:sea_glass/src/contour.dart';
import 'package:sea_glass/src/material_field.dart';
import 'package:sea_glass/src/painter.dart';

const fixtures = 'test/fixtures/kotlin';

class Case {
  Case(this.json) : id = json['id'];
  final Map<String, dynamic> json;
  final String id;

  double n(String key) => (json[key] as num).toDouble();
  int i(String key) => json[key] as int;
  SeaGlassShape get shape => SeaGlassShape.values.byName(json['shape']);
  SeaGlassStyle get style => SeaGlassStyle(
        frost: n('frost'), grain: n('grain'), tumble: n('tumble'), thickness: n('thickness'),
        bulge: n('bulge'), elevation: n('elevation'), lightDegrees: n('light'),
        transmission: n('transmission'), seed: i('seed'),
      );
  /// Geometry uses the unrounded double scale. Only the shader uniform is Float.
  double get fieldScale => math.min(1.0, math.sqrt(262144.0 / (n('width') * n('height'))));
  Uint8List bytes(String name) =>
      Uint8List.fromList(gzip.decode(File('$fixtures/$id/$name.gz').readAsBytesSync()));
  Float32List floats(String name) => bytes(name).buffer.asFloat32List();
  List<ContourSegment> get segments => contourSegments(
      buildContour(n('width'), n('height'), shape: shape, tumble: n('tumble'), seed: i('seed')));
}

final cases = [
  for (final c in jsonDecode(File('$fixtures/cases.json').readAsStringSync())) Case(c),
];

class Diff {
  double max = 0, sum = 0;
  int count = 0, over = 0;
  void add(num a, num b, [num tolerance = 0]) {
    final d = (a - b).abs().toDouble();
    max = math.max(max, d);
    sum += d;
    count++;
    if (d > tolerance) over++;
  }

  double get mean => count == 0 ? 0 : sum / count;
  @override
  String toString() => 'max=${max.toStringAsExponential(3)} mean=${mean.toStringAsExponential(3)} over=$over/$count';
}

Future<Uint8List> renderBody(Case c, ui.Image a, ui.Image b, double gradA, double gradB, ui.FragmentProgram program,
    {Offset offset = Offset.zero, SeaGlassStyle? style}) async {
  final shader = program.fragmentShader();
  configureBodyShader(
    shader, a, b,
    widthDp: c.n('width'), heightDp: c.n('height'), fieldScale: f32(c.n('fieldScale')),
    gradientScaleA: gradA, gradientScaleB: gradB,
    textureWidth: c.i('textureWidth'), textureHeight: c.i('textureHeight'),
    style: (style ?? c.style).normalized(), seed: c.i('seed'),
    body: Color(0xFF000000 | c.i('body')), edge: Color(0xFF000000 | c.i('edge')),
  );
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..translate(offset.dx, offset.dy)
    ..drawPath(contourToPath(c.segments), Paint()
      ..isAntiAlias = true
      ..shader = shader);
  final picture = recorder.endRecording();
  final image = await picture.toImage(c.i('pixelWidth') + offset.dx.toInt(), c.i('pixelHeight') + offset.dy.toInt());
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return data.buffer.asUint8List();
}

/// Compares two premultiplied RGBA renders: fully covered pixels and all pixels.
(Diff, Diff) compareRgba(Uint8List actual, Uint8List expected) {
  final interior = Diff(), all = Diff();
  for (var p = 0; p < expected.length; p += 4) {
    for (var ch = 0; ch < 4; ch++) {
      all.add(actual[p + ch], expected[p + ch]);
      if (expected[p + 3] == 255 && actual[p + 3] == 255) interior.add(actual[p + ch], expected[p + ch]);
    }
  }
  return (interior, all);
}

void main() {
  for (final c in cases) {
    group(c.id, () {
      test('contour segments match the Kotlin geometry inputs', () {
        // Segment counts and texture sizes come from the same contour and budget code.
        final fieldScale = c.fieldScale;
        expect(f32(fieldScale), f32(c.n('fieldScale')));
        expect(math.max(1, (c.n('width') * fieldScale).ceil()), c.i('textureWidth'));
        expect(math.max(1, (c.n('height') * fieldScale).ceil()), c.i('textureHeight'));
      });

      test('geometry textures from the Kotlin mask are bit-identical', () {
        final w = c.i('textureWidth'), h = c.i('textureHeight');
        final t = buildGeometryTextures(GeometryRequest(
          widthDp: c.n('width'), heightDp: c.n('height'), scale: c.fieldScale,
          seed: c.i('seed'), width: w, height: h, coverage: c.bytes('mask.u8'),
        ));
        expect(t.gradientScaleA, f32(c.n('gradientScaleA')));
        expect(t.gradientScaleB, f32(c.n('gradientScaleB')));
        final ka = c.floats('a.f32'), kb = c.floats('b.f32');
        final da = Diff(), db = Diff();
        for (var i = 0; i < ka.length; i++) {
          da.add(t.a[i], ka[i]);
          db.add(t.b[i], kb[i]);
        }
        printOnFailure('A $da\nB $db');
        // ignore: avoid_print
        print('${c.id} textures: A $da | B $db');
        expect(da.over, 0, reason: 'A $da');
        expect(db.over, 0, reason: 'B $db');
      });

      testWidgets('Flutter mask rasterization is identical to Kotlin/Skia', (tester) async {
        final w = c.i('textureWidth') + 2, h = c.i('textureHeight') + 2;
        final mask = (await tester.runAsync(() => rasterizeMask(c.segments, w, h, c.fieldScale)))!;
        final expected = c.bytes('mask.u8');
        final d = Diff();
        for (var i = 0; i < expected.length; i++) {
          d.add(mask[i], expected[i]);
        }
        // ignore: avoid_print
        print('${c.id} mask: $d');
        expect(d.over, 0, reason: '$d');
      });

      testWidgets('body shader with Kotlin textures is pixel-identical to the Kotlin render', (tester) async {
        final program = await tester.runAsync(SeaGlassShaderProgram.load);
        expect(program, isNotNull, reason: 'shader must load in flutter test');
        final w = c.i('textureWidth'), h = c.i('textureHeight');
        final pixels = (await tester.runAsync(() async {
          final a = await uploadFloatTexture(c.floats('a.f32'), w, h);
          final b = await uploadFloatTexture(c.floats('b.f32'), w, h);
          return renderBody(c, a, b, f32(c.n('gradientScaleA')), f32(c.n('gradientScaleB')), program!);
        }))!;
        final (interior, all) = compareRgba(pixels, c.bytes('body.rgba'));
        // ignore: avoid_print
        print('${c.id} body (Kotlin textures): interior $interior | all $all');
        expect(all.over, 0, reason: 'all $all');
      });

      testWidgets('shading uses local coordinates (drawn at an offset)', (tester) async {
        // Fragment coordinates must follow the canvas transform, matching the
        // original's local shader coordinates.
        const offset = Offset(23, 11);
        final program = await tester.runAsync(SeaGlassShaderProgram.load);
        final w = c.i('textureWidth'), h = c.i('textureHeight');
        final pixels = (await tester.runAsync(() async {
          final a = await uploadFloatTexture(c.floats('a.f32'), w, h);
          final b = await uploadFloatTexture(c.floats('b.f32'), w, h);
          return renderBody(c, a, b, f32(c.n('gradientScaleA')), f32(c.n('gradientScaleB')), program!, offset: offset);
        }))!;
        final pw = c.i('pixelWidth'), ph = c.i('pixelHeight'), stride = pw + offset.dx.toInt();
        final expected = c.bytes('body.rgba');
        final d = Diff();
        for (var y = 0; y < ph; y++) {
          for (var x = 0; x < pw; x++) {
            final i = (y * pw + x) * 4, j = ((y + offset.dy.toInt()) * stride + x + offset.dx.toInt()) * 4;
            // Interior only: moving a path can shift edge antialiasing a little.
            if (expected[i + 3] != 255 || pixels[j + 3] != 255) continue;
            for (var ch = 0; ch < 4; ch++) {
              d.add(pixels[j + ch], expected[i + ch]);
            }
          }
        }
        expect(d.over, 0, reason: '$d');
      });

      testWidgets('ground light matches the Kotlin/Skia ground', (tester) async {
        final w = c.n('width'), h = c.n('height');
        final pw = (w + kSeaGlassPadding * 2).ceil(), ph = (h + kSeaGlassPadding * 2).ceil();
        final pixels = (await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)..translate(kSeaGlassPadding, kSeaGlassPadding);
          paintGround(canvas, contourToPath(c.segments), Size(w, h), c.style.normalized(),
              SeaGlassPalette(body: Color(0xFF000000 | c.i('body')), edge: Color(0xFF000000 | c.i('edge')), ink: const Color(0xFF000000)));
          final image = await recorder.endRecording().toImage(pw, ph);
          return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
        }))!;
        // Without blur the alpha matches, but premultiplied colour still differs
        // by a few levels: the two Skia builds round translucent blending
        // differently. Allow 3/255 per channel; everything else must be exact.
        final ground = Diff();
        final expected = c.bytes('ground.rgba');
        for (var i = 0; i < expected.length; i++) {
          ground.add(pixels[i], expected[i], 3);
        }
        // ignore: avoid_print
        print('${c.id} ground: $ground');
        expect(ground.over, 0, reason: '$ground');
        expect(ground.mean, lessThan(1.0));
      });

      testWidgets('full Dart pipeline is pixel-identical to the Kotlin render', (tester) async {
        final program = await tester.runAsync(SeaGlassShaderProgram.load);
        final w = c.i('textureWidth'), h = c.i('textureHeight');
        final pixels = (await tester.runAsync(() async {
          final mask = await rasterizeMask(c.segments, w + 2, h + 2, c.fieldScale);
          final t = buildGeometryTextures(GeometryRequest(
            widthDp: c.n('width'), heightDp: c.n('height'), scale: c.fieldScale,
            seed: c.i('seed'), width: w, height: h, coverage: mask,
          ));
          final a = await uploadFloatTexture(t.a, w, h);
          final b = await uploadFloatTexture(t.b, w, h);
          return renderBody(c, a, b, t.gradientScaleA, t.gradientScaleB, program!);
        }))!;
        final (interior, all) = compareRgba(pixels, c.bytes('body.rgba'));
        // ignore: avoid_print
        print('${c.id} body (full Dart): interior $interior | all $all');
        expect(all.over, 0, reason: 'all $all');
      });
    });
  }

  group('shadow direction and tint (extension)', () {
    // The Kotlin exporter applies the same extension to the original
    // RealtimeGround code path (renderGroundExtended), so compare against that.
    const variants = [(90.0, false), (135.0, false), (0.0, false), (270.0, false), (180.0, true), (135.0, true)];
    for (final c in cases.where((c) => c.id == 'lagoon-rounded' || c.id == 'mint-disc')) {
      for (final (degrees, tinted) in variants) {
        final name = 'ground-${degrees.toInt()}${tinted ? '-tinted' : ''}.rgba';
        testWidgets('${c.id} $name matches the Kotlin/Skia reference', (tester) async {
          final w = c.n('width'), h = c.n('height');
          final pw = (w + kSeaGlassPadding * 2).ceil(), ph = (h + kSeaGlassPadding * 2).ceil();
          final pixels = (await tester.runAsync(() async {
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder)..translate(kSeaGlassPadding, kSeaGlassPadding);
            paintGround(canvas, contourToPath(c.segments), Size(w, h),
                c.style.copyWith(shadowDegrees: degrees, shadowTinted: tinted).normalized(),
                SeaGlassPalette(body: Color(0xFF000000 | c.i('body')), edge: Color(0xFF000000 | c.i('edge')), ink: const Color(0xFF000000)));
            final image = await recorder.endRecording().toImage(pw, ph);
            return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
          }))!;
          final expected = c.bytes(name);
          final d = Diff();
          for (var i = 0; i < expected.length; i++) {
            d.add(pixels[i], expected[i], 3);
          }
          // ignore: avoid_print
          print('${c.id} $name: $d');
          expect(d.over, 0, reason: '$d');
          expect(d.mean, lessThan(1.0));
        });
      }
    }

    testWidgets('the glass body is identical to the original for any shadow setting', (tester) async {
      final c = cases.firstWhere((c) => c.id == 'lagoon-rounded');
      final program = await tester.runAsync(SeaGlassShaderProgram.load);
      final w = c.i('textureWidth'), h = c.i('textureHeight');
      for (final (degrees, tinted) in variants) {
        final pixels = (await tester.runAsync(() async {
          final a = await uploadFloatTexture(c.floats('a.f32'), w, h);
          final b = await uploadFloatTexture(c.floats('b.f32'), w, h);
          return renderBody(c, a, b, f32(c.n('gradientScaleA')), f32(c.n('gradientScaleB')), program!,
              style: c.style.copyWith(shadowDegrees: degrees, shadowTinted: tinted));
        }))!;
        expect(listEquals(pixels, c.bytes('body.rgba')), isTrue, reason: '$degrees° tinted=$tinted');
      }
    });
  });
}
