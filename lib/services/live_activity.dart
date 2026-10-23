import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../timer/phase_text.dart';
import '../timer/workout_timer.dart';
import '../theme.dart';

/// What the Live Activity shows; mirrors `SpurtlyActivityAttributes.
/// ContentState` in `ios/Shared/SpurtlyActivity.swift`.
@immutable
class LiveActivityState {
  const LiveActivityState({
    required this.phase,
    required this.label,
    required this.position,
    required this.next,
    required this.phaseStart,
    required this.phaseEnd,
    this.pausedRemaining,
  });

  /// The current state of [timer]. The activity counts down by itself from
  /// [phaseStart] to [phaseEnd], so it only needs updating when the phase
  /// or the paused state changes.
  factory LiveActivityState.of(WorkoutTimer timer, DateTime now) {
    final phase = timer.phase;
    if (phase == null) {
      return LiveActivityState(
        phase: 'done',
        label: 'Workout complete',
        position: workoutSummary(timer.config, timer.activeTime),
        next: '',
        phaseStart: now,
        phaseEnd: now,
      );
    }
    final remaining = timer.phaseRemaining;
    final (title, subtitle) = phasePosition(phase, timer.config);
    return LiveActivityState(
      phase: phase.type.name,
      label: phase.type.label,
      position: [title, ?subtitle].join(' · '),
      next: nextLabel(timer.nextPhase),
      phaseStart: now.subtract(phase.duration - remaining),
      phaseEnd: now.add(remaining),
      pausedRemaining: timer.isRunning ? null : remaining,
    );
  }

  final String phase;
  final String label;
  final String position;
  final String next;
  final DateTime phaseStart;
  final DateTime phaseEnd;
  final Duration? pausedRemaining;

  Map<String, Object?> toMap() => {
    'phase': phase,
    'label': label,
    'position': position,
    'next': next,
    'phaseStartMs': phaseStart.millisecondsSinceEpoch.toDouble(),
    'phaseEndMs': phaseEnd.millisecondsSinceEpoch.toDouble(),
    'pausedRemaining': switch (pausedRemaining) {
      final remaining? => remaining.inMilliseconds / 1000,
      null => null,
    },
  };
}

/// Buttons on the Live Activity.
enum LiveActivityControl { togglePause, skip }

/// The running workout outside the app, counting down by itself: a Live
/// Activity on the iOS lock screen and in the Dynamic Island, or on Android
/// the notification of a foreground service that keeps the app and its
/// sounds going while the screen is off.
abstract interface class LiveActivity {
  /// Shows the activity, with pause/resume and skip buttons if [controls];
  /// returns `false` where it is not available (iOS before 17, Live
  /// Activities turned off, or the service could not start).
  Future<bool> start(LiveActivityState state, {bool controls = true});

  Future<void> update(LiveActivityState state);

  /// Ends the activity, optionally leaving [finalState] on the lock screen
  /// for [dismissAfter].
  Future<void> end({LiveActivityState? finalState, Duration? dismissAfter});

  /// Called when a button on the activity is tapped.
  set onControl(ValueChanged<LiveActivityControl>? handler);
}

class PlatformLiveActivity implements LiveActivity {
  PlatformLiveActivity() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'control') return;
      final control = LiveActivityControl.values.asNameMap()[call.arguments];
      if (control != null) _onControl?.call(control);
    });
  }

  static const _channel = MethodChannel('spurtly/live_activity');
  ValueChanged<LiveActivityControl>? _onControl;

  @override
  set onControl(ValueChanged<LiveActivityControl>? handler) =>
      _onControl = handler;

  @override
  Future<bool> start(LiveActivityState state, {bool controls = true}) async {
    try {
      return await _channel.invokeMethod<bool>('start', {
            'state': state.toMap(),
            'controls': controls,
          }) ??
          false;
    } on MissingPluginException {
      return false; // Not on iOS or Android.
    } catch (error) {
      debugPrint('Live Activity not started: $error');
      return false;
    }
  }

  @override
  Future<void> update(LiveActivityState state) =>
      _call('update', {'state': state.toMap()});

  @override
  Future<void> end({LiveActivityState? finalState, Duration? dismissAfter}) =>
      _call('end', {
        'state': finalState?.toMap(),
        'dismissAfterSeconds': dismissAfter?.inSeconds.toDouble(),
      });

  Future<void> _call(String method, Map<String, Object?> arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Not on iOS or Android.
    } catch (error) {
      debugPrint('Live Activity $method failed: $error');
    }
  }
}
