import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spurtly/app.dart';
import 'package:spurtly/models/app_settings.dart';
import 'package:spurtly/models/presets.dart';
import 'package:spurtly/services/app_services.dart';
import 'package:spurtly/services/live_activity.dart';
import 'package:spurtly/services/sounds.dart';
import 'package:spurtly/services/workout_library.dart';
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
  late WorkoutLibrary library;

  Future<void> pumpApp(WidgetTester tester) async {
    // iPhone-sized viewport, so every row is on screen.
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    library = WorkoutLibrary(
      workouts: presetWorkouts,
      settings: const AppSettings(),
    );
    await tester.pumpWidget(
      SpurtlyApp(
        library: library,
        services: AppServices(
          sounds: _SilentSounds(),
          notifications: _NoNotifications(),
          liveActivity: _NoLiveActivity(),
        ),
      ),
    );
  }

  testWidgets('home lists the three presets', (tester) async {
    await pumpApp(tester);

    expect(find.text('HIIT 1:1'), findsOneWidget);
    expect(find.text('HIIT 2:1'), findsOneWidget);
    expect(find.text('Tabata'), findsOneWidget);
    expect(find.text('0:20 / 0:10 · 8 × 4 · 20:20'), findsOneWidget);
  });

  testWidgets('editing a workout saves it and updates its card', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Tabata'));
    await tester.pumpAndSettle();
    expect(find.text('Total  20:20', findRichText: true), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Decrease Rounds'));
    await tester.pump();
    expect(library.byId('preset-tabata')!.config.rounds, 3);
    expect(find.text('Total  15:30', findRichText: true), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('0:20 / 0:10 · 8 × 3 · 15:30'), findsOneWidget);
  });

  testWidgets('a new workout can be renamed and deleted', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('New workout'));
    await tester.pumpAndSettle();
    expect(find.text('My workout'), findsOneWidget);

    await tester.tap(find.text('My workout'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Leg day');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Leg day'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Leg day'), findsNothing);
    expect(library.workouts, hasLength(3));
  });

  testWidgets('swiping left deletes a workout, Undo brings it back', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.drag(find.text('HIIT 2:1'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('HIIT 2:1'), findsNothing);
    expect(find.text('Deleted “HIIT 2:1”'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(library.workouts.map((w) => w.name), [
      'HIIT 1:1',
      'HIIT 2:1',
      'Tabata',
    ]);
  });

  testWidgets('swiping right duplicates a workout and keeps the original', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.drag(find.text('Tabata'), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Tabata'), findsOneWidget);
    expect(find.text('Tabata copy'), findsOneWidget);
    expect(library.workouts, hasLength(4));
  });

  testWidgets('settings switch signals off', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3-2-1 countdown'));
    await tester.pumpAndSettle();

    expect(library.settings.countdown, isFalse);
    expect(library.settings.sounds, isTrue);
  });
}
