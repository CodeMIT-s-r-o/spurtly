import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_config.dart';

/// Remembers the last workout setup between launches.
class ConfigStore {
  ConfigStore() : _prefs = SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _warmupKey = 'warmup_seconds';
  static const _workKey = 'work_seconds';
  static const _restKey = 'rest_seconds';
  static const _intervalsKey = 'intervals';
  static const _roundsKey = 'rounds';
  static const _roundRestKey = 'round_rest_seconds';

  Future<WorkoutConfig> load() async {
    const d = WorkoutConfig.defaults;
    try {
      final values = await _prefs.getAll(
        allowList: {
          _warmupKey,
          _workKey,
          _restKey,
          _intervalsKey,
          _roundsKey,
          _roundRestKey,
        },
      );
      int? integer(String key) => switch (values[key]) {
        final int value => value,
        _ => null,
      };
      Duration seconds(String key, Duration fallback) {
        final value = integer(key);
        return value == null ? fallback : Duration(seconds: value);
      }

      return WorkoutConfig(
        warmup: seconds(_warmupKey, d.warmup),
        work: seconds(_workKey, d.work),
        rest: seconds(_restKey, d.rest),
        intervals: integer(_intervalsKey) ?? d.intervals,
        rounds: integer(_roundsKey) ?? d.rounds,
        roundRest: seconds(_roundRestKey, d.roundRest),
      );
    } catch (error) {
      debugPrint('Could not load settings: $error');
      return d;
    }
  }

  Future<void> save(WorkoutConfig config) async {
    try {
      await Future.wait([
        _prefs.setInt(_warmupKey, config.warmup.inSeconds),
        _prefs.setInt(_workKey, config.work.inSeconds),
        _prefs.setInt(_restKey, config.rest.inSeconds),
        _prefs.setInt(_intervalsKey, config.intervals),
        _prefs.setInt(_roundsKey, config.rounds),
        _prefs.setInt(_roundRestKey, config.roundRest.inSeconds),
      ]);
    } catch (error) {
      debugPrint('Could not save settings: $error');
    }
  }
}
