import 'package:emf_quantum_focus/signal_processing/moving_average_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MovingAverageFilter N=3 smooths steps', () {
    final f = MovingAverageFilter(3);
    expect(f.push(10), 10);
    expect(f.push(20), 15);
    expect(f.push(30), 20);
    expect(f.push(0), closeTo(50 / 3, 1e-9));
  });
}
