import 'package:flutter_test/flutter_test.dart';
import 'package:spurtly/models/app_settings.dart';
import 'package:spurtly/models/presets.dart';
import 'package:spurtly/models/saved_workout.dart';
import 'package:spurtly/models/workout_config.dart';
import 'package:spurtly/services/workout_library.dart';
import 'package:spurtly/theme.dart';

void main() {
  group('presets', () {
    test('match the HIIT 1:1, HIIT 2:1 and Tabata formats', () {
      final byName = {for (final p in presetWorkouts) p.name: p.config};

      final oneToOne = byName['HIIT 1:1']!;
      expect(
        (oneToOne.work, oneToOne.rest),
        (const Duration(seconds: 30), const Duration(seconds: 30)),
      );
      final twoToOne = byName['HIIT 2:1']!;
      expect(
        (twoToOne.work, twoToOne.rest),
        (const Duration(seconds: 40), const Duration(seconds: 20)),
      );
      final tabata = byName['Tabata']!;
      expect(
        (tabata.work, tabata.rest, tabata.intervals),
        (const Duration(seconds: 20), const Duration(seconds: 10), 8),
      );

      expect(
        [for (final p in presetWorkouts) formatDuration(p.config.total)],
        ['18:00', '21:00', '20:20'],
      );
    });
  });

  group('WorkoutLibrary', () {
    late List<List<SavedWorkout>> savedWorkouts;
    late List<AppSettings> savedSettings;
    late List<WorkoutConfig> savedQuickConfigs;
    late WorkoutLibrary library;

    setUp(() {
      savedWorkouts = [];
      savedSettings = [];
      savedQuickConfigs = [];
      library = WorkoutLibrary(
        workouts: presetWorkouts,
        settings: const AppSettings(),
        onWorkoutsChanged: savedWorkouts.add,
        onSettingsChanged: savedSettings.add,
        onQuickConfigChanged: savedQuickConfigs.add,
      );
    });

    test('edits a workout in place and persists it', () {
      final tabata = library.byId('preset-tabata')!;
      library.save(tabata.copyWith(config: tabata.config.copyWith(rounds: 2)));

      expect(library.byId('preset-tabata')!.config.rounds, 2);
      expect(library.workouts.map((w) => w.id), [
        'preset-hiit-1-1',
        'preset-hiit-2-1',
        'preset-tabata',
      ]);
      expect(savedWorkouts, hasLength(1));
    });

    test('ignores saves that change nothing', () {
      library.save(library.byId('preset-tabata')!);
      expect(savedWorkouts, isEmpty);
    });

    test('creates workouts with unique names', () {
      final first = library.create();
      final second = library.create();

      expect(first.name, 'My workout');
      expect(second.name, 'My workout 2');
      expect(first.id, isNot(second.id));
      expect(library.workouts, hasLength(5));
    });

    test('duplicates a workout right after the original', () {
      final copy = library.duplicate('preset-tabata')!;
      final second = library.duplicate('preset-hiit-1-1')!;

      expect(copy.name, 'Tabata copy');
      expect(copy.config, presetFor('preset-tabata')!.config);
      expect(library.workouts.map((w) => w.name), [
        'HIIT 1:1',
        'HIIT 1:1 copy',
        'HIIT 2:1',
        'Tabata',
        'Tabata copy',
      ]);
      expect(second.id, isNot(copy.id));
      expect(library.duplicate('preset-tabata')!.name, 'Tabata copy 2');
    });

    test('undoes a delete by inserting at the old position', () {
      final hiit = library.byId('preset-hiit-2-1')!;
      final index = library.indexOf(hiit.id);
      library.delete(hiit.id);
      library.insert(hiit, index);

      expect(library.workouts, presetWorkouts);
    });

    test('deletes workouts, presets included', () {
      library.delete('preset-hiit-2-1');
      expect(library.byId('preset-hiit-2-1'), isNull);
      expect(library.workouts, hasLength(2));
    });

    test('restores an edited preset', () {
      final preset = library.byId('preset-hiit-1-1')!;
      library.save(
        preset.copyWith(
          name: 'Mine',
          config: preset.config.copyWith(work: const Duration(minutes: 1)),
        ),
      );
      library.restorePreset('preset-hiit-1-1');

      expect(library.byId('preset-hiit-1-1'), presetFor('preset-hiit-1-1'));
    });

    test('persists the free screen setup apart from the workouts', () {
      expect(library.quickConfig, WorkoutConfig.defaults);

      library.quickConfig = WorkoutConfig.defaults.copyWith(rounds: 5);
      library.quickConfig = WorkoutConfig.defaults.copyWith(rounds: 5);

      expect(library.quickConfig.rounds, 5);
      expect(savedQuickConfigs, hasLength(1));
      expect(savedWorkouts, isEmpty);
    });

    test('creates a workout from a given setup', () {
      final config = WorkoutConfig.defaults.copyWith(work: Duration.zero);
      expect(library.create(config: config).config, config);
    });

    test('persists settings changes', () {
      library.settings = library.settings.copyWith(vibration: false);
      expect(library.settings.vibration, isFalse);
      expect(savedSettings.single.vibration, isFalse);
    });
  });

  group('JSON', () {
    test('round-trips workouts and settings', () {
      for (final workout in presetWorkouts) {
        expect(SavedWorkout.fromJson(workout.toJson()), workout);
        expect(WorkoutConfig.fromJson(workout.config.toJson()), workout.config);
      }
      const settings = AppSettings(sounds: false, countdown: true);
      expect(AppSettings.fromJson(settings.toJson()), settings);
    });

    test('drops entries it cannot read and fills missing fields', () {
      expect(SavedWorkout.fromJson({'name': 'No id'}), isNull);
      expect(SavedWorkout.fromJson('garbage'), isNull);
      final partial = SavedWorkout.fromJson({
        'id': 'x',
        'config': {'work': 45},
      })!;
      expect(partial.name, 'Workout');
      expect(partial.config.work, const Duration(seconds: 45));
      expect(partial.config.rest, WorkoutConfig.defaults.rest);
    });
  });
}
