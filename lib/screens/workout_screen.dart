import 'package:flutter/material.dart';

import '../models/phase.dart';
import '../models/presets.dart';
import '../models/saved_workout.dart';
import '../models/workout_config.dart';
import '../services/app_services.dart';
import '../services/workout_library.dart';
import '../theme.dart';
import '../widgets/section_header.dart';
import '../widgets/stepper_row.dart';
import 'start_workout.dart';

/// Edits one saved workout; every change is saved right away.
class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({
    super.key,
    required this.workoutId,
    required this.library,
    required this.services,
  });

  final String workoutId;
  final WorkoutLibrary library;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final workout = library.byId(workoutId);
        // Briefly null while the screen closes after a delete.
        if (workout == null) return const Scaffold();
        return _WorkoutEditor(
          workout: workout,
          library: library,
          services: services,
        );
      },
    );
  }
}

enum _MenuAction { rename, restore, delete }

class _WorkoutEditor extends StatelessWidget {
  const _WorkoutEditor({
    required this.workout,
    required this.library,
    required this.services,
  });

  final SavedWorkout workout;
  final WorkoutLibrary library;
  final AppServices services;

  static const _maxDuration = Duration(minutes: 10);
  static const _minWork = Duration(seconds: 5);
  static const _maxIntervals = 20;
  static const _maxRounds = 50;

  WorkoutConfig get _config => workout.config;

  void _update(WorkoutConfig config) =>
      library.save(workout.copyWith(config: config));

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

  Future<void> _rename(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initialName: workout.name),
    );
    if (name != null) library.save(workout.copyWith(name: name));
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete “${workout.name}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !context.mounted) return;
    Navigator.of(context).pop();
    library.delete(workout.id);
  }

  void _onMenu(BuildContext context, _MenuAction action) {
    switch (action) {
      case _MenuAction.rename:
        _rename(context);
      case _MenuAction.restore:
        library.restorePreset(workout.id);
      case _MenuAction.delete:
        _delete(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final preset = presetFor(workout.id);
    const gap = SizedBox(height: 8);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  const BackButton(),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _rename(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Text(
                          workout.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<_MenuAction>(
                    tooltip: 'More',
                    onSelected: (action) => _onMenu(context, action),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: _MenuAction.rename,
                        child: Text('Rename'),
                      ),
                      if (preset != null)
                        PopupMenuItem(
                          value: _MenuAction.restore,
                          enabled: preset != workout,
                          child: const Text('Restore defaults'),
                        ),
                      const PopupMenuItem(
                        value: _MenuAction.delete,
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  if (workout.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, right: 4),
                      child: Text(
                        workout.description,
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  const SectionHeader('Before you start'),
                  _durationRow(
                    type: PhaseType.warmup,
                    icon: Icons.directions_walk,
                    value: _config.warmup,
                    min: Duration.zero,
                    apply: (d) => _config.copyWith(warmup: d),
                  ),
                  const SectionHeader('Each interval'),
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
                  const SectionHeader('Rounds'),
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
                    onPressed: () => startWorkout(
                      context,
                      workout: workout,
                      library: library,
                      services: services,
                    ),
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

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initialName)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialName.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename workout'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 30,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
