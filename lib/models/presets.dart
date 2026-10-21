import 'saved_workout.dart';
import 'workout_config.dart';

/// Workouts every user starts with. They can be edited like any other, and
/// restored to these values.
const presetWorkouts = [
  SavedWorkout(
    id: 'preset-hiit-1-1',
    name: 'HIIT 1:1',
    description:
        'Equal work and rest, e.g. 30\u00a0s / 30\u00a0s. Ideal for beginners and '
        'intermediates building fitness without extreme strain.',
    config: WorkoutConfig(
      warmup: Duration(minutes: 2),
      work: Duration(seconds: 30),
      rest: Duration(seconds: 30),
      intervals: 8,
      rounds: 2,
      roundRest: Duration(minutes: 1),
    ),
  ),
  SavedWorkout(
    id: 'preset-hiit-2-1',
    name: 'HIIT 2:1',
    description:
        'Twice as much work as rest, e.g. 40\u00a0s / 20\u00a0s. A tougher variant '
        'for fitter athletes.',
    config: WorkoutConfig(
      warmup: Duration(minutes: 2),
      work: Duration(seconds: 40),
      rest: Duration(seconds: 20),
      intervals: 6,
      rounds: 3,
      roundRest: Duration(minutes: 1),
    ),
  ),
  SavedWorkout(
    id: 'preset-tabata',
    name: 'Tabata',
    description:
        '20\u00a0s all-out effort / 10\u00a0s rest, 8 times: a 4\u2011minute block. '
        'Four blocks with a minute of rest in between.',
    config: WorkoutConfig(
      warmup: Duration(minutes: 2),
      work: Duration(seconds: 20),
      rest: Duration(seconds: 10),
      intervals: 8,
      rounds: 4,
      roundRest: Duration(minutes: 1),
    ),
  ),
];

/// The preset [id] was created from, if any.
SavedWorkout? presetFor(String id) {
  for (final preset in presetWorkouts) {
    if (preset.id == id) return preset;
  }
  return null;
}
