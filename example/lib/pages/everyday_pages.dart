import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sea_glass/sea_glass.dart';

/// Three everyday screens, music, mail and a little conversation, on a warm
/// paper background. The glass stays quiet: soft frost, a faint rim, short
/// shadows.

const paper = Color(0xFFF4F2EC);
const _ink = Color(0xFF1F2A26);
const _muted = Color(0xFF8A908C);
const _line = Color(0xFFE6E3DB);

const _serif = 'Newsreader';
TextStyle serif(double size, {Color color = _ink, bool italic = false, double height = 1.15}) => TextStyle(
      fontFamily: _serif,
      fontSize: size,
      color: color,
      height: height,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    );
TextStyle _sans(double size, {Color color = _ink, FontWeight weight = FontWeight.w400, double spacing = 0}) =>
    TextStyle(fontSize: size, color: color, fontWeight: weight, letterSpacing: spacing);
TextStyle _caps(double size, {Color color = _muted}) =>
    _sans(size, color: color, weight: FontWeight.w600, spacing: size * .18);

const mint = SeaGlassPalette(body: Color(0xFFBFE3D2), edge: Color(0xFFEFFFF7), ink: Color(0xFF1E4D3E));
const sky = SeaGlassPalette(body: Color(0xFFB9D3F0), edge: Color(0xFFEEF6FF), ink: Color(0xFF2B4F7A));
const lilac = SeaGlassPalette(body: Color(0xFFE2C6EE), edge: Color(0xFFFBF0FF), ink: Color(0xFF5B3570));
const peach = SeaGlassPalette(body: Color(0xFFF2D3B3), edge: Color(0xFFFFF4E8), ink: Color(0xFF7A4A24));
const _cloud = SeaGlassPalette(body: Color(0xFFF7F6F2), edge: Color(0xFFFFFFFF), ink: _ink);

/// Quiet glass: little transmitted light and a short shadow.
const quietGlass = SeaGlassStyle(
  frost: .55, grain: .5, tumble: .004, thickness: 5, bulge: .5, elevation: 7, transmission: .3, seed: 9,
);

Widget _glass(SeaGlassPalette p, double w, double h, Widget child,
        {SeaGlassShape shape = SeaGlassShape.capsule, int seed = 9, VoidCallback? onPressed, String? label}) =>
    onPressed == null
        ? SeaGlassSurface(width: w, height: h, shape: shape, palette: p, style: quietGlass.copyWith(seed: seed), child: child)
        : SeaGlassButton(
            onPressed: onPressed,
            padding: EdgeInsets.zero,
            semanticLabel: label,
            width: w,
            height: h,
            shape: shape,
            palette: p,
            style: quietGlass.copyWith(seed: seed),
            child: child,
          );

/// The phone frame shared by the three screens: paper, safe area, side padding.
class _Screen extends StatelessWidget {
  const _Screen({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: paper,
      child: SafeArea(
        child: Padding(padding: const EdgeInsets.fromLTRB(26, 20, 26, 12), child: child),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sonder: music

class MusicPage extends StatefulWidget {
  const MusicPage({super.key, this.initiallyPlaying = true});

  final bool initiallyPlaying;

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  late bool playing = widget.initiallyPlaying;
  bool liked = false;
  double position = .42;

  @override
  Widget build(BuildContext context) {
    String time(double f) {
      final s = (f * 168).round();
      return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    }

    return _Screen(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('SONDER', style: _caps(11, color: _ink)),
          const Spacer(),
          Text('NOW PLAYING', style: _caps(9)),
          const SizedBox(width: 6),
          const CircleAvatar(radius: 2.5, backgroundColor: Color(0xFF3B8C6E)),
        ]),
        const SizedBox(height: 26),
        const AspectRatio(aspectRatio: 1, child: _AlbumArt()),
        const SizedBox(height: 26),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Evening tide', style: serif(30)),
              const SizedBox(height: 4),
              Text('Sora Vale  ·  Slow Current', style: _sans(13, color: _muted)),
            ]),
          ),
          IconButton(
            onPressed: () => setState(() => liked = !liked),
            icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: _ink, size: 24),
          ),
        ]),
        const SizedBox(height: 18),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            activeTrackColor: _ink,
            inactiveTrackColor: _line,
            thumbColor: _ink,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            overlayShape: SliderComponentShape.noOverlay,
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(value: position, onChanged: (v) => setState(() => position = v)),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text(time(position), style: _sans(11, color: _muted)),
          const Spacer(),
          Text(time(1), style: _sans(11, color: _muted)),
        ]),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.skip_previous, size: 30, color: _ink)),
          const SizedBox(width: 30),
          _glass(
            mint, 78, 78,
            Icon(playing ? Icons.pause : Icons.play_arrow, size: 34),
            shape: SeaGlassShape.disc,
            seed: 3,
            label: playing ? 'Pause' : 'Play',
            onPressed: () => setState(() => playing = !playing),
          ),
          const SizedBox(width: 30),
          IconButton(onPressed: () {}, icon: const Icon(Icons.skip_next, size: 30, color: _ink)),
        ]),
        const Spacer(),
        Center(
          child: _glass(
            mint, 190, 52,
            const Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              Icon(Icons.headphones_outlined, size: 21),
              Icon(Icons.repeat, size: 21),
              Icon(Icons.queue_music, size: 21),
            ]),
            seed: 4,
          ),
        ),
        const SizedBox(height: 14),
        Center(child: Text('Listening on headphones', style: _sans(11, color: _muted))),
        const SizedBox(height: 8),
      ]),
    );
  }
}

/// The cover: a sun setting over layered waves, painted so no image is needed.
class _AlbumArt extends StatelessWidget {
  const _AlbumArt();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: CustomPaint(
        painter: _WavesPainter(),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SORA VALE', style: _caps(10, color: const Color(0xFF2E5A4C))),
            const Spacer(),
            Text('Slow\nCurrent', style: serif(42, color: const Color(0xFFF3EFE6), height: 1.0)),
            const SizedBox(height: 12),
            Text('VOLUME 02  ·  2026', style: _caps(8, color: const Color(0xCCF3EFE6))),
          ]),
        ),
      ),
    );
  }
}

class _WavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFA9CDB4), Color(0xFF8DBB9E)],
      ).createShader(Offset.zero & size));
    canvas.drawCircle(Offset(w * .6, h * .4), w * .22, Paint()..color = const Color(0xFFEB9A68));
    // Three bands of water, each darker and lower than the last.
    for (final (i, color) in [const Color(0xFF5E9A80), const Color(0xFF3F7D66), const Color(0xFF2B6252)].indexed) {
      final top = h * (.5 + i * .13);
      final path = Path()..moveTo(0, top);
      for (var x = 0.0; x <= w; x += 4) {
        path.lineTo(x, top + math.sin(x / w * math.pi * 2 + i * 1.3) * h * .035);
      }
      path..lineTo(w, h)..lineTo(0, h)..close();
      canvas.drawPath(path, Paint()..color = color);
    }
    // Fine current lines on the deepest band.
    final line = Paint()
      ..color = const Color(0x33F3EFE6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var k = 0; k < 4; k++) {
      final y = h * (.82 + k * .04);
      final path = Path()..moveTo(w * .45, y);
      for (var x = w * .45; x <= w; x += 4) {
        path.lineTo(x, y + math.sin(x / w * math.pi * 3 + k) * 3);
      }
      canvas.drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(_WavesPainter old) => false;
}

// ---------------------------------------------------------------------------
// Post: mail

class PostPage extends StatefulWidget {
  const PostPage({super.key, this.initiallyArchive = false});

  final bool initiallyArchive;

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  late bool archive = widget.initiallyArchive;

  static const _mail = [
    ('MB', Color(0xFFF6DCC8), 'Maya Bennett', '9:41', 'A table by the window', 'Saturday at ten? Coffee is on me.'),
    ('S', Color(0xFFD5EBDF), 'Studio Notes', '8:25', 'Things worth keeping', 'A few good things from this week.'),
    ('OC', Color(0xFFE6DDF0), 'Oliver Chen', '8:02', 'The first sketches', 'I think we found our direction.'),
  ];

  @override
  Widget build(BuildContext context) {
    return _Screen(
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Post', style: serif(32)),
            const Spacer(),
            CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFE9E6DF),
              child: Text('AL', style: _sans(10, color: _muted, weight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 22),
          Text('Room to breathe.', style: serif(23)),
          const SizedBox(height: 6),
          Text('Your day, thoughtfully delivered.', style: _sans(12, color: _muted)),
          const SizedBox(height: 26),
          LayoutBuilder(builder: (context, c) {
            final half = (c.maxWidth - 12) / 2;
            Widget tab(String text, bool selected, VoidCallback onTap) => GestureDetector(
                  onTap: onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: half,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white.withValues(alpha: .55) : Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(text, style: _sans(13, color: sky.ink, weight: selected ? FontWeight.w600 : FontWeight.w400)),
                      if (text == 'Inbox') ...[
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 9,
                          backgroundColor: Colors.white.withValues(alpha: .7),
                          child: Text('3', style: _sans(10, color: sky.ink)),
                        ),
                      ],
                    ]),
                  ),
                );
            return _glass(
              sky, c.maxWidth, 56,
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                tab('Inbox', !archive, () => setState(() => archive = false)),
                tab('Archive', archive, () => setState(() => archive = true)),
              ]),
              seed: 5,
            );
          }),
          const SizedBox(height: 30),
          Row(children: [
            Text('TODAY', style: _caps(10)),
            const Spacer(),
            Text(archive ? 'Nothing archived' : '3 conversations', style: _sans(11, color: _muted)),
          ]),
          const SizedBox(height: 14),
          if (!archive)
            for (final (i, m) in _mail.indexed) ...[
              if (i > 0) const Divider(height: 1, color: _line),
              _MailItem(mail: m),
            ],
        ]),
        Positioned(
          right: 0,
          bottom: 44,
          child: _glass(
            sky, 132, 50,
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.edit_outlined, size: 18),
              const SizedBox(width: 8),
              Text('Compose', style: _sans(14, color: sky.ink, weight: FontWeight.w500)),
            ]),
            seed: 6,
            onPressed: () {},
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 4,
          child: Center(child: Text('The rest can wait a little.', style: serif(13, color: _muted))),
        ),
      ]),
    );
  }
}

class _MailItem extends StatelessWidget {
  const _MailItem({required this.mail});
  final (String, Color, String, String, String, String) mail;

  @override
  Widget build(BuildContext context) {
    final (initials, tint, name, time, subject, snippet) = mail;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: tint,
          child: Text(initials, style: _sans(10.5, color: const Color(0xFF6B5E55), weight: FontWeight.w600)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(name, style: _sans(14, weight: FontWeight.w600)),
              const Spacer(),
              Text(time, style: _sans(11, color: _muted)),
            ]),
            const SizedBox(height: 5),
            Text(subject, style: _sans(13.5)),
            const SizedBox(height: 5),
            Text(snippet, style: _sans(12.5, color: _muted)),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Nori: a little conversation

class NoriPage extends StatefulWidget {
  const NoriPage({super.key});

  @override
  State<NoriPage> createState() => _NoriPageState();
}

class _NoriPageState extends State<NoriPage> {
  static const _stops = [
    ('10:00', 'Coffee, slowly', 'Find a sunny table. Stay a while.'),
    ('11:30', 'A book you didn’t plan on', 'Let a small bookstore surprise you.'),
    ('1:00', 'Follow the water', 'An easy walk, with no destination.'),
  ];

  @override
  Widget build(BuildContext context) {
    return _Screen(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _glass(_cloud, 40, 40, const Icon(Icons.auto_awesome, size: 17), shape: SeaGlassShape.disc, seed: 7),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nori', style: serif(22)),
            Text('A little clarity, every day', style: _sans(10.5, color: _muted)),
          ]),
          const Spacer(),
          Text('New', style: _sans(12, color: _muted)),
        ]),
        const SizedBox(height: 26),
        Center(child: Text('A LITTLE SPACE FOR IDEAS', style: _caps(9))),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 290),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(color: const Color(0xFFE9E7E0), borderRadius: BorderRadius.circular(18)),
            child: Text('A quiet Sunday: coffee, a bookstore, and a walk by the water.',
                style: _sans(13.5, color: const Color(0xFF3A403D)).copyWith(height: 1.45)),
          ),
        ),
        const SizedBox(height: 26),
        Row(children: [
          const Icon(Icons.auto_awesome, size: 11, color: _muted),
          const SizedBox(width: 6),
          Text('NORI', style: _caps(9)),
        ]),
        const SizedBox(height: 10),
        Text('A slower kind of Sunday.', style: serif(26)),
        const SizedBox(height: 8),
        Text('Three good stops. No need to rush between them.', style: _sans(12.5, color: _muted)),
        const SizedBox(height: 20),
        for (final (time, title, note) in _stops)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 50, child: Text(time, style: _sans(11.5, color: _muted))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: _sans(14, weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(note, style: _sans(12.5, color: _muted)),
                ]),
              ),
            ]),
          ),
        const Spacer(),
        Row(children: [
          for (final (i, chip) in ['If it rains?', 'More outdoors'].indexed) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: LayoutBuilder(builder: (context, c) => _glass(
                    lilac, c.maxWidth, 46, Text(chip, style: _sans(13, color: lilac.ink)),
                    seed: 20 + i, onPressed: () {},
                  )),
            ),
          ],
        ]),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, c) => _glass(
              _cloud, c.maxWidth, 58,
              Row(children: [
                const SizedBox(width: 22),
                Expanded(child: Text('Make it a slower morning', style: _sans(14, color: const Color(0xFF3A403D)))),
                _glass(lilac, 42, 42, const Icon(Icons.arrow_upward, size: 19),
                    shape: SeaGlassShape.disc, seed: 24, onPressed: () {}, label: 'Send'),
                const SizedBox(width: 8),
              ]),
              seed: 23,
            )),
        const SizedBox(height: 16),
        Center(child: Text('A thought partner, at your pace.', style: serif(13, color: _muted))),
        const SizedBox(height: 4),
      ]),
    );
  }
}
