// Kept in its own file: other widget tests start the shader load inside
// the fake-async test zone, where it never completes.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sea_glass/sea_glass.dart';
import 'package:sea_glass/src/painter.dart';

void main() {
  testWidgets('precached piece is complete on its first frame', (tester) async {
    const size = Size(200, 64);
    const style = SeaGlassStyle(seed: 9);
    await tester.runAsync(() => SeaGlass.precache(size, style: style));
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: SeaGlass(width: 200, height: 64, style: style)),
    ));
    final paint = tester.widget<CustomPaint>(
        find.descendant(of: find.byType(SeaGlass), matching: find.byType(CustomPaint)));
    final painter = paint.painter! as SeaGlassPainter;
    expect(painter.program, isNotNull);
    expect(painter.controller.displayedFor(size), isNotNull);
  });
}
