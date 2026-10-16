import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/phase.dart';
import '../models/workout_config.dart';
import '../services/sounds.dart';
import '../services/workout_notifications.dart';
import '../theme.dart';
import '../timer/workout_timer.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({
    super.key,
    required this.config,
    required this.sounds,
    required this.notifications,
  });

  final WorkoutConfig config;
  final Sounds sounds;
  final WorkoutNotifications notifications;

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with SingleTickerProviderStateMixin {
  late final WorkoutTimer _timer = WorkoutTimer(
    widget.config,
    onPhaseChanged: _onPhaseChanged,
    onCountdown: (_) => unawaited(widget.sounds.play(Cue.countdown)),
  );

  /// Bumped every frame while running so the ring sweeps smoothly; the rest
  /// of the screen only rebuilds when the timer notifies.
  final _frame = ValueNotifier<int>(0);
  late final Ticker _frames = createTicker((_) => _frame.value++);

  /// While the app is in the background the lock screen shows the current
  /// phase as a notification; it goes away once the app is back.
  late final AppLifecycleListener _lifecycle;

  bool _keepingAlive = false;

  @override
  void initState() {
    super.initState();
    _timer.addListener(_syncRunning);
    _lifecycle = AppLifecycleListener(
      onHide: () {
        if (_timer.isRunning) _notify(_timer.phase);
      },
      onShow: () => unawaited(widget.notifications.clear()),
    );
    // Keep the timer in view while the phone lies on the floor.
    unawaited(WakelockPlus.enable());
    _timer.start();
  }

  void _onPhaseChanged(Phase? phase) {
    // The warm-up starts silently because the user just tapped Start.
    final cue = switch (phase?.type) {
      PhaseType.warmup => null,
      PhaseType.work => Cue.work,
      PhaseType.rest || PhaseType.roundRest => Cue.rest,
      null => Cue.finish,
    };
    if (cue != null) unawaited(widget.sounds.play(cue));
    if (phase == null) unawaited(WakelockPlus.disable());
    final inBackground =
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
    if (inBackground) _notify(phase);
  }

  void _notify(Phase? phase) {
    final config = widget.config;
    if (phase == null) {
      unawaited(
        widget.notifications.show(
          'Workout complete',
          '${config.rounds * config.intervals} intervals · '
              '${formatDuration(config.total)}',
        ),
      );
      return;
    }
    final (position, detail) = _position(phase);
    unawaited(
      widget.notifications.show(
        '${phase.type.label} · ${formatDuration(phase.duration)}',
        [
          [position, ?detail].join(' · '),
          _nextLabel(_timer.nextPhase),
        ].join('\n'),
      ),
    );
  }

  /// Animates the ring and keeps the app alive in the background, but only
  /// while the timer actually runs.
  void _syncRunning() {
    final running = _timer.isRunning;
    if (running && !_frames.isActive) {
      _frames.start();
    } else if (!running && _frames.isActive) {
      _frames.stop();
    }
    if (running != _keepingAlive) {
      _keepingAlive = running;
      unawaited(widget.sounds.keepAlive(running));
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
    if (_keepingAlive) unawaited(widget.sounds.keepAlive(false));
    unawaited(widget.notifications.clear());
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
    final (title, subtitle) = _position(phase);
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
          _nextLabel(_timer.nextPhase),
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

  /// Where in the workout [phase] is, as a title and optional subtitle.
  (String, String?) _position(Phase phase) {
    final config = widget.config;
    final round = 'Round ${phase.round} / ${config.rounds}';
    final interval = config.intervals > 1
        ? 'Interval ${phase.interval} / ${config.intervals}'
        : null;
    return switch (phase.type) {
      PhaseType.warmup => ('Get ready', null),
      PhaseType.work || PhaseType.rest => (round, interval),
      PhaseType.roundRest => (round, 'Round complete'),
    };
  }

  String _nextLabel(Phase? next) {
    if (next == null) return 'Last one!';
    final time = formatDuration(next.duration);
    final name = next.type == PhaseType.work && next.interval == 1
        ? 'Round ${next.round}'
        : next.type.label;
    return 'Next: $name · $time';
  }

  Widget _buildDone() {
    final text = Theme.of(context).textTheme;
    final config = widget.config;
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
            '${config.rounds * config.intervals} intervals · '
            '${formatDuration(config.total)}',
            style: text.titleLarge?.copyWith(color: Colors.white70),
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
