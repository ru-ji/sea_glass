import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sea_glass/sea_glass.dart';

import '../pages/everyday_pages.dart';
import '../pages/pill_page.dart';
import '../pages/quick_settings_page.dart';

/// Total length of the promo loop.
const promoDuration = Duration(seconds: 10);

/// The full release loop, plus three shorter teaser clips.
enum PromoClip {
  button(Duration(milliseconds: 5500)),
  screen(Duration(milliseconds: 5000)),
  tumble(Duration(milliseconds: 7000), Size(360, 780)), // 1080 x 2340 phone screen
  release(promoDuration);

  const PromoClip(this.duration, [this.size = const Size(360, 640)]);
  final Duration duration;

  /// Logical size. Rendered at 3x.
  final Size size;
}

/// A 9:16 walkthrough of the package, driven entirely by [t] (seconds since
/// the start), so every frame is deterministic. The last frame fades back to
/// the empty background of the first, so the loop joins cleanly.
///
/// 0.0-1.7   title, and a pill dropping into place
/// 1.5-4.0   Sonder, the music player: play is pressed
/// 3.9-6.4   Post, the mail inbox: Archive is selected
/// 6.3-8.7   Nori, a little conversation
/// 8.6-10.0  the one-line API, then fade out
class PromoScene extends StatelessWidget {
  const PromoScene({super.key, required this.t, this.clip = PromoClip.release});

  final double t;
  final PromoClip clip;

  // A shade darker than paper, so the phone cards stand out.
  static const background = Color(0xFFEAE7DF);
  static const ink = Color(0xFF17302F);

  @override
  Widget build(BuildContext context) {
    if (clip == PromoClip.tumble) return _TumbleCapture(t: t);
    // Material supplies the text style, and there is no debug underline.
    return Material(
      color: background,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: ink),
        child: LayoutBuilder(builder: (context, constraints) {
          final size = constraints.biggest;
          // The teaser clips reuse the release scenes with a time shift.
          return Stack(children: switch (clip) {
            PromoClip.button => [
                _scene(0.0, 3.1, (p) => _StartButton(t: t)),
                _scene(3.0, 4.6, (p) => _Palettes(t: t + 2.6, size: size)),
                _scene(4.5, 5.5, (p) => _Code(t: t)),
                _caption(const [
                  (0.3, 1.5, 'A button made of sea glass'),
                  (1.7, 2.9, 'Press it.'),
                  (3.1, 4.5, 'Any palette, or your Material 3 theme'),
                  (4.6, 5.3, 'One widget.'),
                ]),
              ],
            PromoClip.screen => [
                _scene(0.0, 2.9, (p) => _QuickSettings(t: t + 1.6)),
                _scene(2.8, 5.0, (p) => _Shadow(t: t + .8, size: size)),
                _caption(const [
                  (0.2, 2.7, 'Quick Settings, made of glass'),
                  (3.0, 4.8, 'Choose where the shadow falls'),
                ]),
              ],
            _ => [ // full release
                _scene(0.0, 1.7, (p) => _Title(t: t)),
                _scene(1.5, 4.0, (p) => _Phone(
                    t: t - 1.5, child: MusicPage(key: ValueKey(t >= 2.9), initiallyPlaying: t >= 2.9))),
                _scene(3.9, 6.4, (p) => _Phone(
                    t: t - 3.9, child: PostPage(key: ValueKey(t >= 5.7), initiallyArchive: t >= 5.7))),
                _scene(6.3, 8.7, (p) => _Phone(t: t - 6.3, child: const NoriPage())),
                _scene(8.6, 10.0, (p) => _Code(t: t)),
                _caption(const [
                  (0.3, 1.6, 'Frosted, softly tumbled glass'),
                  (1.7, 3.8, 'Music that feels calm'),
                  (4.1, 6.2, 'Mail with room to breathe'),
                  (6.5, 8.5, 'A little conversation'),
                  (8.8, 9.8, 'One widget.'),
                ]),
              ],
          });
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

  Widget _caption(List<(double, double, String)> captions) {
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
          child: Column(children: [
            const Text('INTRODUCING', style: TextStyle(fontSize: 13, letterSpacing: 4, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text('Sea Glass', style: serif(54, height: 1.05)),
            Text('for Flutter', style: serif(24, color: const Color(0xFF3B7D66), italic: true)),
          ]),
        ),
      ),
      const SizedBox(height: 64),
      Opacity(
        opacity: _ease(_progress(t, 0.35, 0.6)),
        child: Transform.translate(
          offset: Offset(0, (1 - drop) * -70),
          child: const SeaGlassSurface(
            width: 220,
            height: 64,
            shape: SeaGlassShape.capsule,
            palette: mint,
            style: quietGlass,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.play_arrow, size: 26), SizedBox(width: 8), Text('Listen', style: TextStyle(fontSize: 22)),
            ]),
          ),
        ),
      ),
      const Spacer(flex: 4),
    ]);
  }
}

/// Looks like a screen recording of the Playground tab: a finger drags the
/// Tumble slider and then Frost, and the glass reshapes as it goes.
class _TumbleCapture extends StatelessWidget {
  const _TumbleCapture({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    double move(double a, double b, double from, double to) =>
        from + (to - from) * Curves.easeInOut.transform(_progress(t, a, b));
    // Steps of .001, so each value's outline is built only once.
    final tumble = (move(3.2, 4.2, move(0.8, 2.6, 0, .065), .025) * 1000).round() / 1000;
    final frost = (move(4.8, 6.2, .55, 1) * 100).round() / 100;
    final style = SeaGlassStyle.reference.copyWith(tumble: tumble, frost: frost);
    final touchTumble = t > .6 && t < 4.4;
    final touchFrost = t > 4.6 && t < 6.4;
    Widget slider(String label, double value, double max, bool touched) => Row(children: [
          SizedBox(width: 64, child: Text(label)),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final x = 24 + (c.maxWidth - 48) * value / max;
              return Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: [
                Slider(value: value, max: max, onChanged: (_) {}),
                if (touched)
                  Positioned(
                    left: x - 18,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: .18),
                          border: Border.all(color: Colors.white.withValues(alpha: .7), width: 2)),
                    ),
                  ),
              ]);
            }),
          ),
          SizedBox(width: 44, child: Text(value.toStringAsFixed(3), style: const TextStyle(fontSize: 11))),
        ]);
    return Theme(
      data: ThemeData(colorSchemeSeed: const Color(0xFF1E6F7C), useMaterial3: true, fontFamily: 'Google Sans'),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4EF),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Spacer(),
              Center(
                child: SeaGlassButton(
                  onPressed: () {},
                  width: 240,
                  height: 80,
                  palette: SeaGlassPalette.lagoon,
                  style: style.copyWith(seed: 33),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.edit_outlined), SizedBox(width: 12), Text('Compose', style: TextStyle(fontSize: 20)),
                  ]),
                ),
              ),
              const SizedBox(height: 36),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final (i, p) in [SeaGlassPalette.lilac, SeaGlassPalette.amber, SeaGlassPalette.mint].indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SeaGlassSurface(
                      width: 72,
                      height: 72,
                      shape: SeaGlassShape.disc,
                      palette: p,
                      style: style.copyWith(seed: 12 + i),
                      child: Icon([Icons.add, Icons.favorite_border, Icons.music_note][i]),
                    ),
                  ),
              ]),
              const Spacer(),
              slider('Tumble', tumble, .065, touchTumble),
              slider('Frost', frost, 1, touchFrost),
              const SizedBox(height: 16),
            ]),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: 2,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.tune), label: 'Quick settings'),
            NavigationDestination(icon: Icon(Icons.smart_button_outlined), label: 'Pill'),
            NavigationDestination(icon: Icon(Icons.science_outlined), label: 'Playground'),
          ],
        ),
      ),
    );
  }
}

/// A frosted Start button drops in, gets pressed (2 px offset, as in
/// SeaGlassButton) and turns lagoon.
class _StartButton extends StatelessWidget {
  const _StartButton({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final drop = Curves.easeOutBack.transform(_progress(t, 0.1, 1.0));
    final pressed = t > 1.8 && t < 2.0;
    final on = t >= 2.0;
    return Column(children: [
      const Spacer(flex: 3),
      Opacity(
        opacity: _ease(_progress(t, 0.1, 0.4)),
        child: Transform.translate(
          offset: Offset(0, (1 - drop) * -70 + (pressed ? 2 : 0)),
          child: SeaGlassSurface(
            width: 240,
            height: 72,
            shape: SeaGlassShape.capsule,
            palette: on ? lagoonPill : frosted,
            style: pillStyle.copyWith(seed: 33),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(on ? Icons.check : Icons.play_arrow_rounded, size: 26, color: (on ? lagoonPill : frosted).ink),
              const SizedBox(width: 8),
              Text(on ? 'Started' : 'Start', style: TextStyle(fontSize: 26, color: (on ? lagoonPill : frosted).ink)),
            ]),
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
    // 180 to 90 to 135 degrees, then the tint switches on.
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

/// A phone screen on a paper card that rises into place. [t] starts at 0.
class _Phone extends StatelessWidget {
  const _Phone({required this.t, required this.child});
  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rise = _ease(_progress(t, 0, .6));
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Align(
        alignment: Alignment.topCenter,
        child: Transform.translate(
          offset: Offset(0, (1 - rise) * 30),
          child: Container(
            width: 226,
            height: 226 * 891 / 411,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: paper,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [BoxShadow(color: Color(0x1F3B3426), blurRadius: 28, offset: Offset(0, 10))],
            ),
            child: FittedBox(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
                child: SizedBox(width: 411, height: 891, child: child),
              ),
            ),
          ),
        ),
      ),
    );
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
    // Hold each palette and crossfade during the last 0.15 s of its slot.
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
        '  onPressed: play,',
        '  palette: SeaGlassPalette.mint,',
        '  style: SeaGlassStyle.quiet,',
        '  child: Icon(Icons.play_arrow),',
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
