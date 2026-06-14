/// One processed magnetometer snapshot after calibration, DC removal, filtering, and optional FFT.
class MagnetometerSnapshot {
  const MagnetometerSnapshot({
    required this.timestamp,
    required this.filteredMagnitudeMicroTesla,
    required this.varianceMicroTeslaSq,
    required this.dx,
    required this.dy,
    required this.dz,
    required this.isSaturated,
    required this.lineNoisePercent,
    required this.dominantFrequencyHz,
    required this.fftReady,
    required this.riskLevel,
    required this.icnirpBand,
    required this.estimatedSampleRateHz,
  });

  final DateTime timestamp;
  final double filteredMagnitudeMicroTesla;
  final double varianceMicroTeslaSq;
  final double dx;
  final double dy;
  final double dz;
  final bool isSaturated;

  /// Share of spectral energy in the configured line-frequency band (see [fftReady]).
  final double lineNoisePercent;
  final double dominantFrequencyHz;
  final bool fftReady;

  /// 1 (low) … 5 (high) visual / UX risk for AR particles.
  final int riskLevel;

  /// Localized label for ICNIRP-inspired three-band UX (not a legal certification).
  final String icnirpBand;

  final double estimatedSampleRateHz;
}
