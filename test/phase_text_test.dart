import 'package:flutter_test/flutter_test.dart';
import 'package:spurtly/models/workout_config.dart';
import 'package:spurtly/timer/phase_text.dart';

void main() {
  test('workout summary counts intervals in singular and plural', () {
    const single = WorkoutConfig(
      warmup: Duration.zero,
      work: Duration(seconds: 30),
      rest: Duration.zero,
      intervals: 1,
      rounds: 1,
      roundRest: Duration.zero,
    );
    expect(workoutSummary(single), '1 interval · 0:30');
    expect(workoutSummary(single.copyWith(rounds: 2)), '2 intervals · 1:00');
  });
}
