import 'package:flutter/material.dart';

import 'models/phase.dart';

abstract final class AppColors {
  /// Taken from the app icon.
  static const background = Color(0xFF111628);
  static const surface = Color(0xFF1C2238);
  static const stepper = Color(0xFF2C3454);
  static const muted = Color(0xFF8F97AE);
  static const coral = Color(0xFFFF6A4D);
  static const onCoral = Colors.white;
  static const teal = Color(0xFF2DD4BF);
  static const indigo = Color(0xFF8B92FF);

  /// Full-screen background of the finished state.
  static const done = Color(0xFF4C55D6);
}

extension PhaseStyle on PhaseType {
  String get label => switch (this) {
    PhaseType.warmup => 'Warm-up',
    PhaseType.work => 'Work',
    PhaseType.rest => 'Rest',
    PhaseType.roundRest => 'Round rest',
  };

  /// Full-screen background while the phase runs; carries white text.
  Color get background => switch (this) {
    PhaseType.warmup => const Color(0xFFB86E00),
    PhaseType.work => const Color(0xFFE0453A),
    PhaseType.rest => const Color(0xFF0E8F80),
    PhaseType.roundRest => const Color(0xFF0B6E7A),
  };

  /// Brighter variant for icons and text on the dark app background.
  Color get accent => switch (this) {
    PhaseType.warmup => const Color(0xFFFFB547),
    PhaseType.work => AppColors.coral,
    PhaseType.rest => AppColors.teal,
    PhaseType.roundRest => const Color(0xFF38BDF8),
  };
}

const tabularFigures = [FontFeature.tabularFigures()];

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.coral,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.coral,
        onPrimary: AppColors.onCoral,
        surface: AppColors.background,
        // Menus, dialogs and sheets in the app's navy instead of tones
        // derived from the coral seed.
        surfaceContainerLowest: const Color(0xFF0C1020),
        surfaceContainerLow: const Color(0xFF161B2E),
        surfaceContainer: AppColors.surface,
        surfaceContainerHigh: const Color(0xFF232A44),
        surfaceContainerHighest: AppColors.stepper,
      );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.stepper,
      contentTextStyle: const TextStyle(color: Colors.white),
      actionTextColor: AppColors.coral,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// `m:ss`, or `h:mm:ss` from an hour up.
String formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
      : '$minutes:$seconds';
}
