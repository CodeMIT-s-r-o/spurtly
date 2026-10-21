import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../models/phase.dart';
import '../models/saved_workout.dart';
import '../models/workout_config.dart';
import '../services/app_services.dart';
import '../services/workout_library.dart';
import '../theme.dart';
import '../widgets/section_header.dart';
import 'settings_sheet.dart';
import 'start_workout.dart';
import 'workout_screen.dart';

/// The saved workouts: tap one to edit it, or its play button to start.
/// Swipe right to duplicate a workout, left to delete it.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.library, required this.services});

  final WorkoutLibrary library;
  final AppServices services;

  /// Deletes without asking; the snack bar offers to undo instead.
  void _delete(BuildContext context, SavedWorkout workout) {
    final index = library.indexOf(workout.id);
    library.delete(workout.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted “${workout.name}”'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => library.insert(workout, index),
          ),
        ),
      );
  }

  void _duplicate(SavedWorkout workout) {
    library.duplicate(workout.id);
    HapticFeedback.mediumImpact();
  }

  void _open(BuildContext context, SavedWorkout workout) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutScreen(
          workoutId: workout.id,
          library: library,
          services: services,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: library,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                  Expanded(
                    child: Column(
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
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune_rounded),
                    tooltip: 'Settings',
                    onPressed: () => showSettingsSheet(context, library),
                  ),
                ],
              ),
              const SectionHeader('Your workouts'),
              for (final workout in library.workouts) ...[
                _Swipeable(
                  key: ValueKey(workout.id),
                  onDuplicate: () => _duplicate(workout),
                  onDelete: () => _delete(context, workout),
                  child: _WorkoutCard(
                    workout: workout,
                    onOpen: () => _open(context, workout),
                    onStart: () => startWorkout(
                      context,
                      workout: workout,
                      library: library,
                      services: services,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => _open(context, library.create()),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New workout'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.stepper, width: 1.5),
                  textStyle: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (library.workouts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    'Swipe a workout right to duplicate it, left to delete it.',
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.workout,
    required this.onOpen,
    required this.onStart,
  });

  final SavedWorkout workout;
  final VoidCallback onOpen;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final config = workout.config;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (workout.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        workout.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _RatioStrip(config: config),
                    const SizedBox(height: 8),
                    Text(
                      _summary(config),
                      style: text.labelLarge?.copyWith(
                        color: AppColors.muted,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: onStart,
                iconSize: 30,
                style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
                icon: Icon(
                  Icons.play_arrow_rounded,
                  semanticLabel: 'Start ${workout.name}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "0:30 / 0:15 · 4 × 3 · 11:15"
  static String _summary(WorkoutConfig config) {
    final rest = config.rest == Duration.zero
        ? 'no rest'
        : formatDuration(config.rest);
    return '${formatDuration(config.work)} / $rest · '
        '${config.intervals} × ${config.rounds} · '
        '${formatDuration(config.total)}';
  }
}

/// One interval at a glance: work (coral) and rest (teal) to scale, like the
/// dashes and dots of the logo.
class _RatioStrip extends StatelessWidget {
  const _RatioStrip({required this.config});

  final WorkoutConfig config;

  @override
  Widget build(BuildContext context) {
    final work = config.work.inSeconds;
    final rest = config.rest.inSeconds;
    Widget bar(int flex, Color color) => Expanded(
      flex: flex,
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
    return Row(
      children: [
        bar(work, AppColors.coral),
        if (rest > 0) ...[const SizedBox(width: 4), bar(rest, AppColors.teal)],
      ],
    );
  }
}

/// Swipe right to duplicate (the card springs back), left to delete.
/// Screen readers get the same two actions.
class _Swipeable extends StatelessWidget {
  const _Swipeable({
    super.key,
    required this.onDuplicate,
    required this.onDelete,
    required this.child,
  });

  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Duplicate'): onDuplicate,
        const CustomSemanticsAction(label: 'Delete'): onDelete,
      },
      child: Dismissible(
        key: key!,
        background: const _SwipeBackground(
          color: AppColors.done,
          icon: Icons.copy_rounded,
          label: 'Duplicate',
          alignment: Alignment.centerLeft,
        ),
        secondaryBackground: _SwipeBackground(
          color: PhaseType.work.background,
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          alignment: Alignment.centerRight,
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            onDuplicate();
            return false;
          }
          return true;
        },
        onDismissed: (_) => onDelete(),
        child: child,
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final children = [
      Icon(icon, color: Colors.white),
      const SizedBox(width: 8),
      Text(
        label,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    ];
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignment == Alignment.centerLeft
            ? children
            : children.reversed.toList(),
      ),
    );
  }
}
