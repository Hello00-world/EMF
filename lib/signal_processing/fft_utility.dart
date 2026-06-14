import 'dart:math' as math;

/// In-place Cooley–Tukey FFT on complex arrays [re], [im] of length [n] (must be power of two).
void fftInPlace(List<double> re, List<double> im) {
  final n = re.length;
  assert(n == im.length && n > 0 && (n & (n - 1)) == 0, 'n must be power of 2');

  var j = 0;
  for (var i = 1; i < n; i++) {
    var bit = n >> 1;
    while (j & bit != 0) {
      j ^= bit;
      bit >>= 1;
    }
    j ^= bit;
    if (i < j) {
      var t = re[i];
      re[i] = re[j];
      re[j] = t;
      t = im[i];
      im[i] = im[j];
      im[j] = t;
    }
  }

  for (var len = 2; len <= n; len <<= 1) {
    final ang = -2 * math.pi / len;
    final wlenRe = math.cos(ang);
    final wlenIm = math.sin(ang);
    for (var i = 0; i < n; i += len) {
      var wRe = 1.0;
      var wIm = 0.0;
      for (var k = 0; k < len >> 1; k++) {
        final i0 = i + k;
        final i1 = i0 + (len >> 1);
        final tRe = wRe * re[i1] - wIm * im[i1];
        final tIm = wRe * im[i1] + wIm * re[i1];
        re[i1] = re[i0] - tRe;
        im[i1] = im[i0] - tIm;
        re[i0] += tRe;
        im[i0] += tIm;
        final nwRe = wRe * wlenRe - wIm * wlenIm;
        final nwIm = wRe * wlenIm + wIm * wlenRe;
        wRe = nwRe;
        wIm = nwIm;
      }
    }
  }
}

/// Band energy ratio: sum(|X[k]|^2) for k in [kLow, kHigh] divided by total energy (excl. DC bin 0).
double bandEnergyRatio({
  required List<double> re,
  required List<double> im,
  required int kLow,
  required int kHigh,
}) {
  final n = re.length;
  var band = 0.0;
  var total = 0.0;
  final half = n >> 1;
  for (var k = 1; k < half; k++) {
    final p = re[k] * re[k] + im[k] * im[k];
    total += p;
    if (k >= kLow && k <= kHigh) {
      band += p;
    }
  }
  if (total <= 1e-30) return 0;
  return (band / total * 100).clamp(0.0, 100.0);
}

/// Dominant frequency bin index in [1, n/2 - 1] by magnitude squared.
int dominantBin(List<double> re, List<double> im) {
  final half = re.length >> 1;
  var bestK = 1;
  var bestP = 0.0;
  for (var k = 1; k < half; k++) {
    final p = re[k] * re[k] + im[k] * im[k];
    if (p > bestP) {
      bestP = p;
      bestK = k;
    }
  }
  return bestK;
}

double binToHz(int k, double sampleRateHz, int n) {
  return k * sampleRateHz / n;
}
