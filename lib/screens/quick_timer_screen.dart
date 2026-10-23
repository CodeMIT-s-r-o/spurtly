import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/workout_library.dart';
import '../widgets/app_header.dart';
import '../widgets/pro_badge.dart';
import '../widgets/readable_width.dart';
import '../widgets/workout_form.dart';
import 'pro_sheet.dart';
import 'start_workout.dart';

/// The free version: one workout to set up and start, remembered between
/// launches. Saving workouts, signal settings and the lock-screen controls
/// come with Spurtly Pro.
class QuickTimerScreen extends StatelessWidget {
  const QuickTimerScreen({
    super.key,
    required this.library,
    required this.services,
  });

  final WorkoutLibrary library;
  final AppServices services;

  void _offerPro(BuildContext context, {String? reason}) =>
      showProSheet(context, services.pro, reason: reason);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: library,
          builder: (context, _) {
            final config = library.quickConfig;
            final sounds = library.settings.sounds;
            return Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = readableInset(constraints.maxWidth);
                      return ListView(
                        // Full width, so the margins of a tablet scroll it
                        // too.
                        padding: EdgeInsets.fromLTRB(side, 16, side, 16),
                        children: [
                          AppHeader(
                            trailing: TextButton.icon(
                              onPressed: () => _offerPro(context),
                              icon: const Icon(Icons.workspace_premium_rounded),
                              label: const Text('Pro'),
                            ),
                          ),
                          WorkoutConfigForm(
                            config: config,
                            onChanged: (config) => library.quickConfig = config,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                ReadableWidth(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              // On iPhone the cues play even in silent
                              // mode, so this is the way to mute them.
                              tooltip: sounds
                                  ? 'Mute sounds'
                                  : 'Turn sounds on',
                              icon: Icon(
                                sounds
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_off_rounded,
                              ),
                              onPressed: () => library.settings = library
                                  .settings
                                  .copyWith(sounds: !sounds),
                            ),
                            Expanded(
                              child: Center(child: WorkoutTotal(config)),
                            ),
                            TextButton(
                              onPressed: () => _offerPro(
                                context,
                                reason:
                                    'Save your workouts and start any of '
                                    'them with one tap.',
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Save'),
                                  SizedBox(width: 6),
                                  ProBadge(),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: StartButton(
                            onPressed: () => startWorkout(
                              context,
                              config: config,
                              library: library,
                              services: services,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
