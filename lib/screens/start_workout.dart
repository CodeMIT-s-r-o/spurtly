import 'package:flutter/material.dart';

import '../models/saved_workout.dart';
import '../services/app_services.dart';
import '../services/workout_library.dart';
import 'timer_screen.dart';

/// Opens the timer for [workout] with the current settings.
Future<void> startWorkout(
  BuildContext context, {
  required SavedWorkout workout,
  required WorkoutLibrary library,
  required AppServices services,
}) async {
  // Asked here, before the timer runs, so the system prompt never
  // interrupts a workout.
  await services.notifications.requestPermission();
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TimerScreen(
        workout: workout,
        settings: library.settings,
        services: services,
      ),
    ),
  );
}
