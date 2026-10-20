import 'package:flutter/material.dart';
import 'package:sea_glass/sea_glass.dart';

import 'pill_page.dart';

const _blue = SeaGlassPalette(body: Color(0xFF63B4F2), edge: Color(0xFFC4E8FF), ink: Color(0xFF0B3A6B));
const _deepBlue = SeaGlassPalette(body: Color(0xFF2F63B0), edge: Color(0xFF9CC2FF), ink: Colors.white);
const _yellow = SeaGlassPalette(body: Color(0xFFF1EFA6), edge: Color(0xFFFFFFD6), ink: Color(0xFF7A4A1C));
const _green = SeaGlassPalette(body: Color(0xFFA8E67E), edge: Color(0xFFE2FFC4), ink: Color(0xFF16360A));
const _pink = SeaGlassPalette(body: Color(0xFFF7C6F0), edge: Color(0xFFFFE9FB), ink: Color(0xFF4A0E45));
const _mist = SeaGlassPalette(body: Color(0xFFA9CBEA), edge: Color(0xFFE3F1FF), ink: Color(0xFF0B3A6B));

/// A board of glass components in the style of the Material 4 concept art.
class ShowcasePage extends StatelessWidget {
  const ShowcasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEEF1FA),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Expanded(
            flex: 5,
            child: Row(children: [
              Expanded(flex: 3, child: _tile(FittedBox(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 34), child: actions())))),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: Column(children: [
                Expanded(child: _tile(_glass(_yellow, 88, SeaGlassShape.disc, const Text('S', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w700))))),
                const SizedBox(height: 24),
                Expanded(child: _tile(_glass(_green, 72, SeaGlassShape.squircle, const Icon(Icons.add, size: 40)))),
              ])),
              const SizedBox(width: 24),
              Expanded(flex: 5, child: _tile(_photo())),
            ]),
          ),
          const SizedBox(height: 24),
          Expanded(
            flex: 3,
            child: Row(children: [
              Expanded(flex: 3, child: _tile(Row(mainAxisSize: MainAxisSize.min, children: [
                _bar(_pink, [Icons.check_circle, Icons.favorite, Icons.description, Icons.calendar_month], height: 56),
                const SizedBox(width: 12),
                _glass(_pink, 56, SeaGlassShape.squircle, const Icon(Icons.edit)),
              ]))),
              const SizedBox(width: 24),
              Expanded(flex: 5, child: _tile(Row(mainAxisSize: MainAxisSize.min, children: [
                _label(_blue, Icons.check_circle, 'Going', 150),
                const SizedBox(width: 12),
                _label(_mist, Icons.block, 'Not going', 190),
                const SizedBox(width: 12),
                _label(_mist, Icons.help_outline, 'Maybe', 140),
              ]))),
            ]),
          ),
        ]),
      ),
    );
  }

  static Widget _tile(Widget child) => DecoratedBox(
        decoration: BoxDecoration(color: const Color(0xFFDDE2F1), borderRadius: BorderRadius.circular(40)),
        child: Center(child: child),
      );

  static Widget _glass(SeaGlassPalette p, double size, SeaGlassShape shape, Widget child, {int seed = 3}) =>
      SeaGlassSurface(
        width: size, height: size, shape: shape, palette: p, style: pillStyle.copyWith(seed: seed), child: child,
      );

  static Widget _label(SeaGlassPalette p, IconData icon, String text, double width) => SeaGlassSurface(
        width: width,
        height: 64,
        shape: SeaGlassShape.capsule,
        palette: p,
        style: pillStyle.copyWith(seed: text.length),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 26), const SizedBox(width: 8), Text(text, style: const TextStyle(fontSize: 22)),
        ]),
      );

  static Widget _bar(SeaGlassPalette p, List<IconData> icons, {double height = 48}) => SeaGlassSurface(
        width: 44.0 * icons.length + 16,
        height: height,
        shape: SeaGlassShape.capsule,
        palette: p,
        style: pillStyle.copyWith(seed: 7),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (final i in icons) Icon(i, size: 22)]),
      );

  /// Album actions stacked right-aligned above a close button.
  static Widget actions() => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final (i, (icon, text, w)) in [
          (Icons.check_circle, 'Select', 150.0), (Icons.add_a_photo, 'Add photos', 190.0),
          (Icons.share, 'Share album', 200.0), (Icons.search, 'Search', 150.0),
        ].indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SeaGlassSurface(
              width: w, height: 64, shape: SeaGlassShape.capsule, palette: _blue,
              style: pillStyle.copyWith(seed: i + 1),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 22), const SizedBox(width: 8), Text(text, style: const TextStyle(fontSize: 18)),
              ]),
            ),
          ),
        _glass(_deepBlue, 64, SeaGlassShape.disc, const Icon(Icons.close, size: 26)),
      ]);

  static Widget _scene(String name) => SizedBox.expand(child: Image.asset('assets/gallery/$name.jpg', fit: BoxFit.cover));

  /// A phone-shaped gallery: a mosaic of gradient "photos" with a glass bar floating over it.
  static Widget _photo() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 40),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFC3CFF0),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20), bottom: Radius.circular(44)),
            border: Border.all(color: const Color(0xFFC3CFF0), width: 8),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14), bottom: Radius.circular(38)),
            child: Stack(fit: StackFit.expand, children: [
              Column(children: [
                Expanded(child: Row(children: [
                  Expanded(flex: 5, child: _scene('snow')),
                  const SizedBox(width: 1),
                  Expanded(flex: 3, child: _scene('peaks')),
                ])),
                const SizedBox(height: 1),
                Expanded(child: Row(children: [
                  Expanded(flex: 2, child: _scene('fjord')),
                  const SizedBox(width: 1),
                  Expanded(flex: 5, child: _scene('hills')),
                ])),
              ]),
              Align(alignment: const Alignment(0, .62), child: _bar(_mist, [Icons.share, Icons.favorite, Icons.add_a_photo, Icons.edit])),
              Align(
                alignment: const Alignment(0, .93),
                child: Container(width: 160, height: 4, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
              ),
            ]),
          ),
        ),
      );
}

