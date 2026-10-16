import '../models/phase.dart';
import '../models/workout_config.dart';
import '../theme.dart';

/// Where in the workout [phase] is, as a title and optional subtitle:
/// ("Round 2 / 3", "Interval 1 / 4").
(String, String?) phasePosition(Phase phase, WorkoutConfig config) {
  final round = 'Round ${phase.round} / ${config.rounds}';
  final interval = config.intervals > 1
      ? 'Interval ${phase.interval} / ${config.intervals}'
      : null;
  return switch (phase.type) {
    PhaseType.warmup => ('Get ready', null),
    PhaseType.work || PhaseType.rest => (round, interval),
    PhaseType.roundRest => (round, 'Complete'),
  };
}

/// "Next: Rest · 0:15", or "Last one!" when nothing follows.
String nextLabel(Phase? next) {
  if (next == null) return 'Last one!';
  final time = formatDuration(next.duration);
  final name = next.type == PhaseType.work && next.interval == 1
      ? 'Round ${next.round}'
      : next.type.label;
  return 'Next: $name · $time';
}

/// "12 intervals · 11:15".
String workoutSummary(WorkoutConfig config) {
  final count = config.rounds * config.intervals;
  return '$count ${count == 1 ? 'interval' : 'intervals'} · '
      '${formatDuration(config.total)}';
}
