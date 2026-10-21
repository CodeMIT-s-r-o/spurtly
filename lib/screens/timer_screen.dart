import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/app_settings.dart';
import '../models/phase.dart';
import '../models/saved_workout.dart';
import '../models/workout_config.dart';
import '../services/app_services.dart';
import '../services/live_activity.dart';
import '../services/sounds.dart';
import '../theme.dart';
import '../timer/phase_text.dart';
import '../timer/workout_timer.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({
    super.key,
    required this.workout,
    required this.settings,
    required this.services,
  });

  final SavedWorkout workout;
  final AppSettings settings;
  final AppServices services;

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with SingleTickerProviderStateMixin {
  late final WorkoutTimer _timer = WorkoutTimer(
    _config,
    onPhaseChanged: _onPhaseChanged,
    onCountdown: _onCountdown,
  );

  WorkoutConfig get _config => widget.workout.config;
  AppServices get _services => widget.services;

  /// Bumped every frame while running so the ring sweeps smoothly; the rest
  /// of the screen only rebuilds when the timer notifies.
  final _frame = ValueNotifier<int>(0);
  late final Ticker _frames = createTicker((_) => _frame.value++);

  /// Without a Live Activity, the lock screen shows the current phase as a
  /// notification while the app is in the background; it goes away once the
  /// app is back.
  late final AppLifecycleListener _lifecycle;

  bool _keepingAlive = false;
  bool _liveActivityShown = false;

  /// What the Live Activity was last told, so it is only updated when the
  /// phase or the paused state changes.
  (Phase?, bool)? _liveActivityKey;

  @override
  void initState() {
    super.initState();
    _timer
      ..addListener(_syncRunning)
      ..addListener(_syncLiveActivity);
    _services.liveActivity.onControl = _onLiveActivityControl;
    _lifecycle = AppLifecycleListener(
      onHide: () {
        if (_timer.isRunning && !_liveActivityShown) _notify(_timer.phase);
      },
      onShow: () => unawaited(_services.notifications.clear()),
    );
    // Keep the timer in view while the phone lies on the floor.
    unawaited(WakelockPlus.enable());
    _timer.start();
    unawaited(_startLiveActivity());
  }

  Future<void> _startLiveActivity() async {
    final shown = await _services.liveActivity.start(
      LiveActivityState.of(_timer, DateTime.now()),
    );
    if (!shown) return;
    if (!mounted) {
      unawaited(_services.liveActivity.end());
      return;
    }
    _liveActivityShown = true;
    // The app may have gone to the background while the activity was
    // starting and posted the fallback notification; the activity replaces it.
    unawaited(_services.notifications.clear());
    _liveActivityKey = (_timer.phase, _timer.isRunning);
    _syncRunning();
    _syncLiveActivity(); // In case something changed while it was starting.
  }

  void _syncLiveActivity() {
    if (!_liveActivityShown) return;
    final key = (_timer.phase, _timer.isRunning);
    if (key == _liveActivityKey) return;
    _liveActivityKey = key;
    final state = LiveActivityState.of(_timer, DateTime.now());
    if (_timer.isFinished) {
      _liveActivityShown = false;
      unawaited(
        _services.liveActivity.end(
          finalState: state,
          dismissAfter: const Duration(minutes: 5),
        ),
      );
    } else {
      unawaited(_services.liveActivity.update(state));
    }
  }

  void _onLiveActivityControl(LiveActivityControl control) {
    switch (control) {
      case LiveActivityControl.togglePause:
        _timer.togglePause();
      case LiveActivityControl.skip:
        _timer.skip();
    }
  }

  void _onPhaseChanged(Phase? phase) {
    // The warm-up starts silently because the user just tapped Start.
    final cue = switch (phase?.type) {
      PhaseType.warmup => null,
      PhaseType.work => Cue.work,
      PhaseType.rest || PhaseType.roundRest => Cue.rest,
      null => Cue.finish,
    };
    if (cue != null) {
      if (widget.settings.sounds) unawaited(_services.sounds.play(cue));
      // Haptics only work while the app is on screen.
      if (widget.settings.vibration) unawaited(HapticFeedback.heavyImpact());
    }
    if (phase == null) unawaited(WakelockPlus.disable());
    final inBackground =
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
    if (inBackground && !_liveActivityShown) _notify(phase);
  }

  void _onCountdown(int secondsLeft) {
    final settings = widget.settings;
    if (!settings.countdown) return;
    if (settings.sounds) unawaited(_services.sounds.play(Cue.countdown));
    if (settings.vibration) unawaited(HapticFeedback.lightImpact());
  }

  void _notify(Phase? phase) {
    if (phase == null) {
      unawaited(
        _services.notifications.show(
          'Workout complete',
          workoutSummary(_config, _timer.activeTime),
        ),
      );
      return;
    }
    final (position, detail) = phasePosition(phase, _config);
    unawaited(
      _services.notifications.show(
        '${phase.type.label} · ${formatDuration(phase.duration)}',
        [
          [position, ?detail].join(' · '),
          nextLabel(_timer.nextPhase),
        ].join('\n'),
      ),
    );
  }

  /// Animates the ring while the timer runs, and keeps the app alive in the
  /// background while it runs or while the Live Activity offers Resume.
  void _syncRunning() {
    final running = _timer.isRunning;
    if (running && !_frames.isActive) {
      _frames.start();
    } else if (!running && _frames.isActive) {
      _frames.stop();
    }
    final keepAlive = running || (_liveActivityShown && !_timer.isFinished);
    if (keepAlive != _keepingAlive) {
      _keepingAlive = keepAlive;
      unawaited(_services.sounds.keepAlive(keepAlive));
    }
  }

  Future<void> _confirmQuit() async {
    final wasRunning = _timer.isRunning;
    _timer.pause();
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End workout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (quit ?? false) {
      Navigator.of(context).pop();
    } else if (wasRunning) {
      _timer.resume();
    }
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable());
    if (_keepingAlive) unawaited(_services.sounds.keepAlive(false));
    unawaited(_services.notifications.clear());
    _services.liveActivity.onControl = null;
    // Also clears a finished workout's activity still on the lock screen.
    unawaited(_services.liveActivity.end());
    _lifecycle.dispose();
    _timer.dispose();
    _frames.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _timer,
      builder: (context, _) {
        final phase = _timer.phase;
        final base = phase?.type.background ?? AppColors.done;
        final paused = !_timer.isRunning && !_timer.isFinished;
        return PopScope(
          canPop: _timer.isFinished,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmQuit();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            color: paused ? Color.lerp(base, Colors.black, 0.45) : base,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white),
                  child: phase == null ? _buildDone() : _buildRunning(phase),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRunning(Phase phase) {
    final text = Theme.of(context).textTheme;
    final paused = !_timer.isRunning;
    final (title, subtitle) = phasePosition(phase, _config);
    return Column(
      children: [
        _TopBar(
          title: title,
          subtitle: subtitle,
          trailing: formatDuration(Duration(seconds: _timer.totalSecondsLeft)),
          onClose: () => Navigator.maybePop(context),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side =
                  math.min(constraints.maxWidth, constraints.maxHeight) * 0.88;
              return Center(
                child: SizedBox.square(
                  dimension: side,
                  child: CustomPaint(
                    painter: _RingPainter(_timer, repaint: _frame),
                    child: Padding(
                      padding: EdgeInsets.all(side * 0.14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            paused ? 'Paused' : phase.type.label,
                            style: text.titleLarge?.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                            ),
                          ),
                          FittedBox(
                            child: Text(
                              formatDuration(
                                Duration(seconds: _timer.phaseSecondsLeft),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 120,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                fontFeatures: tabularFigures,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Text(
          nextLabel(_timer.nextPhase),
          style: text.titleMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 64),
            const SizedBox(width: 28),
            _RoundButton(
              size: 88,
              filled: true,
              icon: _timer.isRunning
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              semanticLabel: _timer.isRunning ? 'Pause' : 'Resume',
              onPressed: _timer.togglePause,
            ),
            const SizedBox(width: 28),
            _RoundButton(
              size: 64,
              icon: Icons.skip_next_rounded,
              semanticLabel: 'Skip phase',
              onPressed: _timer.skip,
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDone() {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          const Icon(Icons.check_circle_rounded, size: 96, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            'Done!',
            style: text.displayMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.workout.name,
            style: text.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          // Actual time: pauses and skipped phases don't count.
          Text(
            workoutSummary(_config, _timer.activeTime),
            style: text.titleMedium?.copyWith(color: Colors.white70),
          ),
          const Spacer(),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.done,
              minimumSize: const Size.fromHeight(64),
              textStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onClose,
  });

  final String title;
  final String? subtitle;
  final String trailing;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontFeatures: tabularFigures,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                tooltip: 'End workout',
                onPressed: onClose,
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(title, textAlign: TextAlign.center, style: style),
                if (subtitle case final subtitle?)
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: style?.copyWith(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(trailing, textAlign: TextAlign.end, style: style),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.size,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.filled = false,
  });

  final double size;
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.white : Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox.square(
          dimension: size,
          child: Icon(
            icon,
            size: size * 0.5,
            semanticLabel: semanticLabel,
            color: filled ? Colors.black87 : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Track plus the remaining part of the current phase, sweeping clockwise
/// from 12 o'clock as time runs out.
class _RingPainter extends CustomPainter {
  _RingPainter(this.timer, {required Listenable repaint})
    : super(repaint: repaint);

  final WorkoutTimer timer;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.045;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      paint..color = Colors.white.withValues(alpha: 0.2),
    );
    final remaining = 1 - timer.phaseProgress;
    if (remaining > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * remaining,
        false,
        paint..color = Colors.white,
      );
    }
  }

  // Rebuilds happen on phase/pause changes, which also move the ring.
  @override
  bool shouldRepaint(_RingPainter oldDelegate) => true;
}
