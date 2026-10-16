import 'package:flutter/material.dart';

import 'models/workout_config.dart';
import 'screens/setup_screen.dart';
import 'services/sounds.dart';
import 'services/workout_notifications.dart';
import 'theme.dart';

class SpurtlyApp extends StatelessWidget {
  const SpurtlyApp({
    super.key,
    required this.initialConfig,
    required this.onConfigChanged,
    required this.sounds,
    required this.notifications,
  });

  final WorkoutConfig initialConfig;
  final ValueChanged<WorkoutConfig> onConfigChanged;
  final Sounds sounds;
  final WorkoutNotifications notifications;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spurtly',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: SetupScreen(
        initialConfig: initialConfig,
        onConfigChanged: onConfigChanged,
        sounds: sounds,
        notifications: notifications,
      ),
    );
  }
}
