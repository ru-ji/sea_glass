import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'contour.dart';
import 'material_field.dart';
import 'random.dart';
import 'style.dart';

/// Transparent gutter the material may draw into outside its layout box.
const double kSeaGlassPadding = 48.0;

/// Loads the fragment program once. Resolves to null if shaders are unavailable
/// (unsupported backend, unit tests); painters then draw only the ground light.
class SeaGlassShaderProgram {
  SeaGlassShaderProgram._();

  static const String asset = 'packages/sea_glass/shaders/sea_glass.frag';
  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram?>? _loading;

  static ui.FragmentProgram? get loaded => _program;

  static Future<ui.FragmentProgram?> load() => _loading ??= () async {
        try {
          return _program = await ui.FragmentProgram.fromAsset(asset);
        } catch (e) {
          debugPrint('sea_glass: shader unavailable ($e)');
          return null;
        }
      }();
}

@immutable
class GeometryKey {
  const GeometryKey(this.widthDp, this.heightDp, this.shape, this.tumble, this.seed, this.fieldScale);
  final double widthDp, heightDp, tumble, fieldScale;
  final SeaGlassShape shape;
  final int seed;

  bool sameSize(Size s) => widthDp == s.width && heightDp == s.height;

  @override
  bool operator ==(Object other) =>
      other is GeometryKey && other.widthDp == widthDp && other.heightDp == heightDp && other.shape == shape &&
      other.tumble == tumble && other.seed == seed && other.fieldScale == fieldScale;

  @override
  int get hashCode => Object.hash(widthDp, heightDp, shape, tumble, seed, fieldScale);
}

class LiveGeometry {
  LiveGeometry(this.key, this.path, this.a, this.b, this.width, this.height, this.gradientScaleA, this.gradientScaleB);
  final GeometryKey key;
  final Path path;
  final ui.Image a, b;
  final int width, height;
  final double gradientScaleA, gradientScaleB;

  void dispose() {
    a.dispose();
    b.dispose();
  }
}

/// Owns one piece's geometry (port of LiveMaterialRenderer's update model):
/// the last complete geometry stays visible while edits are prepared off the
/// paint path; one build is active and only the newest request is kept pending.
class SeaGlassGeometryController extends ChangeNotifier {
  LiveGeometry? _displayed;
  GeometryKey? _active, _pending;
  bool _disposed = false;
  final Map<GeometryKey, Path> _paths = {};

  static GeometryKey keyFor(Size size, SeaGlassShape shape, SeaGlassStyle style) {
    final fieldScale = math.min(1.0, math.sqrt(262144.0 / (size.width * size.height)));
    return GeometryKey(size.width, size.height, shape, style.tumble, style.seed, fieldScale);
  }

  /// Outline for clipping and ground light: the displayed geometry's when it
  /// matches the size, otherwise the requested outline (computed synchronously).
  Path pathFor(Size size, SeaGlassShape shape, SeaGlassStyle style) {
    final d = _displayed;
    if (d != null && d.key.sameSize(size)) return d.path;
    final key = keyFor(size, shape, style);
    if (_paths.length > 4) _paths.clear();
    return _paths[key] ??= _outline(key);
  }

  static Path _outline(GeometryKey k) => contourToPath(
      contourSegments(buildContour(k.widthDp, k.heightDp, shape: k.shape, tumble: k.tumble, seed: k.seed)));

  LiveGeometry? displayedFor(Size size) {
    final d = _displayed;
    return d != null && d.key.sameSize(size) ? d : null;
  }

  void request(Size size, SeaGlassShape shape, SeaGlassStyle style) {
    if (size.width < 1 || size.height < 1) return;
    final key = keyFor(size, shape, style);
    if (_displayed?.key == key || _active == key) {
      _pending = null;
      return;
    }
    if (_active != null) {
      _pending = key;
      return;
    }
    _start(key);
  }

  void _start(GeometryKey key) {
    _active = key;
    _build(key).then((g) {
      if (_disposed) {
        g?.dispose();
        return;
      }
      if (g != null) {
        _displayed?.dispose();
        _displayed = g;
      }
      _active = null;
      final next = _pending;
      _pending = null;
      if (next != null && next != _displayed?.key) _start(next);
      notifyListeners();
    });
  }

  static Future<LiveGeometry?> _build(GeometryKey k) async {
    try {
      final segments = contourSegments(
          buildContour(k.widthDp, k.heightDp, shape: k.shape, tumble: k.tumble, seed: k.seed));
      final width = math.max(1, (k.widthDp * k.fieldScale).ceil());
      final height = math.max(1, (k.heightDp * k.fieldScale).ceil());
      final columns = width + 2, rows = height + 2;
      // Mask rasterizer: source-over white, scaled path, offset by one pixel.
      final recorder = ui.PictureRecorder();
      Canvas(recorder)
        ..translate(1, 1)
        ..drawPath(contourToPath(segments, k.fieldScale), Paint()
          ..color = const Color(0xFFFFFFFF)
          ..isAntiAlias = true);
      final picture = recorder.endRecording();
      final maskImage = await picture.toImage(columns, rows);
      picture.dispose();
      final rgba = (await maskImage.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      maskImage.dispose();
      final coverage = Uint8List(columns * rows);
      for (var i = 0; i < coverage.length; i++) {
        coverage[i] = rgba.getUint8(i * 4 + 3);
      }
      final textures = await compute(
        buildGeometryTextures,
        GeometryRequest(
          widthDp: k.widthDp, heightDp: k.heightDp, scale: k.fieldScale,
          seed: k.seed, width: width, height: height, coverage: coverage,
        ),
      );
      final a = await _upload(textures.a, width, height);
      final b = await _upload(textures.b, width, height);
      return LiveGeometry(k, contourToPath(segments), a, b, width, height,
          textures.gradientScaleA, textures.gradientScaleB);
    } catch (e, s) {
      debugPrint('sea_glass: geometry build failed: $e\n$s');
      return null;
    }
  }

  /// Opaque float RGBA keeps the encoded fields out of color conversion.
  static Future<ui.Image> _upload(Float32List data, int width, int height) {
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        width, height, ui.PixelFormat.rgbaFloat32, done.complete);
    return done.future;
  }

  @override
  void dispose() {
    _disposed = true;
    _displayed?.dispose();
    _displayed = null;
    super.dispose();
  }
}

/// Paints the three ground-light layers and the glass body.
class SeaGlassPainter extends CustomPainter {
  SeaGlassPainter({
    required this.style,
    required this.palette,
    required this.shape,
    required this.controller,
    this.program,
  }) : super(repaint: controller);

  final SeaGlassStyle style;
  final SeaGlassPalette palette;
  final SeaGlassShape shape;
  final SeaGlassGeometryController controller;
  final ui.FragmentProgram? program;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 1 || size.height < 1) return;
    final s = style.normalized();
    controller.request(size, shape, s);
    final geometry = controller.displayedFor(size);
    // Like the reference, a displayed geometry keeps its own seed and tumble.
    final path = geometry?.path ?? controller.pathFor(size, shape, s);
    canvas.save();
    _paintGround(canvas, path, size, s);
    if (geometry != null && program != null) _paintBody(canvas, size, s, geometry, program!);
    canvas.restore();
  }

  /// Port of RealtimeGround: each layer is drawn, then blurred as a whole.
  void _paintGround(Canvas canvas, Path path, Size size, SeaGlassStyle s) {
    final short = math.min(size.width, size.height);
    final t = s.transmission;
    final bounds = Rect.fromLTWH(-kSeaGlassPadding, -kSeaGlassPadding,
        size.width + kSeaGlassPadding * 2, size.height + kSeaGlassPadding * 2);

    void layer(double offset, double sigma, Paint paint) {
      canvas.saveLayer(
        bounds,
        Paint()..imageFilter = sigma > 0
            ? ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal)
            : null,
      );
      canvas.translate(0, offset);
      canvas.drawPath(path, paint..isAntiAlias = true);
      canvas.restore();
    }

    layer(
      math.min(16.0, s.thickness * 0.40 + s.elevation * 0.72 + s.bulge * short * 0.03),
      math.min(6.0, 2.5 + s.elevation * 0.18 + s.frost * 0.7 + s.bulge * short * 0.018),
      Paint()..color = Color(0xFF3F4342).withValues(alpha: f32((0.18 + s.elevation * 0.001) * (1.0 - t * 0.82))),
    );
    layer(
      math.min(8.0, s.thickness * 0.32 + 0.8),
      1.4 + s.elevation * 0.065,
      Paint()..color = Color(0xFF3D413F).withValues(alpha: f32(0.10 * (1.0 - t * 0.70))),
    );
    if (t > 0.001) {
      final travel = 4.0 + s.elevation * 0.56 + short * 0.055;
      final body = palette.body.toARGB32();
      int tint(int channel) => (255.0 - (255 - channel) * 1.35).round().clamp(0, 255);
      final tintColor = Color.fromARGB(
          255, tint((body >> 16) & 255), tint((body >> 8) & 255), tint(body & 255));
      layer(
        math.min(22.0, s.thickness * 0.42 + travel),
        math.min(8.0, 2.8 + short * 0.033 + s.frost * 1.6),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0, size.height),
            [
              tintColor.withValues(alpha: 0),
              tintColor.withValues(alpha: f32(t * 0.06)),
              tintColor.withValues(alpha: f32(t * 0.48)),
              tintColor.withValues(alpha: f32(t * 0.94)),
            ],
            const [0.0, 0.45, 0.75, 1.0],
          ),
      );
    }
  }

  void _paintBody(Canvas canvas, Size size, SeaGlassStyle s, LiveGeometry g, ui.FragmentProgram p) {
    final theta = s.lightDegrees * math.pi / 180.0;
    final lx = math.sin(theta);
    final ly = -math.cos(theta);
    const lightZ = 0.52;
    final lightSide = math.sqrt(1.0 - lightZ * lightZ);
    final halfX = lx * lightSide, halfY = ly * lightSide, halfZ = lightZ + 1.0;
    final halfLength = math.sqrt(halfX * halfX + halfY * halfY + halfZ * halfZ);
    final shader = p.fragmentShader()
      ..setImageSampler(0, g.a, filterQuality: FilterQuality.low)
      ..setImageSampler(1, g.b, filterQuality: FilterQuality.low);
    var i = 0;
    void f(double v) => shader.setFloat(i++, v);
    f(g.key.widthDp); f(g.key.heightDp); // materialSize
    f(g.key.fieldScale); // fieldScale
    f(1.0); // density: Flutter fragment coordinates are already logical pixels
    f(g.gradientScaleA); f(g.gradientScaleB); // gradientScales
    f(g.width.toDouble()); f(g.height.toDouble()); // geometrySize
    f(s.frost); f(s.grain); f(s.thickness); f(s.bulge); // recipeA
    f(s.lightDegrees); f(s.transmission); f(SeaGlassRandom(g.key.seed).nextDouble()); f(0); // recipeB
    final body = palette.body.toARGB32(), edge = palette.edge.toARGB32();
    f(((body >> 16) & 255) / 255); f(((body >> 8) & 255) / 255); f((body & 255) / 255); // bodyColor
    f(((edge >> 16) & 255) / 255); f(((edge >> 8) & 255) / 255); f((edge & 255) / 255); // edgeColor
    f(lx); f(ly); // lightDirection
    f(halfX / halfLength); f(halfY / halfLength); f(halfZ / halfLength); // halfway
    canvas.drawPath(g.path, Paint()
      ..isAntiAlias = true
      ..shader = shader);
  }

  @override
  bool shouldRepaint(SeaGlassPainter old) =>
      style != old.style || palette != old.palette || shape != old.shape ||
      program != old.program || controller != old.controller;
}

/// Clips children to the displayed tumbled outline.
class SeaGlassClipper extends CustomClipper<Path> {
  SeaGlassClipper(this.controller, this.style, this.shape) : super(reclip: controller);
  final SeaGlassGeometryController controller;
  final SeaGlassStyle style;
  final SeaGlassShape shape;

  @override
  Path getClip(Size size) => controller.pathFor(size, shape, style.normalized());

  @override
  bool shouldReclip(SeaGlassClipper old) => style != old.style || shape != old.shape;
}
