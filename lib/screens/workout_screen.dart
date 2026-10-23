import 'package:flutter/material.dart';

import '../models/presets.dart';
import '../models/saved_workout.dart';
import '../models/workout_config.dart';
import '../services/app_services.dart';
import '../services/workout_library.dart';
import '../theme.dart';
import '../widgets/readable_width.dart';
import '../widgets/workout_form.dart';
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

  void _update(WorkoutConfig config) =>
      library.save(workout.copyWith(config: config));

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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ReadableWidth(
              child: Padding(
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
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final side = readableInset(constraints.maxWidth);
                  return ListView(
                    // Full width, so the margins of a tablet scroll it too.
                    padding: EdgeInsets.fromLTRB(side, 0, side, 16),
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
                      WorkoutConfigForm(
                        config: workout.config,
                        onChanged: _update,
                      ),
                    ],
                  );
                },
              ),
            ),
            ReadableWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  children: [
                    WorkoutTotal(workout.config),
                    const SizedBox(height: 12),
                    StartButton(
                      onPressed: () => startWorkout(
                        context,
                        config: workout.config,
                        name: workout.name,
                        library: library,
                        services: services,
                      ),
                    ),
                  ],
                ),
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
