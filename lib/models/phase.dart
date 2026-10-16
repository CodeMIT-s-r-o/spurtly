enum PhaseType { warmup, work, rest, roundRest }

/// One timed segment of a workout.
class Phase {
  const Phase(this.type, this.duration, {this.round = 0, this.interval = 0});

  final PhaseType type;
  final Duration duration;

  /// 1-based round this phase belongs to; 0 for the warm-up.
  /// A rest carries the round it follows.
  final int round;

  /// 1-based interval within [round]; 0 for the warm-up and round rest.
  /// A rest carries the interval it follows.
  final int interval;

  @override
  String toString() =>
      'Phase($type, ${duration.inSeconds}s, round $round, interval $interval)';
}
