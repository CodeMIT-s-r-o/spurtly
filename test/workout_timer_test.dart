import 'package:flutter_test/flutter_test.dart';
import 'package:spurtly/models/phase.dart';
import 'package:spurtly/models/workout_config.dart';
import 'package:spurtly/timer/workout_timer.dart';

void main() {
  // One interval per round and no round rest: work and rest simply alternate.
  const config = WorkoutConfig(
    warmup: Duration(seconds: 10),
    work: Duration(seconds: 30),
    rest: Duration(seconds: 15),
    intervals: 1,
    rounds: 3,
    roundRest: Duration.zero,
  );

  group('WorkoutConfig', () {
    test('has no rest after the last round', () {
      expect(config.phases.map((p) => (p.type, p.round)), [
        (PhaseType.warmup, 0),
        (PhaseType.work, 1),
        (PhaseType.rest, 1),
        (PhaseType.work, 2),
        (PhaseType.rest, 2),
        (PhaseType.work, 3),
      ]);
      expect(config.total, const Duration(seconds: 10 + 3 * 30 + 2 * 15));
    });

    test('uses round rest between rounds and rest within them', () {
      final circuit = config.copyWith(
        intervals: 2,
        rounds: 2,
        roundRest: const Duration(minutes: 1),
      );
      expect(circuit.phases.map((p) => (p.type, p.round, p.interval)), [
        (PhaseType.warmup, 0, 0),
        (PhaseType.work, 1, 1),
        (PhaseType.rest, 1, 1),
        (PhaseType.work, 1, 2),
        (PhaseType.roundRest, 1, 0),
        (PhaseType.work, 2, 1),
        (PhaseType.rest, 2, 1),
        (PhaseType.work, 2, 2),
      ]);
      expect(circuit.total, const Duration(seconds: 10 + 4 * 30 + 2 * 15 + 60));
    });

    test('falls back to normal rest between rounds when round rest is off', () {
      final circuit = config.copyWith(intervals: 2, rounds: 2);
      expect(circuit.phases.map((p) => p.type), [
        PhaseType.warmup,
        PhaseType.work,
        PhaseType.rest,
        PhaseType.work,
        PhaseType.rest,
        PhaseType.work,
        PhaseType.rest,
        PhaseType.work,
      ]);
    });

    test('drops warm-up and rest when they are zero', () {
      final noBreaks = config.copyWith(
        warmup: Duration.zero,
        rest: Duration.zero,
      );
      expect(noBreaks.phases.map((p) => p.type), [
        PhaseType.work,
        PhaseType.work,
        PhaseType.work,
      ]);
    });
  });

  group('WorkoutTimer', () {
    late Duration now;
    late List<Phase?> changes;
    late List<int> countdown;
    late WorkoutTimer timer;

    setUp(() {
      now = Duration.zero;
      changes = [];
      countdown = [];
      timer = WorkoutTimer(
        config,
        clock: () => now,
        onPhaseChanged: changes.add,
        onCountdown: countdown.add,
        tickInterval: const Duration(days: 1), // ticks are driven manually
      );
    });

    tearDown(() => timer.dispose());

    void advance(int seconds) {
      now += Duration(seconds: seconds);
      timer.tick();
    }

    test('walks through every phase and finishes', () {
      timer.start();
      expect(timer.phase?.type, PhaseType.warmup);
      expect(timer.phaseSecondsLeft, 10);

      advance(9);
      expect(timer.phaseSecondsLeft, 1);
      expect(timer.totalSecondsLeft, config.total.inSeconds - 9);
      advance(1);
      expect((timer.phase?.type, timer.phase?.round), (PhaseType.work, 1));
      expect(timer.phaseSecondsLeft, 30);

      advance(30 + 15 + 30 + 15 + 30);
      expect(timer.isFinished, isTrue);
      expect(timer.isRunning, isFalse);
      expect(timer.totalRemaining, Duration.zero);
      expect(changes.last, isNull);
    });

    test('reports each phase once, in order', () {
      timer.start();
      for (var i = 0; i < 135; i++) {
        advance(1);
      }
      expect(changes.map((p) => p?.type), [
        PhaseType.warmup,
        PhaseType.work,
        PhaseType.rest,
        PhaseType.work,
        PhaseType.rest,
        PhaseType.work,
        null,
      ]);
    });

    test('a late tick lands in the right phase without replaying the rest', () {
      timer.start();
      advance(10 + 30 + 15 + 5); // into round 2's work
      expect((timer.phase?.type, timer.phase?.round), (PhaseType.work, 2));
      expect(timer.phaseSecondsLeft, 25);
      expect(changes.map((p) => p?.type), [PhaseType.warmup, PhaseType.work]);
    });

    test('does not count time while paused', () {
      timer.start();
      advance(4);
      timer.pause();
      advance(100);
      expect(timer.phaseSecondsLeft, 6);
      timer.resume();
      advance(6);
      expect(timer.phase?.type, PhaseType.work);
    });

    test('skip jumps to the next phase and keeps paused state', () {
      timer.start();
      advance(3);
      timer.skip();
      expect(timer.phase?.type, PhaseType.work);
      expect(timer.phaseSecondsLeft, 30);
      expect(timer.isRunning, isTrue);

      timer.pause();
      timer.skip();
      expect(timer.phase?.type, PhaseType.rest);
      expect(timer.isRunning, isFalse);
      advance(60);
      expect(timer.phaseSecondsLeft, 15);
    });

    test('counts down the last three seconds of each phase', () {
      timer.start();
      for (var i = 0; i < 10; i++) {
        advance(1);
      }
      expect(countdown, [3, 2, 1]);
      expect(timer.phase?.type, PhaseType.work);
    });

    test('no countdown while paused or when skipping', () {
      timer.start();
      advance(6);
      timer.pause();
      advance(10);
      timer.skip();
      expect(countdown, isEmpty);
    });

    test('active time leaves out pauses and skipped time', () {
      timer.start();
      advance(4);
      timer.pause();
      advance(100); // paused
      timer.resume();
      advance(2);
      timer.skip(); // jumps over the remaining 4 s of the warm-up
      advance(30);
      expect(timer.activeTime, const Duration(seconds: 4 + 2 + 30));
      expect(timer.elapsed, const Duration(seconds: 10 + 30));
    });

    test('progress runs from 0 to 1 within a phase', () {
      timer.start();
      expect(timer.phaseProgress, 0);
      advance(5);
      expect(timer.phaseProgress, closeTo(0.5, 1e-9));
    });
  });
}
