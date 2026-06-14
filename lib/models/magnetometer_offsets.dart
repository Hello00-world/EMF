/// DC offsets estimated during figure-8 calibration (µT, sensor frame).
class MagnetometerOffsets {
  const MagnetometerOffsets({
    required this.ox,
    required this.oy,
    required this.oz,
  });

  final double ox;
  final double oy;
  final double oz;
}
