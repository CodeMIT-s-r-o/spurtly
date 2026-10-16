import 'phase.dart';

/// The user's interval setup: an optional warm-up, then [rounds] rounds of
/// [intervals] work intervals each.
///
/// Work intervals are separated by [rest]. Between rounds the optional
/// [roundRest] is used instead, falling back to [rest] when it is off.
/// Nothing follows the very last work interval.
class WorkoutConfig {
  const WorkoutConfig({
    required this.warmup,
    required this.work,
    required this.rest,
    required this.intervals,
    required this.rounds,
    required this.roundRest,
  });

  static const defaults = WorkoutConfig(
    warmup: Duration(minutes: 1),
    work: Duration(seconds: 30),
    rest: Duration(seconds: 15),
    intervals: 4,
    rounds: 3,
    roundRest: Duration(minutes: 1),
  );

  final Duration warmup;
  final Duration work;
  final Duration rest;
  final int intervals;
  final int rounds;
  final Duration roundRest;

  List<Phase> get phases {
    final phases = [
      if (warmup > Duration.zero) Phase(PhaseType.warmup, warmup),
    ];
    for (var round = 1; round <= rounds; round++) {
      for (var interval = 1; interval <= intervals; interval++) {
        phases.add(
          Phase(PhaseType.work, work, round: round, interval: interval),
        );
        final restAfter = Phase(
          PhaseType.rest,
          rest,
          round: round,
          interval: interval,
        );
        if (interval < intervals) {
          if (rest > Duration.zero) phases.add(restAfter);
        } else if (round < rounds) {
          if (roundRest > Duration.zero) {
            phases.add(Phase(PhaseType.roundRest, roundRest, round: round));
          } else if (rest > Duration.zero) {
            phases.add(restAfter);
          }
        }
      }
    }
    return phases;
  }

  Duration get total =>
      phases.fold(Duration.zero, (sum, p) => sum + p.duration);

  WorkoutConfig copyWith({
    Duration? warmup,
    Duration? work,
    Duration? rest,
    int? intervals,
    int? rounds,
    Duration? roundRest,
  }) {
    return WorkoutConfig(
      warmup: warmup ?? this.warmup,
      work: work ?? this.work,
      rest: rest ?? this.rest,
      intervals: intervals ?? this.intervals,
      rounds: rounds ?? this.rounds,
      roundRest: roundRest ?? this.roundRest,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorkoutConfig &&
      other.warmup == warmup &&
      other.work == work &&
      other.rest == rest &&
      other.intervals == intervals &&
      other.rounds == rounds &&
      other.roundRest == roundRest;

  @override
  int get hashCode =>
      Object.hash(warmup, work, rest, intervals, rounds, roundRest);
}
