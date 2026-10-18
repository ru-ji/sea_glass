import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sea_glass/sea_glass.dart';

import '../pages/pill_page.dart';
import '../pages/quick_settings_page.dart';

/// Total length of the promo loop.
const promoDuration = Duration(seconds: 8);

/// A vertical (9:16) presentation of the package, driven entirely by [t]
/// (seconds since the start), so every frame is deterministic. The last frame
/// fades back to the empty background of the first, for a seamless loop.
///
/// 0.0–1.7  title, and a pill dropping into place
/// 1.5–3.6  Quick Settings tiles light up, the brightness slider moves
/// 3.5–5.6  the shadow turns (shadowDegrees) and takes the tint (shadowTinted)
/// 5.5–7.1  palettes, then a Material 3 theme
/// 7.0–8.0  the one-line API, then fade out
class PromoScene extends StatelessWidget {
  const PromoScene({super.key, required this.t});

  final double t;

  static const background = Color(0xFFEEF3F2);
  static const ink = Color(0xFF17302F);

  @override
  Widget build(BuildContext context) {
    // Material provides the theme's text style (and no debug underline).
    return Material(
      color: background,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: ink),
        child: LayoutBuilder(builder: (context, constraints) {
          final size = constraints.biggest;
          return Stack(children: [
            _scene(0.0, 1.7, (p) => _Title(t: t)),
            _scene(1.5, 3.6, (p) => _QuickSettings(t: t)),
            _scene(3.5, 5.6, (p) => _Shadow(t: t, size: size)),
            _scene(5.5, 7.1, (p) => _Palettes(t: t, size: size)),
            _scene(7.0, 8.0, (p) => _Code(t: t)),
            _caption(),
          ]);
        }),
      ),
    );
  }

  /// Shows [child] between [start] and [end], fading and sliding in and out.
  Widget _scene(double start, double end, Widget Function(double) child) {
    if (t < start || t > end) return const SizedBox.shrink();
    final fadeIn = start == 0 ? 1.0 : _ease(_progress(t, start, start + .25));
    final fadeOut = 1 - _ease(_progress(t, end - .25, end));
    final opacity = math.min(fadeIn, fadeOut);
    return Positioned.fill(
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, (1 - fadeIn) * 24 - (1 - fadeOut) * 24),
          child: child(_progress(t, start, end)),
        ),
      ),
    );
  }

  Widget _caption() {
    const captions = [
      (0.3, 1.6, 'Frosted, softly tumbled glass'),
      (1.7, 3.5, 'Quick Settings, made of glass'),
      (3.7, 5.5, 'Choose where the shadow falls'),
      (5.7, 7.0, 'Any palette, or your Material 3 theme'),
      (7.1, 7.8, 'One widget.'),
    ];
    for (final (start, end, text) in captions) {
      if (t >= start && t <= end) {
        final o = math.min(_ease(_progress(t, start, start + .3)), 1 - _ease(_progress(t, end - .25, end)));
        return Positioned(
          left: 24,
          right: 24,
          bottom: 56,
          child: Opacity(
            opacity: o,
            child: Text(text, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, color: ink.withValues(alpha: .72), letterSpacing: .2)),
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }
}

double _progress(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
double _ease(double x) => Curves.easeOutCubic.transform(x);

class _Title extends StatelessWidget {
  const _Title({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final title = _ease(_progress(t, 0.05, 0.7));
    final drop = Curves.easeOutBack.transform(_progress(t, 0.35, 1.25));
    return Column(children: [
      const Spacer(flex: 3),
      Opacity(
        opacity: title,
        child: Transform.translate(
          offset: Offset(0, (1 - title) * 16),
          child: const Column(children: [
            Text('INTRODUCING', style: TextStyle(fontSize: 13, letterSpacing: 4, fontWeight: FontWeight.w600)),
            SizedBox(height: 10),
            Text('sea_glass', style: TextStyle(fontSize: 52, fontWeight: FontWeight.w300, height: 1.05)),
            Text('for Flutter', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400)),
          ]),
        ),
      ),
      const SizedBox(height: 64),
      Opacity(
        opacity: _ease(_progress(t, 0.35, 0.6)),
        child: Transform.translate(
          offset: Offset(0, (1 - drop) * -70),
          child: const SeaGlassSurface(
            width: 260,
            height: 72,
            shape: SeaGlassShape.capsule,
            palette: lagoonPill,
            style: pillStyle,
            child: Text('Sea Glass', style: TextStyle(fontSize: 26)),
          ),
        ),
      ),
      const Spacer(flex: 4),
    ]);
  }
}

class _QuickSettings extends StatelessWidget {
  const _QuickSettings({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final wifi = t > 2.2;
    final location = t > 2.75;
    final brightness = .3 + .45 * Curves.easeInOut.transform(_progress(t, 2.4, 3.3));
    Widget row(List<Widget> children) => Row(children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 10), children[i]],
        ]);
    Widget tile(IconData icon, bool active, int seed, {String? label, String? subtitle, int flex = 1}) => Expanded(
          flex: flex,
          child: QsTile(icon: icon, label: label, subtitle: subtitle, active: active, seed: seed, onPressed: () {}),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(height: 40),
        GlassSlider(value: brightness, onChanged: (_) {}),
        const SizedBox(height: 22),
        row([
          tile(Icons.wifi, wifi, 1, label: 'Wi-Fi', subtitle: wifi ? 'On' : 'Off', flex: 2),
          tile(Icons.bluetooth, false, 3, label: 'Bluetooth', flex: 2),
        ]),
        const SizedBox(height: 10),
        row([
          tile(Icons.flashlight_on_outlined, false, 4),
          tile(Icons.location_on, location, 5),
          tile(Icons.sync_alt, false, 10, label: 'Share', flex: 2),
        ]),
        const SizedBox(height: 10),
        row([
          tile(Icons.flight, false, 8),
          tile(Icons.qr_code_scanner, false, 9),
          tile(Icons.bed_outlined, false, 6, label: 'Modes', flex: 2),
        ]),
        const SizedBox(height: 80),
      ]),
    );
  }
}

class _Shadow extends StatelessWidget {
  const _Shadow({required this.t, required this.size});
  final double t;
  final Size size;

  @override
  Widget build(BuildContext context) {
    // 180° → 90° → 135°, then the tint switches on.
    final turn = Curves.easeInOut.transform(_progress(t, 3.8, 4.5));
    final settle = Curves.easeInOut.transform(_progress(t, 4.5, 5.0));
    final degrees = (180 - 90 * turn + 45 * settle).roundToDouble();
    final tinted = t > 5.1;
    return Column(children: [
      const Spacer(flex: 3),
      SeaGlassSurface(
        width: 260,
        height: 72,
        shape: SeaGlassShape.capsule,
        palette: lagoonPill,
        style: pillStyle.copyWith(shadowDegrees: degrees, shadowTinted: tinted, transmission: .55, elevation: 18),
        child: const Text('Sea Glass', style: TextStyle(fontSize: 26)),
      ),
      const SizedBox(height: 70),
      _CodeChip(lines: [
        'shadowDegrees: ${degrees.toInt()}',
        'shadowTinted: $tinted',
      ]),
      const Spacer(flex: 4),
    ]);
  }
}

class _Palettes extends StatelessWidget {
  const _Palettes({required this.t, required this.size});
  final double t;
  final Size size;

  static SeaGlassPalette lerp(SeaGlassPalette a, SeaGlassPalette b, double x) => SeaGlassPalette(
        body: Color.lerp(a.body, b.body, x)!,
        edge: Color.lerp(a.edge, b.edge, x)!,
        ink: Color.lerp(a.ink, b.ink, x)!,
      );

  @override
  Widget build(BuildContext context) {
    final material = SeaGlassPalette.fromColorScheme(ColorScheme.fromSeed(seedColor: const Color(0xFF3B7D4F)));
    final stops = [(lagoonPill, 'Lagoon'), (lilacPill, 'Lilac'), (amberPill, 'Amber'), (material, 'Material 3')];
    // Hold each palette, crossfading during the last 0.15 s of its slot.
    final slot = _progress(t, 5.6, 7.0) * stops.length;
    final index = slot.floor().clamp(0, stops.length - 1);
    final next = math.min(index + 1, stops.length - 1);
    final blend = Curves.easeInOut.transform(((slot - index - .7) / .3).clamp(0.0, 1.0));
    final palette = lerp(stops[index].$1, stops[next].$1, blend);
    final name = blend < .5 ? stops[index].$2 : stops[next].$2;
    return Column(children: [
      const Spacer(flex: 3),
      SeaGlassSurface(
        width: 260,
        height: 72,
        shape: SeaGlassShape.capsule,
        palette: palette,
        style: pillStyle,
        child: Text(name, style: const TextStyle(fontSize: 26)),
      ),
      const SizedBox(height: 46),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final (i, (p, _)) in stops.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SeaGlassSurface(
              width: 34,
              height: 34,
              shape: SeaGlassShape.disc,
              palette: p,
              style: pillStyle.copyWith(seed: 40 + i, elevation: 6),
              child: i == index ? Icon(Icons.check, size: 16, color: p.ink) : null,
            ),
          ),
      ]),
      const Spacer(flex: 4),
    ]);
  }
}

class _Code extends StatelessWidget {
  const _Code({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    return const Column(children: [
      Spacer(flex: 3),
      _CodeChip(lines: [
        'SeaGlassButton(',
        '  onPressed: compose,',
        '  palette: SeaGlassPalette.lagoon,',
        "  child: Text('Compose'),",
        ')',
      ]),
      SizedBox(height: 40),
      Text('flutter pub add sea_glass', style: TextStyle(fontFamily: 'monospace', fontSize: 14)),
      Spacer(flex: 4),
    ]);
  }
}

class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in lines)
            Text(line, style: const TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}

/// Plays [PromoScene] in a loop inside the app.
class PromoPage extends StatefulWidget {
  const PromoPage({super.key});

  @override
  State<PromoPage> createState() => _PromoPageState();
}

class _PromoPageState extends State<PromoPage> with SingleTickerProviderStateMixin {
  late final controller = AnimationController(vsync: this, duration: promoDuration)..repeat();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => PromoScene(t: controller.value * promoDuration.inMilliseconds / 1000),
        ),
      ),
    );
  }
}
