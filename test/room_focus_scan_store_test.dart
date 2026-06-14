import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:emf_quantum_focus/models/desk_pose.dart';
import 'package:emf_quantum_focus/providers/environment_provider.dart';
import 'package:emf_quantum_focus/services/room_focus_scan_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  double scoreAt({
    required double emfAvgMicroTesla,
    required double varianceAvg,
    required double lineNoisePercent,
  }) {
    const w1 = 0.98;
    const w2 = 0.17;
    const w4 = 0.26;
    return (100.0 -
            emfAvgMicroTesla * w1 -
            varianceAvg * w2 -
            lineNoisePercent * w4)
        .clamp(0.0, 100.0);
  }

  test('RoomFocusScanStore picks highest focus score cell', () {
    SharedPreferences.setMockInitialValues({});
    final store = RoomFocusScanStore(spanM: 4, heightSpanM: 2, cellM: 0.5);

    void seed(double x, double z, double emf, int n) {
      for (var i = 0; i < n; i++) {
        store.addSample(
          pose: DeskPose(x, 0.02, z),
          emfMicroTesla: emf,
          variance: 10,
          lineNoisePercent: 5,
        );
      }
    }

    seed(0.5, 0.5, 45, 4);
    seed(-1.0, 1.0, 30, 4);
    seed(1.2, -0.8, 55, 4);

    final best = store.bestZone(scoreFn: scoreAt, minSamples: 3);
    expect(best, isNotNull);
    expect(best!.focusScore, greaterThan(60));
    expect(best.avgEmfMicroTesla, closeTo(30, 1));
    expect(best.x, closeTo(-1.0, 0.6));
  });

  test('RoomFocusScanStore ignores out-of-bounds poses', () {
    final store = RoomFocusScanStore(spanM: 4, cellM: 0.5);
    store.addSample(
      pose: const DeskPose(10, 0.02, 0),
      emfMicroTesla: 40,
      variance: 10,
      lineNoisePercent: 5,
    );
    expect(store.filledCellCount, 0);
  });
}
