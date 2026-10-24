import 'package:flutter/material.dart';

import '../services/pro.dart';
import '../services/workout_library.dart';
import '../theme.dart';
import 'pro_sheet.dart';

/// Spurtly Pro, and switches for the timer's sounds, countdown and vibration.
Future<void> showSettingsSheet(
  BuildContext context,
  WorkoutLibrary library,
  SpurtlyPro pro,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (context) => SingleChildScrollView(
      child: ListenableBuilder(
        listenable: Listenable.merge([library, pro]),
        builder: (context, _) {
          final settings = library.settings;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProTile(pro: pro),
              const Divider(height: 24, indent: 24, endIndent: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  'Signals',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              SwitchListTile(
                title: const Text('Sounds'),
                subtitle: const Text(
                  'Chimes when work and rest start, and at the finish',
                ),
                value: settings.sounds,
                onChanged: (on) =>
                    library.settings = settings.copyWith(sounds: on),
              ),
              SwitchListTile(
                title: const Text('3-2-1 countdown'),
                subtitle: const Text(
                  'Pips in the last 3 seconds of each phase',
                ),
                value: settings.countdown,
                onChanged: (on) =>
                    library.settings = settings.copyWith(countdown: on),
              ),
              SwitchListTile(
                title: const Text('Vibration'),
                subtitle: const Text(
                  'A buzz when the phase changes, also with the screen locked',
                ),
                value: settings.vibration,
                onChanged: (on) =>
                    library.settings = settings.copyWith(vibration: on),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    ),
  );
}

class _ProTile extends StatelessWidget {
  const _ProTile({required this.pro});

  final SpurtlyPro pro;

  @override
  Widget build(BuildContext context) {
    final unlocked = pro.unlocked;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: const Icon(
        Icons.workspace_premium_rounded,
        color: AppColors.coral,
        size: 32,
      ),
      title: Text(
        'Spurtly Pro',
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        unlocked
            ? 'Unlocked. Thank you!'
            : 'Saved workouts, signal settings and lock-screen controls',
      ),
      trailing: unlocked
          ? const Icon(Icons.check_circle_rounded, color: AppColors.teal)
          : const Icon(Icons.chevron_right_rounded),
      onTap: () => showProSheet(context, pro),
    );
  }
}
