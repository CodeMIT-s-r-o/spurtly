import 'package:flutter/material.dart';

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
      home: HomeScreen(library: library, services: services),
    );
  }
}
