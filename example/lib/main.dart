import 'package:flutter/material.dart';
import 'package:sea_glass/sea_glass.dart';

void main() => runApp(const SeaGlassExample());

class SeaGlassExample extends StatefulWidget {
  const SeaGlassExample({super.key});

  @override
  State<SeaGlassExample> createState() => _SeaGlassExampleState();
}

class _SeaGlassExampleState extends State<SeaGlassExample> {
  static const palettes = [
    SeaGlassPalette.lagoon, SeaGlassPalette.lilac, SeaGlassPalette.rose,
    SeaGlassPalette.amber, SeaGlassPalette.mint,
  ];
  int palette = 0;
  bool materialYou = false;
  double tumble = 0.025, frost = 0.55, light = 315;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: Builder(builder: (context) {
        final glass = materialYou ? SeaGlassPalette.of(context) : palettes[palette];
        final style = SeaGlassStyle.reference.copyWith(tumble: tumble, frost: frost, lightDegrees: light);
        return Scaffold(
          backgroundColor: const Color(0xFFF7F4EF),
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(32), children: [
              SeaGlassTheme(
                style: style,
                palette: glass,
                child: Wrap(spacing: 24, runSpacing: 40, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SeaGlassButton(
                    onPressed: () {},
                    width: 220, height: 72,
                    style: style.copyWith(seed: 33),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.edit_outlined), SizedBox(width: 12), Text('Compose'),
                    ]),
                  ),
                  SeaGlassButton(
                    onPressed: () {},
                    shape: SeaGlassShape.capsule,
                    style: style.copyWith(seed: 7),
                    child: const Text('Capsule'),
                  ),
                  SeaGlassSurface(
                    width: 80, height: 80, shape: SeaGlassShape.disc,
                    style: style.copyWith(seed: 12),
                    child: const Icon(Icons.add),
                  ),
                ]),
              ),
              const SizedBox(height: 40),
              Wrap(spacing: 8, children: [
                for (var i = 0; i < palettes.length; i++)
                  ChoiceChip(
                    label: Text(['Lagoon', 'Lilac', 'Rose', 'Amber', 'Mint'][i]),
                    selected: !materialYou && palette == i,
                    onSelected: (_) => setState(() { palette = i; materialYou = false; }),
                  ),
              ]),
              SwitchListTile(
                title: const Text('Material 3 colors'),
                value: materialYou,
                onChanged: (v) => setState(() => materialYou = v),
              ),
              _slider('Tumble', tumble, 0.065, (v) => tumble = v),
              _slider('Frost', frost, 1, (v) => frost = v),
              _slider('Light', light, 360, (v) => light = v),
            ]),
          ),
        );
      }),
    );
  }

  Widget _slider(String label, double value, double max, ValueChanged<double> set) =>
      Row(children: [
        SizedBox(width: 64, child: Text(label)),
        Expanded(child: Slider(value: value, max: max, onChanged: (v) => setState(() => set(v)))),
      ]);
}
