import 'package:flutter/material.dart';

import '../services/workout_library.dart';
import '../theme.dart';

/// Turns the timer's sounds, countdown and vibration on or off.
Future<void> showSettingsSheet(BuildContext context, WorkoutLibrary library) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListenableBuilder(
        listenable: library,
        builder: (context, _) {
          final settings = library.settings;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  'Signals',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              SwitchListTile(
                title: const Text('Sounds'),
                subtitle: const Text(
                  'Chimes when work and rest start, and at the finish',
                ),
                value: settings.sounds,
                onChanged: (on) =>
                    library.settings = settings.copyWith(sounds: on),
              ),
              SwitchListTile(
                title: const Text('3-2-1 countdown'),
                subtitle: const Text(
                  'Pips in the last 3 seconds of each phase',
                ),
                value: settings.countdown,
                onChanged: (on) =>
                    library.settings = settings.copyWith(countdown: on),
              ),
              SwitchListTile(
                title: const Text('Vibration'),
                subtitle: const Text(
                  'A tap when the phase changes, while the app is open',
                ),
                value: settings.vibration,
                onChanged: (on) =>
                    library.settings = settings.copyWith(vibration: on),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    ),
  );
}
