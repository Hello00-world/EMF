/// Virtual device pose on the desk in Quantum Space (meters, desk-centered frame).
class DeskPose {
  const DeskPose(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  @override
  bool operator ==(Object other) =>
      other is DeskPose && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);
}
