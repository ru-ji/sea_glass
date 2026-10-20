import 'dart:math' as math;
import 'dart:typed_data';

import 'random.dart';

final Float32List _f32 = Float32List(1);

/// Rounds to Float32, matching the original's `toFloat()` stores.
double f32(double v) {
  _f32[0] = v;
  return _f32[0];
}

double _clamp(double v, double lo, double hi) => math.max(lo, math.min(hi, v));

double _tanh(double x) {
  if (x > 20) return 1.0;
  if (x < -20) return -1.0;
  final e = math.exp(2 * x);
  return (e - 1) / (e + 1);
}

/// Seeded value-noise grid, a port of the original `NoiseGrid`.
class NoiseGrid {
  NoiseGrid(double width, double height, this.spacing, SeaGlassRandom random,
      {int maxCachedCells = 262144})
      : columns = (width / spacing).ceil() + 2,
        rows = (height / spacing).ceil() + 2,
        _sampleRandom = random.copy() {
    final count = columns * rows;
    if (count <= maxCachedCells) {
      _values = Float32List(count);
      for (var i = 0; i < count; i++) {
        _values![i] = random.nextDouble() * 2.0 - 1.0;
      }
    } else {
      random.advance(count);
    }
  }

  final double spacing;
  final int columns, rows;
  final SeaGlassRandom _sampleRandom;
  Float32List? _values;

  double _value(int x, int y) {
    final index = y * columns + x;
    return _values?[index] ?? f32(_sampleRandom.sample(index) * 2.0 - 1.0);
  }

  double call(double x, double y) {
    final gx = _clamp(x / spacing, 0.0, (columns - 1).toDouble());
    final gy = _clamp(y / spacing, 0.0, (rows - 1).toDouble());
    final ix = math.min(gx.floor(), columns - 2);
    final iy = math.min(gy.floor(), rows - 2);
    final tx = gx - ix;
    final ty = gy - iy;
    final sx = tx * tx * (3.0 - 2.0 * tx);
    final sy = ty * ty * (3.0 - 2.0 * ty);
    final a = _value(ix, iy);
    final b = _value(ix + 1, iy);
    final c = _value(ix, iy + 1);
    final d = _value(ix + 1, iy + 1);
    return (a + (b - a) * sx) * (1.0 - sy) + (c + (d - c) * sx) * sy;
  }
}

/// Live cloud field, ported from `makeLiveCloudTexture`. It consumes exactly
/// the fine and micro streams without building them, like the original.
Float32List makeLiveClouds(double widthDp, double heightDp, double scale, int seed, int width, int height) {
  final random = SeaGlassRandom(seed ^ 0x59BF1D7A);
  void skipGrid(double spacing) {
    final columns = ((widthDp + 3.0) / spacing).ceil() + 2;
    final rows = ((heightDp + 3.0) / spacing).ceil() + 2;
    random.advance(columns * rows);
  }

  skipGrid(0.68);
  skipGrid(1.7);
  final worn = NoiseGrid(widthDp + 3.0, heightDp + 3.0, 7.5, random);
  final cloud = NoiseGrid(widthDp + 3.0, heightDp + 3.0, math.min(widthDp, heightDp) * 0.44, random);
  final clouds = Float32List(width * height);
  for (var y = 0; y < height; y++) {
    final cy = (y + 0.5) / scale;
    for (var x = 0; x < width; x++) {
      final cx = (x + 0.5) / scale;
      clouds[y * width + x] = cloud(cx, cy) * 0.75 + worn(cx, cy) * 0.25;
    }
  }
  return clouds;
}

/// Exact squared Euclidean distance transform. Runs in linear time.
void _distanceLine(Float64List input, int length, Float64List output, Int32List sites, Float64List separators) {
  var k = 0;
  sites[0] = 0;
  separators[0] = double.negativeInfinity;
  separators[1] = double.infinity;
  for (var q = 1; q < length; q++) {
    double cut;
    do {
      final v = sites[k];
      cut = ((input[q] + q.toDouble() * q) - (input[v] + v.toDouble() * v)) / (2.0 * q - 2.0 * v);
      if (cut <= separators[k]) {
        k--;
      } else {
        break;
      }
    } while (k >= 0);
    k++;
    sites[k] = q;
    separators[k] = cut;
    separators[k + 1] = double.infinity;
  }
  k = 0;
  for (var q = 0; q < length; q++) {
    while (separators[k + 1] < q) {
      k++;
    }
    final delta = q - sites[k];
    output[q] = delta.toDouble() * delta + input[sites[k]];
  }
}

Float32List _smoothHeight(Float32List values, int width, int height, double scale) {
  final sigma = 0.85 * scale;
  final reach = (sigma * 3.0).ceil();
  final weights = Float64List(reach * 2 + 1);
  for (var i = 0; i < weights.length; i++) {
    final q = (i - reach) / sigma;
    weights[i] = math.exp(-(q * q) / 2.0);
  }
  var sum = 0.0;
  for (final w in weights) {
    sum += w;
  }
  final horizontal = Float32List(values.length);
  final result = Float32List(values.length);
  for (var y = 0; y < height; y++) {
    final row = y * width;
    for (var x = 0; x < width; x++) {
      var value = 0.0;
      if (x >= reach && x < width - reach) {
        final first = row + x - reach;
        for (var k = 0; k < weights.length; k++) {
          value += values[first + k] * weights[k];
        }
      } else {
        for (var k = 0; k < weights.length; k++) {
          value += values[row + (x + k - reach).clamp(0, width - 1)] * weights[k];
        }
      }
      horizontal[row + x] = value / sum;
    }
  }
  final rowValues = Float64List(width);
  for (var y = 0; y < height; y++) {
    rowValues.fillRange(0, width, 0.0);
    for (var k = 0; k < weights.length; k++) {
      final sourceRow = (y + k - reach).clamp(0, height - 1) * width;
      final weight = weights[k];
      for (var x = 0; x < width; x++) {
        rowValues[x] += horizontal[sourceRow + x] * weight;
      }
    }
    final row = y * width;
    for (var x = 0; x < width; x++) {
      result[row + x] = rowValues[x] / sum;
    }
  }
  return result;
}

/// Inputs for [buildGeometryTextures]. Plain data, so it can cross isolates.
class GeometryRequest {
  const GeometryRequest({
    required this.widthDp,
    required this.heightDp,
    required this.scale,
    required this.seed,
    required this.width,
    required this.height,
    required this.coverage,
  });

  final double widthDp, heightDp, scale;
  final int seed, width, height;

  /// Antialiased contour alpha, (width + 2) by (height + 2), path offset by 1 px.
  final Uint8List coverage;
}

/// Encoded geometry: two opaque RGBA float textures and their gradient scales.
class GeometryTextures {
  const GeometryTextures(this.width, this.height, this.a, this.b, this.gradientScaleA, this.gradientScaleB);
  final int width, height;
  final Float32List a, b;
  final double gradientScaleA, gradientScaleB;
}

/// Port of `makeGeometryField` plus the texture encoding from
/// `makeLiveMaterialGeometry`.
GeometryTextures buildGeometryTextures(GeometryRequest r) {
  final w = r.widthDp, h = r.heightDp;
  final width = r.width, height = r.height, scale = r.scale;
  final clouds = makeLiveClouds(w, h, scale, r.seed, width, height);
  final columns = width + 2;
  final rows = height + 2;
  final coverage = r.coverage;
  final distances = Float32List(columns * rows);
  for (var i = 0; i < distances.length; i++) {
    distances[i] = coverage[i] > 127 ? 1e12 : 0.0;
  }
  final longest = math.max(columns, rows);
  final input = Float64List(longest);
  final output = Float64List(longest);
  final sites = Int32List(longest);
  final separators = Float64List(longest + 1);
  for (var y = 0; y < rows; y++) {
    final row = y * columns;
    for (var x = 0; x < columns; x++) {
      input[x] = distances[row + x];
    }
    _distanceLine(input, columns, output, sites, separators);
    for (var x = 0; x < columns; x++) {
      distances[row + x] = output[x];
    }
  }
  for (var x = 0; x < columns; x++) {
    for (var y = 0; y < rows; y++) {
      input[y] = distances[y * columns + x];
    }
    _distanceLine(input, rows, output, sites, separators);
    for (var y = 0; y < rows; y++) {
      distances[y * columns + x] = math.max(0.0, math.sqrt(output[y]) - 0.5) / scale;
    }
  }
  final count = width * height;
  final profile = Float32List(count);
  final gradX = Float32List(count);
  final gradY = Float32List(count);
  final roundProfile = Float32List(count);
  final roundGradX = Float32List(count);
  final roundGradY = Float32List(count);
  final alpha = Uint8List(count);
  final short = math.min(w, h);
  var maxDistanceRaw = 0.0;
  for (final d in distances) {
    if (d > maxDistanceRaw) maxDistanceRaw = d;
  }
  final maxDistance = math.max(1.0, maxDistanceRaw);
  final columnLengthArch = Float64List(width);
  final columnLengthSlope = Float64List(width);
  for (var x = 0; x < width; x++) {
    final u = (x + 0.5) / width;
    final sine = math.sin(u * math.pi);
    columnLengthArch[x] = 0.86 + 0.14 * sine * sine;
    columnLengthSlope[x] = 0.14 * math.pi / w * math.sin(u * math.pi * 2.0);
  }
  for (var y = 0; y < height; y++) {
    final row = y * width;
    final maskRow = (y + 1) * columns;
    final above = math.max(0, y - 1) * columns;
    final below = math.min(rows - 1, y + 3) * columns;
    for (var x = 0; x < width; x++) {
      final i = row + x;
      final mx = x + 1;
      final distance = distances[maskRow + mx];
      alpha[i] = coverage[maskRow + mx];
      final roll = short * (0.205 + clouds[i] * 0.023);
      final dome = _tanh(distance / roll);
      final slope = (1.0 - dome * dome) / roll;
      profile[i] = dome;
      final dx = distances[maskRow + math.min(columns - 1, x + 3)] - distances[maskRow + math.max(0, x - 1)];
      final dy = distances[below + mx] - distances[above + mx];
      final direction = math.sqrt(dx * dx + dy * dy);
      gradX[i] = direction > 0.001 ? dx / direction * slope : 0.0;
      gradY[i] = direction > 0.001 ? dy / direction * slope : 0.0;
      final q = _clamp(distance / maxDistance, 0.0, 1.0);
      final arch = math.sqrt(q * (2.0 - q));
      final roundSlope = (1.0 - q) / (maxDistance * math.max(arch, 0.035));
      final lengthArch = columnLengthArch[x];
      final lengthSlope = columnLengthSlope[x];
      roundProfile[i] = arch * lengthArch;
      roundGradX[i] = (direction > 0.001 ? dx / direction * roundSlope * lengthArch : 0.0) + arch * lengthSlope;
      roundGradY[i] = direction > 0.001 ? dy / direction * roundSlope * lengthArch : 0.0;
    }
  }
  final softened = _smoothHeight(roundProfile, width, height, scale);
  for (var y = 0; y < height; y++) {
    final row = y * width;
    final maskRow = (y + 1) * columns + 1;
    final above = math.max(0, y - 2) * width;
    final below = math.min(height - 1, y + 2) * width;
    for (var x = 0; x < width; x++) {
      final i = row + x;
      final blend = _clamp((distances[maskRow + x] - 2.0) / 3.0, 0.0, 1.0);
      final weight = blend * blend * (3.0 - 2.0 * blend);
      final rp = roundProfile[i];
      final gx = roundGradX[i];
      final gy = roundGradY[i];
      final dx = softened[row + math.min(width - 1, x + 2)] - softened[row + math.max(0, x - 2)];
      final dy = softened[below + x] - softened[above + x];
      roundProfile[i] = rp + (softened[i] - rp) * weight;
      roundGradX[i] = gx + (dx * scale / 4.0 - gx) * weight;
      roundGradY[i] = gy + (dy * scale / 4.0 - gy) * weight;
    }
  }

  // Texture encoding, using Float32 arithmetic like the original.
  var maxGradientA = f32(0.005), maxGradientB = f32(0.005);
  for (var i = 0; i < count; i++) {
    if (alpha[i] == 0) continue;
    maxGradientA = math.max(maxGradientA, math.max(gradX[i].abs(), gradY[i].abs()));
    maxGradientB = math.max(maxGradientB, math.max(roundGradX[i].abs(), roundGradY[i].abs()));
  }
  final gradientScaleA = f32(f32(0.49) / maxGradientA);
  final gradientScaleB = f32(f32(0.49) / maxGradientB);
  final a = Float32List(count * 4);
  final b = Float32List(count * 4);
  double enc(double g, double s) => f32(0.5 + f32(g * s)).clamp(0.0, 1.0);
  for (var i = 0; i < count; i++) {
    final c = i * 4;
    a[c] = profile[i].clamp(0.0, 1.0);
    a[c + 1] = enc(gradX[i], gradientScaleA);
    a[c + 2] = enc(gradY[i], gradientScaleA);
    a[c + 3] = 1.0;
    b[c] = roundProfile[i].clamp(0.0, 1.0);
    b[c + 1] = enc(roundGradX[i], gradientScaleB);
    b[c + 2] = enc(roundGradY[i], gradientScaleB);
    b[c + 3] = 1.0;
  }
  return GeometryTextures(width, height, a, b, gradientScaleA, gradientScaleB);
}
