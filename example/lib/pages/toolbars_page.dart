import 'package:flutter/material.dart';
import 'package:sea_glass/sea_glass.dart';

import 'pill_page.dart';

const _coral = SeaGlassPalette(body: Color(0xFFF5A99C), edge: Color(0xFFFFD6CE), ink: Color(0xFF7A2418));
const _lilac = SeaGlassPalette(body: Color(0xFFE3A8F5), edge: Color(0xFFF8DBFF), ink: Color(0xFF5E1F80));
const _periwinkle = SeaGlassPalette(body: Color(0xFFA9BDF5), edge: Color(0xFFDCE5FF), ink: Color(0xFF22408A));
const _magenta = SeaGlassPalette(body: Color(0xFFEE5FB0), edge: Color(0xFFFFA8E3), ink: Color(0xFF7A0A45));
const _lemon = SeaGlassPalette(body: Color(0xFFE6E58A), edge: Color(0xFFFFFBC0), ink: Color(0xFF5C5200));
const _peach = SeaGlassPalette(body: Color(0xFFF5B27A), edge: Color(0xFFFFD9B0), ink: Color(0xFF7A3A10));

/// Toolbars, tabs and an input bar: glass that holds more than one control.
class ToolbarsPage extends StatelessWidget {
  const ToolbarsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(children: [
          Expanded(
              flex: 4,
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _glass(_coral, 70, 70, SeaGlassShape.disc,
                    const Text('S', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700))),
                _glass(
                    _lilac,
                    360,
                    64,
                    SeaGlassShape.capsule,
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 24, 0),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        _chip(const Icon(Icons.photo, size: 22), 'Photos'),
                        const Text('Collections', style: TextStyle(fontSize: 19)),
                        const Text('Create', style: TextStyle(fontSize: 19)),
                      ]),
                    )),
                _glass(
                    _periwinkle,
                    420,
                    70,
                    SeaGlassShape.capsule,
                    Row(children: [
                      const SizedBox(width: 20),
                      const Icon(Icons.add, size: 22),
                      const SizedBox(width: 18),
                      const Expanded(child: Text('Ask anything', style: TextStyle(fontSize: 18))),
                      const Icon(Icons.mic, size: 22),
                      const SizedBox(width: 10),
                      _round(const Icon(Icons.graphic_eq, size: 22)),
                      const SizedBox(width: 6),
                    ])),
              ])),
          const SizedBox(width: 24),
          Expanded(
              flex: 6,
              child: Column(children: [
                Expanded(child: _tile(const Color(0xFFE9C7E0), replyBar())),
                const SizedBox(height: 24),
                Expanded(child: _tile(const Color(0xFFEAD7CB), emojiBar())),
              ])),
        ]),
      ),
    );
  }

  /// The pink toolbar with a flat, recessed "Reply all" split button.
  static Widget replyBar() => _glass(
      _magenta,
      470,
      84,
      SeaGlassShape.capsule,
      Row(children: [
        const SizedBox(width: 20),
        for (final i in [Icons.archive, Icons.schedule, Icons.more_vert]) ...[
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Icon(i, size: 26)),
        ],
        const Spacer(),
        _inset('Reply all', const BorderRadius.horizontal(left: Radius.circular(30), right: Radius.circular(6)), 160),
        const SizedBox(width: 4),
        _inset(null, const BorderRadius.horizontal(left: Radius.circular(6), right: Radius.circular(30)), 64),
        const SizedBox(width: 12),
      ]));

  /// The yellow icon bar next to the orange squircle action button.
  static Widget emojiBar() => Row(mainAxisSize: MainAxisSize.min, children: [
        _glass(
            _lemon,
            290,
            80,
            SeaGlassShape.capsule,
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (final i in [Icons.add_reaction, Icons.chat, Icons.place, Icons.grid_view]) Icon(i, size: 24),
            ])),
        const SizedBox(width: 20),
        _glass(_peach, 122, 122, SeaGlassShape.squircle, const Icon(Icons.edit, size: 34)),
      ]);

  static Widget _tile(Color color, Widget child) => SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(28)),
          child: Center(child: child),
        ),
      );

  static Widget _glass(SeaGlassPalette p, double w, double h, SeaGlassShape shape, Widget child) => SeaGlassSurface(
        width: w,
        height: h,
        shape: shape,
        palette: p,
        style: pillStyle.copyWith(seed: w.toInt()),
        child: child,
      );

  static Widget _round(Widget child) => Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .4), shape: BoxShape.circle),
        child: child,
      );

  /// A flat, recessed control sitting inside the glass: not glass itself.
  static Widget _inset(String? label, BorderRadius radius, double width) => Container(
        width: width,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9C2560), Color(0xFF7E0C48)],
          ),
        ),
        child: IconTheme(
          data: const IconThemeData(color: Color(0xFFFF8FD0)),
          child: label == null
              ? const Icon(Icons.expand_more, size: 28)
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.reply_all, size: 26),
                  const SizedBox(width: 10),
                  Text(label, style: const TextStyle(fontSize: 20, color: Color(0xFFFF8FD0))),
                ]),
        ),
      );

  static Widget _chip(Widget icon, String text) => Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .4), borderRadius: BorderRadius.circular(25)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          icon,
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 19)),
        ]),
      );
}
