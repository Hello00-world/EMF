import 'dart:math' as math;

class _Sample {
  _Sample(this.t, this.x, this.y, this.z);
  final DateTime t;
  final double x;
  final double y;
  final double z;
}

/// Subtracts the mean of all samples within [window] ending at the latest time.
class RollingVectorMean {
  RollingVectorMean({required this.window});

  final Duration window;
  final List<_Sample> _q = [];

  void push(DateTime t, double x, double y, double z) {
    _q.add(_Sample(t, x, y, z));
    final cutoff = t.subtract(window);
    while (_q.isNotEmpty && _q.first.t.isBefore(cutoff)) {
      _q.removeAt(0);
    }
  }

  void clear() => _q.clear();

  bool get hasData => _q.isNotEmpty;

  /// Returns (x - meanX, y - meanY, z - meanZ). If empty, returns inputs unchanged.
  (double, double, double) demean(double x, double y, double z) {
    if (_q.isEmpty) return (x, y, z);
    var sx = 0.0;
    var sy = 0.0;
    var sz = 0.0;
    for (final s in _q) {
      sx += s.x;
      sy += s.y;
      sz += s.z;
    }
    final n = _q.length.toDouble();
    return (x - sx / n, y - sy / n, z - sz / n);
  }

  static double magnitude(double x, double y, double z) {
    return math.sqrt(x * x + y * y + z * z);
  }
}
