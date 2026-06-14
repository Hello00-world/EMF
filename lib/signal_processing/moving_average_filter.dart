/// Simple moving average (FIR) smoother.
///
/// At ~50 Hz sample rate, a window of 5–6 samples spans ~100 ms and
/// partially attenuates 50/60 Hz power-line ripple when present in the
/// magnetometer channel (not a substitute for a true notch filter).
class MovingAverageFilter {
  MovingAverageFilter(this.windowSize) : assert(windowSize > 0, 'windowSize must be positive');

  final int windowSize;
  final List<double> _buf = [];

  /// Pushes [x], returns the current window mean.
  double push(double x) {
    _buf.add(x);
    while (_buf.length > windowSize) {
      _buf.removeAt(0);
    }
    return _average(_buf);
  }

  void reset() => _buf.clear();

  static double _average(List<double> xs) {
    if (xs.isEmpty) return 0;
    var s = 0.0;
    for (final v in xs) {
      s += v;
    }
    return s / xs.length;
  }
}
