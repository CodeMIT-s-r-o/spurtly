import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/phase.dart';
import '../models/workout_config.dart';

typedef Clock = Duration Function();

/// Wall-clock time, which keeps advancing while the device sleeps.
Duration wallClock() =>
    Duration(microseconds: DateTime.now().microsecondsSinceEpoch);

/// Drives a workout through its phases.
///
/// Elapsed time is read from [Clock] instead of being counted in ticks, so
/// the timer stays correct when ticks arrive late or the app was suspended.
/// Listeners are notified when the phase, the displayed second or the
/// paused state changes.
class WorkoutTimer extends ChangeNotifier {
  WorkoutTimer(
    this.config, {
    this.onPhaseChanged,
    this.onCountdown,
    this._clock = wallClock,
    this.tickInterval = const Duration(milliseconds: 100),
  }) : phases = config.phases {
    var end = Duration.zero;
    _phaseEnds = [for (final phase in phases) end += phase.duration];
  }

  final WorkoutConfig config;
  final List<Phase> phases;

  /// Called when a phase begins, with `null` once the workout is finished.
  /// Phases skipped over in a single tick are not reported.
  final void Function(Phase? phase)? onPhaseChanged;

  /// Called with 3, 2 and 1 as the last seconds of a running phase begin.
  final void Function(int secondsLeft)? onCountdown;

  final Duration tickInterval;
  final Clock _clock;
  late final List<Duration> _phaseEnds;

  /// Elapsed time accumulated up to the last pause or skip.
  Duration _banked = Duration.zero;

  /// Phase time jumped over with [skip], which [activeTime] leaves out.
  Duration _skipped = Duration.zero;
  Duration? _runningSince;
  int _index = 0;
  int _shownSecond = -1;
  bool _started = false;
  Timer? _ticker;

  bool get isStarted => _started;
  bool get isRunning => _runningSince != null;
  bool get isFinished => _index >= phases.length;
  Phase? get phase => isFinished ? null : phases[_index];
  Phase? get nextPhase =>
      _index + 1 < phases.length ? phases[_index + 1] : null;

  Duration get elapsed {
    final since = _runningSince;
    return since == null ? _banked : _banked + (_clock() - since);
  }

  Duration get phaseRemaining =>
      isFinished ? Duration.zero : _nonNegative(_phaseEnds[_index] - elapsed);

  /// Whole seconds left in the phase, rounded up: a 30 s phase shows 30
  /// right after it starts and 1 during its last second.
  int get phaseSecondsLeft => (phaseRemaining.inMicroseconds / 1e6).ceil();

  /// 0 at the start of the phase, 1 at its end.
  double get phaseProgress {
    if (isFinished) return 1;
    final start = _index == 0 ? Duration.zero : _phaseEnds[_index - 1];
    final done = (elapsed - start).inMicroseconds;
    return (done / phases[_index].duration.inMicroseconds).clamp(0.0, 1.0);
  }

  Duration get totalRemaining =>
      isFinished ? Duration.zero : _nonNegative(_phaseEnds.last - elapsed);

  /// Time actually spent working out: [elapsed] without pauses or skipped
  /// phase time.
  Duration get activeTime => elapsed - _skipped;

  /// Whole seconds left in the workout, rounded up like [phaseSecondsLeft].
  int get totalSecondsLeft => (totalRemaining.inMicroseconds / 1e6).ceil();

  void start() {
    if (_started) return;
    _started = true;
    _run();
    onPhaseChanged?.call(phase);
    _notify();
  }

  void pause() {
    if (!isRunning) return;
    _banked = elapsed;
    _halt();
    _notify();
  }

  void resume() {
    if (!_started || isRunning || isFinished) return;
    _run();
    _notify();
  }

  void togglePause() => isRunning ? pause() : resume();

  /// Jumps to the start of the next phase, keeping the paused state.
  void skip() {
    if (!_started || isFinished) return;
    _skipped += _phaseEnds[_index] - elapsed;
    _banked = _phaseEnds[_index];
    if (isRunning) _runningSince = _clock();
    tick();
  }

  /// Advances to whichever phase [elapsed] falls into. Called periodically
  /// while running; safe to call at any time.
  void tick() {
    final now = elapsed;
    final previous = _index;
    while (_index < phases.length && now >= _phaseEnds[_index]) {
      _index++;
    }
    if (_index != previous) {
      if (isFinished) {
        _banked = _phaseEnds.last;
        _halt();
      }
      onPhaseChanged?.call(phase);
      _notify();
    } else if (phaseSecondsLeft != _shownSecond) {
      final left = phaseSecondsLeft;
      if (isRunning && left <= 3 && left >= 1 && left < _shownSecond) {
        onCountdown?.call(left);
      }
      _notify();
    }
  }

  void _run() {
    _runningSince = _clock();
    _ticker = Timer.periodic(tickInterval, (_) => tick());
  }

  void _halt() {
    _runningSince = null;
    _ticker?.cancel();
    _ticker = null;
  }

  void _notify() {
    _shownSecond = phaseSecondsLeft;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static Duration _nonNegative(Duration d) => d.isNegative ? Duration.zero : d;
}
