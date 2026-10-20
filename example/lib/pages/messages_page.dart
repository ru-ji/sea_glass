import 'package:flutter/material.dart';
import 'package:sea_glass/sea_glass.dart';

import 'pill_page.dart';

const _milk = SeaGlassPalette(body: Color(0xFFF7F7F7), edge: Color(0xFFFFFFFF), ink: Color(0xFF5A5A5A));
const _mint = SeaGlassPalette(body: Color(0xFFDDEBDD), edge: Color(0xFFF4FFF4), ink: Color(0xFF3E4A3E));
const _hay = SeaGlassPalette(body: Color(0xFFEFF2C8), edge: Color(0xFFFFFFE8), ink: Color(0xFF4A4A30));
const _teal = SeaGlassPalette(body: Color(0xFF2CC9BD), edge: Color(0xFF9EFFF4), ink: Colors.white);
const _jade = SeaGlassPalette(body: Color(0xFF31B98A), edge: Color(0xFFA8FFD8), ink: Colors.white);
const _leaf = SeaGlassPalette(body: Color(0xFF4CC93C), edge: Color(0xFFC4FFB0), ink: Colors.white);
const _berry = SeaGlassPalette(body: Color(0xFFD81B7A), edge: Color(0xFFFF9FD0), ink: Colors.white);

/// On a photo the glass casts no shadow, like the concept.
final _onPhoto = pillStyle.copyWith(shadowColor: Colors.transparent, transmission: .2);

/// Message composers on plain and photo backgrounds.
class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Expanded(child: Row(children: [
            Expanded(child: card(null, _milk, _teal)),
            const SizedBox(width: 24),
            Expanded(child: card('pebbles', _mint, _jade)),
          ])),
          const SizedBox(height: 24),
          Expanded(child: Row(children: [
            Expanded(child: card('meadow', _hay, _leaf)),
            const SizedBox(width: 24),
            Expanded(child: card(null, _milk, _berry)),
          ])),
        ]),
      ),
    );
  }

  /// The composer on the meadow photo, casting no shadow.
  static Widget meadow() => card('meadow', _hay, _leaf);

  static Widget card(String? photo, SeaGlassPalette field, SeaGlassPalette mic) => ClipRRect(
        borderRadius: BorderRadius.circular(56),
        child: Stack(fit: StackFit.expand, children: [
          if (photo == null)
            const ColoredBox(color: Color(0xFFF3F2F3))
          else
            Image.asset('assets/gallery/$photo.jpg', fit: BoxFit.cover),
          Positioned(
            left: 28,
            right: 28,
            bottom: 36,
            child: Row(children: [
              Expanded(
                child: LayoutBuilder(builder: (context, c) => SeaGlassSurface(
                      width: c.maxWidth,
                      height: 66,
                      shape: SeaGlassShape.capsule,
                      palette: field,
                      style: photo == null ? pillStyle : _onPhoto,
                      child: const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(left: 26),
                          child: Text('Type your message…', style: TextStyle(fontSize: 17)),
                        ),
                      ),
                    )),
              ),
              const SizedBox(width: 16),
              SeaGlassSurface(
                width: 92,
                height: 70,
                shape: SeaGlassShape.capsule,
                palette: mic,
                style: photo == null ? pillStyle : _onPhoto,
                child: const Icon(Icons.mic_none, size: 28),
              ),
            ]),
          ),
        ]),
      );
}
