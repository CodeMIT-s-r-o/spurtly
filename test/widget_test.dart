import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spurtly/app.dart';
import 'package:spurtly/models/workout_config.dart';
import 'package:spurtly/services/live_activity.dart';
import 'package:spurtly/services/sounds.dart';
import 'package:spurtly/services/workout_notifications.dart';

class _SilentSounds implements Sounds {
  @override
  Future<void> play(Cue cue) async {}

  @override
  Future<void> keepAlive(bool active) async {}
}

class _NoLiveActivity implements LiveActivity {
  @override
  Future<bool> start(LiveActivityState state) async => false;

  @override
  Future<void> update(LiveActivityState state) async {}

  @override
  Future<void> end({
    LiveActivityState? finalState,
    Duration? dismissAfter,
  }) async {}

  @override
  set onControl(ValueChanged<LiveActivityControl>? handler) {}
}

class _NoNotifications implements WorkoutNotifications {
  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> show(String title, String body) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('setup screen edits rounds and updates the total', (
    tester,
  ) async {
    // iPhone-sized viewport, so every row is on screen.
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    WorkoutConfig? saved;
    await tester.pumpWidget(
      SpurtlyApp(
        initialConfig: WorkoutConfig.defaults,
        onConfigChanged: (config) => saved = config,
        sounds: _SilentSounds(),
        notifications: _NoNotifications(),
        liveActivity: _NoLiveActivity(),
      ),
    );

    // 1:00 warm-up + 3 rounds × (4 × 0:30 work + 3 × 0:15 rest)
    // + 2 × 1:00 round rest
    expect(find.text('Total  11:15', findRichText: true), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Increase Rounds'));
    await tester.pump();

    expect(saved?.rounds, 4);
    expect(find.text('Total  15:00', findRichText: true), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
  });
}
