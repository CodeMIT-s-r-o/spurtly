import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
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
      home: HomeScreen(library: library, services: services),
    );
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
