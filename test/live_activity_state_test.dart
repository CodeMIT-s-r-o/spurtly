import 'package:flutter_test/flutter_test.dart';
import 'package:spurtly/models/workout_config.dart';
import 'package:spurtly/services/live_activity.dart';
import 'package:spurtly/timer/workout_timer.dart';

void main() {
  const config = WorkoutConfig(
    warmup: Duration.zero,
    work: Duration(seconds: 30),
    rest: Duration(seconds: 15),
    intervals: 2,
    rounds: 2,
    roundRest: Duration(minutes: 1),
  );
  final now = DateTime.utc(2026, 10, 16, 12);

  late Duration clock;
  late WorkoutTimer timer;

  setUp(() {
    clock = Duration.zero;
    timer = WorkoutTimer(
      config,
      clock: () => clock,
      tickInterval: const Duration(days: 1),
    );
  });

  tearDown(() => timer.dispose());

  void advance(int seconds) {
    clock += Duration(seconds: seconds);
    timer.tick();
  }

  test('a running phase counts down from its start to its end', () {
    timer.start();
    advance(10);
    final state = LiveActivityState.of(timer, now);

    expect(state.phase, 'work');
    expect(state.label, 'Work');
    expect(state.position, 'Round 1 / 2 · Interval 1 / 2');
    expect(state.next, 'Next: Rest · 0:15');
    expect(state.phaseStart, now.subtract(const Duration(seconds: 10)));
    expect(state.phaseEnd, now.add(const Duration(seconds: 20)));
    expect(state.pausedRemaining, isNull);
  });

  test('a paused phase carries the time left', () {
    timer.start();
    advance(30 + 15 + 30 + 5); // 5 s into the round rest
    timer.pause();
    final state = LiveActivityState.of(timer, now);

    expect(state.phase, 'roundRest');
    expect(state.position, 'Round 1 / 2 · Round complete');
    expect(state.next, 'Next: Round 2 · 0:30');
    expect(state.pausedRemaining, const Duration(seconds: 55));
    expect(state.toMap()['pausedRemaining'], 55.0);
  });

  test('a finished workout shows its summary', () {
    timer.start();
    advance(config.total.inSeconds);
    final state = LiveActivityState.of(timer, now);

    expect(state.phase, 'done');
    expect(state.label, 'Workout complete');
    expect(state.position, '4 intervals · 3:30');
  });

  test('toMap matches what the iOS side reads', () {
    timer.start();
    final map = LiveActivityState.of(timer, now).toMap();

    expect(map.keys, {
      'phase',
      'label',
      'position',
      'next',
      'phaseStartMs',
      'phaseEndMs',
      'pausedRemaining',
    });
    expect(map['phaseStartMs'], now.millisecondsSinceEpoch.toDouble());
    expect(
      map['phaseEndMs'],
      now.add(const Duration(seconds: 30)).millisecondsSinceEpoch.toDouble(),
    );
  });
}
