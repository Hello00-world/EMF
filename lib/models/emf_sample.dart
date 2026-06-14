class EmfSample {
  const EmfSample({
    required this.timestamp,
    required this.filteredMagnitudeMicroTesla,
    required this.variance,
    required this.rawX,
    required this.rawY,
    required this.rawZ,
    this.lineNoisePercent = 0,
    this.dominantFrequencyHz = 0,
  });

  final DateTime timestamp;
  final double filteredMagnitudeMicroTesla;
  final double variance;
  final double rawX;
  final double rawY;
  final double rawZ;
  final double lineNoisePercent;
  final double dominantFrequencyHz;
}
