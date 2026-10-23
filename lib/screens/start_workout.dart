import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/workout_config.dart';
import '../services/app_services.dart';
import '../services/workout_library.dart';
import 'timer_screen.dart';

/// Opens the timer for [config]. Saved workouts pass their [name]; the free
/// screen has none.
Future<void> startWorkout(
  BuildContext context, {
  required WorkoutConfig config,
  String? name,
  required WorkoutLibrary library,
  required AppServices services,
}) async {
  // Asked here, before the timer runs, so the system prompt never
  // interrupts a workout.
  await services.notifications.requestPermission();
  if (!context.mounted) return;
  // Signal settings are a Pro feature; the free screen only has the sound
  // switch.
  final settings = services.pro.unlocked
      ? library.settings
      : AppSettings(sounds: library.settings.sounds);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TimerScreen(
        config: config,
        name: name,
        settings: settings,
        services: services,
      ),
    ),
  );
}
