import 'package:shared_preferences/shared_preferences.dart';

class CalibrationStore {
  static const _kDone = 'calibration_done_v1';
  static const _kX = 'calibration_off_x';
  static const _kY = 'calibration_off_y';
  static const _kZ = 'calibration_off_z';

  Future<bool> isCalibrationDone() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kDone) ?? false;
  }

  Future<(double x, double y, double z)?> loadOffset() async {
    final p = await SharedPreferences.getInstance();
    if (!(p.getBool(_kDone) ?? false)) return null;
    return (
      p.getDouble(_kX) ?? 0,
      p.getDouble(_kY) ?? 0,
      p.getDouble(_kZ) ?? 0,
    );
  }

  Future<void> saveOffset(double x, double y, double z) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDone, true);
    await p.setDouble(_kX, x);
    await p.setDouble(_kY, y);
    await p.setDouble(_kZ, z);
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kDone);
    await p.remove(_kX);
    await p.remove(_kY);
    await p.remove(_kZ);
  }
}
