import 'dart:math' show pi;

/// First-order high-pass (one-pole) with runtime sample-rate updates.
///
/// Used after vector demeaning to suppress slow drift / quasi-DC. Digital form:
/// \(y[n] = \alpha (y[n-1] + x[n] - x[n-1])\), \(\alpha = RC/(RC+dt)\).
class HighPassFilter {
  HighPassFilter({required double cutoffHz, required double sampleRateHz}) {
    setSampleRateHz(sampleRateHz, cutoffHz: cutoffHz);
  }

  double _alpha = 1;
  double _y = 0;
  double _xPrev = 0;
  bool _primed = false;

  void setSampleRateHz(double sampleRateHz, {required double cutoffHz}) {
    if (sampleRateHz <= 0 || cutoffHz <= 0) return;
    final dt = 1.0 / sampleRateHz;
    final rc = 1.0 / (2 * pi * cutoffHz);
    _alpha = rc / (rc + dt);
  }

  double push(double x) {
    if (!_primed) {
      _xPrev = x;
      _y = 0;
      _primed = true;
      return 0;
    }
    _y = _alpha * (_y + x - _xPrev);
    _xPrev = x;
    return _y;
  }

  void reset() {
    _y = 0;
    _xPrev = 0;
    _primed = false;
  }
}
