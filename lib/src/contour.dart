import 'dart:math' as math;
import 'dart:ui';

import 'random.dart';
import 'style.dart';

const double _tau = math.pi * 2.0;

/// One closed cubic segment of the tumbled outline.
class ContourSegment {
  const ContourSegment(this.start, this.control1, this.control2, this.end);
  final Offset start, control1, control2, end;
}

/// Exact port of the reference's seeded, fitted tumbled outline.
List<Offset> buildContour(
  double width,
  double height, {
  SeaGlassShape shape = SeaGlassShape.rounded,
  double tumble = 0.025,
  int seed = 42,
  int count = 160,
}) {
  final w = math.max(1.0, width);
  final h = math.max(1.0, height);
  final short = math.min(w, h);
  final amount = tumble.clamp(0.0, 0.065);
  final random = SeaGlassRandom(seed);
  final phase = List<double>.generate(3, (_) => random.nextDouble() * _tau);
  final s0 = 0.70 + random.nextDouble() * 0.10;
  final s1 = 0.18 + random.nextDouble() * 0.04;
  final strength = [s0, s1];
  final samples = math.max(64, count);
  final radius = shape == SeaGlassShape.capsule ? short / 2.0 : short * 0.46;
  final arc = math.pi * radius / 2.0;
  final horizontal = math.max(0.0, w - radius * 2.0);
  final vertical = math.max(0.0, h - radius * 2.0);
  final lengths = [horizontal, arc, vertical, arc, horizontal, arc, vertical, arc];
  final perimeter = lengths.fold(0.0, (a, b) => a + b);
  final base = List<Offset>.generate(samples, (i) {
    final t = i / samples * _tau;
    if (shape == SeaGlassShape.disc) {
      final angle = t - math.pi / 2.0;
      return Offset(w / 2.0 + math.cos(angle) * w / 2.0, h / 2.0 + math.sin(angle) * h / 2.0);
    }
    var distance = i / samples * perimeter;
    var segment = 0;
    while (segment < 7 && distance >= lengths[segment]) {
      distance -= lengths[segment];
      segment++;
    }
    final unit = lengths[segment] != 0.0 ? distance / lengths[segment] : 0.0;
    switch (segment) {
      case 0:
        return Offset(radius + distance, 0.0);
      case 2:
        return Offset(w, radius + distance);
      case 4:
        return Offset(w - radius - distance, h);
      case 6:
        return Offset(0.0, h - radius - distance);
      default:
        final corner = (segment - 1) ~/ 2;
        final angle = -math.pi / 2.0 + corner * math.pi / 2.0 + unit * math.pi / 2.0;
        final center = switch (corner) {
          0 => Offset(w - radius, radius),
          1 => Offset(w - radius, h - radius),
          2 => Offset(radius, h - radius),
          _ => Offset(radius, radius),
        };
        return Offset(center.dx + math.cos(angle) * radius, center.dy + math.sin(angle) * radius);
    }
  });
  final ellipseA = w / 2.0;
  final ellipseB = h / 2.0;
  final curveLength = shape == SeaGlassShape.disc
      ? math.pi *
          (3.0 * (ellipseA + ellipseB) -
              math.sqrt((3.0 * ellipseA + ellipseB) * (ellipseA + 3.0 * ellipseB)))
      : perimeter;
  final sigma = math.max(0.7, short * 0.065 / (curveLength / samples));
  final reach = (sigma * 3.0).ceil();
  final weights = List<double>.generate(reach * 2 + 1, (i) {
    final distance = (i - reach).toDouble();
    return math.exp(-(distance * distance) / (2.0 * sigma * sigma));
  });
  final weightSum = weights.fold(0.0, (a, b) => a + b);
  final smooth = List<Offset>.generate(samples, (i) {
    var x = 0.0, y = 0.0;
    for (var k = 0; k < weights.length; k++) {
      final neighbor = base[(i + k - reach + samples) % samples];
      x += neighbor.dx * weights[k] / weightSum;
      y += neighbor.dy * weights[k] / weightSum;
    }
    return Offset(x, y);
  });
  final points = List<Offset>.generate(samples, (i) {
    final point = smooth[i];
    final prev = smooth[(i - 1 + samples) % samples];
    final next = smooth[(i + 1) % samples];
    final dx = next.dx - prev.dx;
    final dy = next.dy - prev.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    final t = i / samples * _tau;
    final ripple = math.sin(t * 2.0 + phase[0]) * strength[0] + math.sin(t * 3.0 + phase[1]) * strength[1];
    final displacement = short * amount * ripple;
    return Offset(point.dx + dy / length * displacement, point.dy - dx / length * displacement);
  });
  var minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity;
  for (final p in points) {
    minX = math.min(minX, p.dx);
    maxX = math.max(maxX, p.dx);
    minY = math.min(minY, p.dy);
    maxY = math.max(maxY, p.dy);
  }
  final inset = math.min(0.45, short * 0.005);
  return [
    for (final p in points)
      Offset(
        inset + (p.dx - minX) / (maxX - minX) * (w - inset * 2.0),
        inset + (p.dy - minY) / (maxY - minY) * (h - inset * 2.0),
      ),
  ];
}

/// Periodic uniform cubic B-spline; exact C2 joins without interpolation overshoot.
List<ContourSegment> contourSegments(List<Offset> points) {
  assert(points.length >= 4);
  final n = points.length;
  return List.generate(n, (i) {
    final a = points[(i - 1 + n) % n];
    final b = points[i];
    final c = points[(i + 1) % n];
    final d = points[(i + 2) % n];
    return ContourSegment(
      Offset((a.dx + 4.0 * b.dx + c.dx) / 6.0, (a.dy + 4.0 * b.dy + c.dy) / 6.0),
      Offset((2.0 * b.dx + c.dx) / 3.0, (2.0 * b.dy + c.dy) / 3.0),
      Offset((b.dx + 2.0 * c.dx) / 3.0, (b.dy + 2.0 * c.dy) / 3.0),
      Offset((b.dx + 4.0 * c.dx + d.dx) / 6.0, (b.dy + 4.0 * c.dy + d.dy) / 6.0),
    );
  });
}

Path contourToPath(List<ContourSegment> segments, [double scale = 1.0]) {
  final path = Path();
  if (segments.isEmpty) return path;
  path.moveTo(segments[0].start.dx * scale, segments[0].start.dy * scale);
  for (final s in segments) {
    path.cubicTo(s.control1.dx * scale, s.control1.dy * scale, s.control2.dx * scale,
        s.control2.dy * scale, s.end.dx * scale, s.end.dy * scale);
  }
  return path..close();
}
