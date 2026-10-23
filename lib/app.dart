import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/workout_config.dart';
import 'screens/home_screen.dart';
import 'screens/quick_timer_screen.dart';
import 'services/app_services.dart';
import 'services/workout_library.dart';
import 'theme.dart';

class SpurtlyApp extends StatelessWidget {
  const SpurtlyApp({super.key, required this.library, required this.services});

  final WorkoutLibrary library;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spurtly',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => _OrientationPolicy(child: child!),
      home: _Home(library: library, services: services),
    );
  }
}

/// The workout library with Pro, the single free screen without. Switches
/// when Pro is bought, and back after a refund; saved workouts stay stored
/// in between.
class _Home extends StatefulWidget {
  const _Home({required this.library, required this.services});

  final WorkoutLibrary library;
  final AppServices services;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  late bool _pro = widget.services.pro.unlocked;

  @override
  void initState() {
    super.initState();
    widget.services.pro.addListener(_onProChanged);
  }

  @override
  void dispose() {
    widget.services.pro.removeListener(_onProChanged);
    super.dispose();
  }

  void _onProChanged() {
    final pro = widget.services.pro.unlocked;
    if (pro == _pro) return;
    final library = widget.library;
    // Keep what was set up on the free screen as the first own workout.
    if (pro && library.quickConfig != WorkoutConfig.defaults) {
      library.create(config: library.quickConfig);
    }
    setState(() => _pro = pro);
  }

  @override
  Widget build(BuildContext context) {
    return _pro
        ? HomeScreen(library: widget.library, services: widget.services)
        : QuickTimerScreen(library: widget.library, services: widget.services);
  }
}

/// Phones stay in portrait. Tablets and unfolded foldables may rotate:
/// Android 16 ignores the lock on such large screens anyway, and the
/// screens adapt to landscape. Checked whenever the window changes size,
/// e.g. when a foldable is folded or unfolded.
class _OrientationPolicy extends StatefulWidget {
  const _OrientationPolicy({required this.child});

  final Widget child;

  @override
  State<_OrientationPolicy> createState() => _OrientationPolicyState();
}

class _OrientationPolicyState extends State<_OrientationPolicy> {
  bool? _large;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final large = MediaQuery.sizeOf(context).shortestSide >= 600;
    if (large == _large) return;
    _large = large;
    unawaited(
      SystemChrome.setPreferredOrientations(
        large ? const [] : const [DeviceOrientation.portraitUp],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
