import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:emf_quantum_focus/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('보정 완료 상태에서 대시보드가 표시된다', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'calibration_done_v1': true,
      'calibration_off_x': 0.0,
      'calibration_off_y': 0.0,
      'calibration_off_z': 0.0,
    });

    await tester.pumpWidget(const EmfQuantumFocusApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('대시보드'), findsOneWidget);
  });
}
