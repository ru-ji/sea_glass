/// Mulberry32, matching the reference `SeededRandom` (JavaScript imul and
/// unsigned shifts, 32-bit wraparound), so seeds give identical streams.
class SeaGlassRandom {
  SeaGlassRandom(int seed) : _value = seed & _mask;

  static const int _mask = 0xFFFFFFFF;
  static const int _step = 0x6D2B79F5;
  int _value;

  double nextDouble() {
    _value = (_value + _step) & _mask;
    return _mix(_value);
  }

  /// Read an offset in this stream without consuming the intervening values.
  double sample(int index) {
    assert(index >= 0);
    return _mix((_value + imul(index + 1, _step)) & _mask);
  }

  void advance(int count) {
    assert(count >= 0);
    _value = (_value + imul(count, _step)) & _mask;
  }

  SeaGlassRandom copy() => SeaGlassRandom(_value);

  /// 32-bit wrapping multiply, safe on the web (keeps products below 2^53).
  static int imul(int a, int b) {
    a &= _mask;
    b &= _mask;
    final ah = a >>> 16;
    final al = a & 0xFFFF;
    return (al * b + (((ah * b) & 0xFFFF) << 16)) & _mask;
  }

  static double _mix(int state) {
    var n = state;
    n = imul(n ^ (n >>> 15), n | 1);
    n = (n ^ ((n + imul(n ^ (n >>> 7), n | 61)) & _mask)) & _mask;
    return ((n ^ (n >>> 14)) & _mask) / 4294967296.0;
  }
}
