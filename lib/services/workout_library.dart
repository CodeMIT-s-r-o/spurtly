import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/presets.dart';
import '../models/saved_workout.dart';
import '../models/workout_config.dart';

/// The user's saved workouts and settings. Every change is handed to
/// [onWorkoutsChanged] / [onSettingsChanged] to be persisted.
class WorkoutLibrary extends ChangeNotifier {
  WorkoutLibrary({
    required List<SavedWorkout> workouts,
    required this._settings,
    this.onWorkoutsChanged,
    this.onSettingsChanged,
  }) : _workouts = List.of(workouts);

  final ValueChanged<List<SavedWorkout>>? onWorkoutsChanged;
  final ValueChanged<AppSettings>? onSettingsChanged;

  final List<SavedWorkout> _workouts;
  AppSettings _settings;

  List<SavedWorkout> get workouts => List.unmodifiable(_workouts);
  AppSettings get settings => _settings;

  SavedWorkout? byId(String id) {
    for (final workout in _workouts) {
      if (workout.id == id) return workout;
    }
    return null;
  }

  /// Replaces the workout with the same id, or adds it at the end.
  void save(SavedWorkout workout) {
    final index = _workouts.indexWhere((w) => w.id == workout.id);
    if (index == -1) {
      _workouts.add(workout);
    } else if (_workouts[index] == workout) {
      return;
    } else {
      _workouts[index] = workout;
    }
    _workoutsChanged();
  }

  void delete(String id) {
    _workouts.removeWhere((w) => w.id == id);
    _workoutsChanged();
  }

  /// Adds a workout with default values and a name not used yet.
  SavedWorkout create() {
    final workout = SavedWorkout(
      id: _newId(),
      name: _unusedName('My workout'),
      config: WorkoutConfig.defaults,
    );
    save(workout);
    return workout;
  }

  /// Inserts a copy of workout [id] right after it, named "… copy".
  SavedWorkout? duplicate(String id) {
    final index = _workouts.indexWhere((w) => w.id == id);
    if (index == -1) return null;
    final original = _workouts[index];
    final copy = SavedWorkout(
      id: _newId(),
      name: _unusedName('${original.name} copy'),
      description: original.description,
      config: original.config,
    );
    insert(copy, index + 1);
    return copy;
  }

  /// Puts [workout] at [index], e.g. to undo a delete.
  void insert(SavedWorkout workout, int index) {
    _workouts
      ..removeWhere((w) => w.id == workout.id)
      ..insert(index.clamp(0, _workouts.length), workout);
    _workoutsChanged();
  }

  int indexOf(String id) => _workouts.indexWhere((w) => w.id == id);

  String _unusedName(String base) {
    final names = {for (final w in _workouts) w.name};
    var name = base;
    for (var n = 2; names.contains(name); n++) {
      name = '$base $n';
    }
    return name;
  }

  int _idCounter = 0;

  String _newId() =>
      'workout-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  /// Puts a preset back to how it shipped; does nothing for other workouts.
  void restorePreset(String id) {
    final preset = presetFor(id);
    if (preset != null) save(preset);
  }

  set settings(AppSettings settings) {
    if (settings == _settings) return;
    _settings = settings;
    onSettingsChanged?.call(settings);
    notifyListeners();
  }

  void _workoutsChanged() {
    onWorkoutsChanged?.call(workouts);
    notifyListeners();
  }
}

/// Keeps the library in shared preferences as JSON.
class LibraryStore {
  LibraryStore() : _prefs = SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _workoutsKey = 'workouts_v1';
  static const _settingsKey = 'settings_v1';

  /// The saved library; the presets when nothing has been saved yet.
  Future<WorkoutLibrary> load() async {
    var workouts = presetWorkouts;
    var settings = const AppSettings();
    try {
      final storedWorkouts = await _prefs.getString(_workoutsKey);
      if (storedWorkouts != null) {
        workouts = [
          for (final entry in jsonDecode(storedWorkouts) as List<Object?>)
            ?SavedWorkout.fromJson(entry),
        ];
      }
      final storedSettings = await _prefs.getString(_settingsKey);
      if (storedSettings != null) {
        settings = AppSettings.fromJson(jsonDecode(storedSettings));
      }
    } catch (error) {
      debugPrint('Could not load the workout library: $error');
    }
    return WorkoutLibrary(
      workouts: workouts,
      settings: settings,
      onWorkoutsChanged: _saveWorkouts,
      onSettingsChanged: _saveSettings,
    );
  }

  Future<void> _saveWorkouts(List<SavedWorkout> workouts) =>
      _write(_workoutsKey, jsonEncode([for (final w in workouts) w.toJson()]));

  Future<void> _saveSettings(AppSettings settings) =>
      _write(_settingsKey, jsonEncode(settings.toJson()));

  Future<void> _write(String key, String value) async {
    try {
      await _prefs.setString(key, value);
    } catch (error) {
      debugPrint('Could not save $key: $error');
    }
  }
}
