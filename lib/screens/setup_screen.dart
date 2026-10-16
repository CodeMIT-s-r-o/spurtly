import 'package:flutter/material.dart';

import '../models/phase.dart';
import '../models/workout_config.dart';
import '../services/live_activity.dart';
import '../services/sounds.dart';
import '../services/workout_notifications.dart';
import '../theme.dart';
import '../widgets/stepper_row.dart';
import 'timer_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.initialConfig,
    required this.onConfigChanged,
    required this.sounds,
    required this.notifications,
    required this.liveActivity,
  });

  final WorkoutConfig initialConfig;
  final ValueChanged<WorkoutConfig> onConfigChanged;
  final Sounds sounds;
  final WorkoutNotifications notifications;
  final LiveActivity liveActivity;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const _maxDuration = Duration(minutes: 10);
  static const _minWork = Duration(seconds: 5);
  static const _maxIntervals = 20;
  static const _maxRounds = 50;

  late WorkoutConfig _config = widget.initialConfig;

  void _update(WorkoutConfig config) {
    setState(() => _config = config);
    widget.onConfigChanged(config);
  }

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
          ? () => _update(apply(_clamp(_stepDown(value), min)))
          : null,
      onIncrement: value < _maxDuration
          ? () => _update(apply(_clamp(_stepUp(value), min)))
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
      onDecrement: value > 1 ? () => _update(apply(value - 1)) : null,
      onIncrement: value < max ? () => _update(apply(value + 1)) : null,
    );
  }

  Future<void> _start() async {
    // Asked here, before the timer runs, so the system prompt only ever
    // interrupts the setup screen.
    await widget.notifications.requestPermission();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TimerScreen(
          config: _config,
          sounds: widget.sounds,
          notifications: widget.notifications,
          liveActivity: widget.liveActivity,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const gap = SizedBox(height: 8);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 56,
                          height: 56,
                          excludeFromSemantics: true,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spurtly',
                            style: text.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Interval timer',
                            style: text.bodyMedium?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const _SectionHeader('Before you start'),
                  _durationRow(
                    type: PhaseType.warmup,
                    icon: Icons.directions_walk,
                    value: _config.warmup,
                    min: Duration.zero,
                    apply: (d) => _config.copyWith(warmup: d),
                  ),
                  const _SectionHeader('Each interval'),
                  _durationRow(
                    type: PhaseType.work,
                    icon: Icons.local_fire_department,
                    value: _config.work,
                    min: _minWork,
                    apply: (d) => _config.copyWith(work: d),
                  ),
                  gap,
                  _durationRow(
                    type: PhaseType.rest,
                    icon: Icons.self_improvement,
                    value: _config.rest,
                    min: Duration.zero,
                    apply: (d) => _config.copyWith(rest: d),
                  ),
                  const _SectionHeader('Rounds'),
                  _countRow(
                    icon: Icons.format_list_numbered,
                    label: 'Intervals per round',
                    value: _config.intervals,
                    max: _maxIntervals,
                    apply: (n) => _config.copyWith(intervals: n),
                  ),
                  gap,
                  _countRow(
                    icon: Icons.repeat,
                    label: 'Rounds',
                    value: _config.rounds,
                    max: _maxRounds,
                    apply: (n) => _config.copyWith(rounds: n),
                  ),
                  gap,
                  _durationRow(
                    type: PhaseType.roundRest,
                    icon: Icons.hourglass_bottom,
                    value: _config.roundRest,
                    min: Duration.zero,
                    enabled: _config.rounds > 1,
                    apply: (d) => _config.copyWith(roundRest: d),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'Total  ',
                      style: const TextStyle(color: AppColors.muted),
                      children: [
                        TextSpan(
                          text: formatDuration(_config.total),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontFeatures: tabularFigures,
                          ),
                        ),
                      ],
                    ),
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.play_arrow_rounded, size: 32),
                    label: const Text('Start'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                      textStyle: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.muted,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
