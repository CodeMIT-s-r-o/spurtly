import 'package:flutter/material.dart';

import '../models/phase.dart';
import '../models/workout_config.dart';
import '../theme.dart';
import 'section_header.dart';
import 'stepper_row.dart';

/// The −/+ rows for every part of a workout: warm-up, work, rest,
/// intervals, rounds and the rest between rounds.
class WorkoutConfigForm extends StatelessWidget {
  const WorkoutConfigForm({
    super.key,
    required this.config,
    required this.onChanged,
  });

  final WorkoutConfig config;
  final ValueChanged<WorkoutConfig> onChanged;

  static const _maxDuration = Duration(minutes: 10);
  static const _minWork = Duration(seconds: 5);
  static const _maxIntervals = 20;
  static const _maxRounds = 50;

  /// 5 s steps up to a minute, 15 s steps above.
  static Duration _stepUp(Duration d) =>
      d + Duration(seconds: d < const Duration(minutes: 1) ? 5 : 15);
  static Duration _stepDown(Duration d) =>
      d - Duration(seconds: d <= const Duration(minutes: 1) ? 5 : 15);

  static Duration _clamp(Duration d, Duration min) =>
      d < min ? min : (d > _maxDuration ? _maxDuration : d);

  Widget _durationRow({
    required PhaseType type,
    required IconData icon,
    required Duration value,
    required Duration min,
    required WorkoutConfig Function(Duration) apply,
    bool enabled = true,
  }) {
    return StepperRow(
      icon: icon,
      accent: type.accent,
      label: type.label,
      value: value == Duration.zero ? 'Off' : formatDuration(value),
      enabled: enabled,
      onDecrement: value > min
          ? () => onChanged(apply(_clamp(_stepDown(value), min)))
          : null,
      onIncrement: value < _maxDuration
          ? () => onChanged(apply(_clamp(_stepUp(value), min)))
          : null,
    );
  }

  Widget _countRow({
    required IconData icon,
    required String label,
    required int value,
    required int max,
    required WorkoutConfig Function(int) apply,
  }) {
    return StepperRow(
      icon: icon,
      accent: AppColors.indigo,
      label: label,
      value: '$value',
      onDecrement: value > 1 ? () => onChanged(apply(value - 1)) : null,
      onIncrement: value < max ? () => onChanged(apply(value + 1)) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Before you start'),
        _durationRow(
          type: PhaseType.warmup,
          icon: Icons.directions_walk,
          value: config.warmup,
          min: Duration.zero,
          apply: (d) => config.copyWith(warmup: d),
        ),
        const SectionHeader('Each interval'),
        _durationRow(
          type: PhaseType.work,
          icon: Icons.local_fire_department,
          value: config.work,
          min: _minWork,
          apply: (d) => config.copyWith(work: d),
        ),
        gap,
        _durationRow(
          type: PhaseType.rest,
          icon: Icons.self_improvement,
          value: config.rest,
          min: Duration.zero,
          apply: (d) => config.copyWith(rest: d),
        ),
        const SectionHeader('Rounds'),
        _countRow(
          icon: Icons.format_list_numbered,
          label: 'Intervals per round',
          value: config.intervals,
          max: _maxIntervals,
          apply: (n) => config.copyWith(intervals: n),
        ),
        gap,
        _countRow(
          icon: Icons.repeat,
          label: 'Rounds',
          value: config.rounds,
          max: _maxRounds,
          apply: (n) => config.copyWith(rounds: n),
        ),
        gap,
        _durationRow(
          type: PhaseType.roundRest,
          icon: Icons.hourglass_bottom,
          value: config.roundRest,
          min: Duration.zero,
          enabled: config.rounds > 1,
          apply: (d) => config.copyWith(roundRest: d),
        ),
      ],
    );
  }
}

/// "Total  14:00"
class WorkoutTotal extends StatelessWidget {
  const WorkoutTotal(this.config, {super.key});

  final WorkoutConfig config;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: 'Total  ',
        style: const TextStyle(color: AppColors.muted),
        children: [
          TextSpan(
            text: formatDuration(config.total),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class StartButton extends StatelessWidget {
  const StartButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.play_arrow_rounded, size: 32),
      label: const Text('Start'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(64),
        textStyle: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
