import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spurtly/app.dart';
import 'package:spurtly/models/app_settings.dart';
import 'package:spurtly/models/presets.dart';
import 'package:spurtly/models/workout_config.dart';
import 'package:spurtly/services/app_services.dart';
import 'package:spurtly/services/live_activity.dart';
import 'package:spurtly/services/pro.dart';
import 'package:spurtly/services/sounds.dart';
import 'package:spurtly/services/vibrations.dart';
import 'package:spurtly/services/workout_library.dart';
import 'package:spurtly/screens/timer_screen.dart';
import 'package:spurtly/services/workout_notifications.dart';
import 'package:spurtly/theme.dart';

class _SilentSounds implements Sounds {
  @override
  Future<void> play(Cue cue) async {}

  @override
  Future<void> keepAlive(bool active) async {}
}

class _RecordingVibrations implements Vibrations {
  final cues = <Cue>[];

  @override
  Future<void> vibrate(Cue cue) async => cues.add(cue);
}

class _NoLiveActivity implements LiveActivity {
  @override
  Future<bool> start(LiveActivityState state, {bool controls = true}) async =>
      false;

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

class _FakePro extends SpurtlyPro {
  _FakePro({required this._unlocked});

  bool _unlocked;

  @override
  bool get unlocked => _unlocked;

  @override
  String? get price => '4,99 €';

  /// A refund, or a purchase made elsewhere.
  set unlocked(bool unlocked) {
    _unlocked = unlocked;
    notifyListeners();
  }

  @override
  Future<ProOutcome> buy() async {
    unlocked = true;
    return ProOutcome.unlocked;
  }

  @override
  Future<ProOutcome> restore() async => ProOutcome.notFound;

  @override
  Future<void> redeemCode() async {}
}

void main() {
  late WorkoutLibrary library;
  late _FakePro fakePro;
  late _RecordingVibrations vibrations;

  setUp(() {
    // The timer keeps the screen on through wakelock_plus.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.'
          'WakelockPlusApi.toggle',
          (_) async => const StandardMessageCodec().encodeMessage([null]),
        );
  });

  /// [size] is in logical pixels; by default an iPhone, so every row is on
  /// screen.
  Future<void> pumpApp(
    WidgetTester tester, {
    required bool pro,
    Size size = const Size(390, 844),
  }) async {
    tester.view
      ..physicalSize = size * 3
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
          vibrations: vibrations = _RecordingVibrations(),
          notifications: _NoNotifications(),
          liveActivity: _NoLiveActivity(),
          pro: fakePro = _FakePro(unlocked: pro),
        ),
      ),
    );
  }

  /// Taps Start (or a card's play button) and lets the timer screen open;
  /// its ring animates while it runs, so it never settles.
  Future<void> start(WidgetTester tester, Finder button) async {
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('free', () {
    testWidgets('one screen to set up and start a workout', (tester) async {
      await pumpApp(tester, pro: false);

      expect(find.text('Your workouts'.toUpperCase()), findsNothing);
      expect(find.byTooltip('Settings'), findsNothing);
      expect(
        find.text(
          'Total  ${formatDuration(WorkoutConfig.defaults.total)}',
          findRichText: true,
        ),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsLabel('Decrease Rounds'));
      await tester.pump();
      expect(library.quickConfig.rounds, WorkoutConfig.defaults.rounds - 1);
    });

    testWidgets('starts with default signals, except the sound switch', (
      tester,
    ) async {
      await pumpApp(tester, pro: false);
      library.settings = const AppSettings(countdown: false, vibration: false);
      await tester.pump();

      await tester.tap(find.byTooltip('Mute sounds'));
      await tester.pump();
      expect(library.settings.sounds, isFalse);

      await start(tester, find.text('Start'));
      final timer = tester.widget<TimerScreen>(find.byType(TimerScreen));
      expect(timer.settings, const AppSettings(sounds: false));
      expect(timer.name, isNull);
      expect(timer.config, library.quickConfig);
    });

    testWidgets('Save offers Pro; buying it opens the workout library', (
      tester,
    ) async {
      await pumpApp(tester, pro: false);
      await tester.tap(find.bySemanticsLabel('Decrease Rounds'));
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Save your workouts and start any of them with one tap.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Unlock for 4,99 €'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Tabata'), findsOneWidget);
      // What was set up on the free screen is kept as a workout.
      final mine = library.workouts.last;
      expect(mine.name, 'My workout');
      expect(mine.config, library.quickConfig);
    });

    testWidgets('an unchanged free setup is not added as a workout', (
      tester,
    ) async {
      await pumpApp(tester, pro: false);
      fakePro.unlocked = true;
      await tester.pumpAndSettle();

      expect(library.workouts, presetWorkouts);
    });

    testWidgets('after a refund the free screen is back, workouts kept', (
      tester,
    ) async {
      await pumpApp(tester, pro: true);
      fakePro.unlocked = false;
      await tester.pumpAndSettle();

      expect(find.text('Tabata'), findsNothing);
      expect(find.text('Start'), findsOneWidget);
      expect(library.workouts, presetWorkouts);
    });

    testWidgets('Pro offers restore, which reports nothing found', (
      tester,
    ) async {
      await pumpApp(tester, pro: false);

      await tester.tap(find.text('Pro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore purchase'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No earlier purchase found'), findsOneWidget);
    });
  });

  group('Pro', () {
    testWidgets('home lists the three presets', (tester) async {
      await pumpApp(tester, pro: true);

      expect(find.text('HIIT 1:1'), findsOneWidget);
      expect(find.text('HIIT 2:1'), findsOneWidget);
      expect(find.text('Tabata'), findsOneWidget);
      expect(find.text('0:20 / 0:10 · 8 × 4 · 20:20'), findsOneWidget);
    });

    testWidgets('editing a workout saves it and updates its card', (
      tester,
    ) async {
      await pumpApp(tester, pro: true);

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
      await pumpApp(tester, pro: true);

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
      await pumpApp(tester, pro: true);

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
      await pumpApp(tester, pro: true);

      await tester.drag(find.text('Tabata'), const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Tabata'), findsOneWidget);
      expect(find.text('Tabata copy'), findsOneWidget);
      expect(library.workouts, hasLength(4));
    });

    testWidgets('a saved workout starts with its name and the settings', (
      tester,
    ) async {
      await pumpApp(tester, pro: true);
      library.settings = const AppSettings(countdown: false);

      await start(tester, find.bySemanticsLabel('Start Tabata'));
      final timer = tester.widget<TimerScreen>(find.byType(TimerScreen));
      expect(timer.name, 'Tabata');
      expect(timer.settings, const AppSettings(countdown: false));
    });

    testWidgets('a phase change vibrates, unless vibration is off', (
      tester,
    ) async {
      await pumpApp(tester, pro: true);
      await start(tester, find.bySemanticsLabel('Start Tabata'));
      await tester.tap(find.bySemanticsLabel('Skip phase'));
      await tester.pump();
      expect(vibrations.cues, [Cue.work]);

      Navigator.of(tester.element(find.byType(TimerScreen))).pop();
      await tester.pumpAndSettle();
      library.settings = const AppSettings(vibration: false);
      await start(tester, find.bySemanticsLabel('Start Tabata'));
      await tester.tap(find.bySemanticsLabel('Skip phase'));
      await tester.pump();
      expect(vibrations.cues, [Cue.work]);
    });

    testWidgets('settings switch signals off', (tester) async {
      await pumpApp(tester, pro: true);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3-2-1 countdown'));
      await tester.pumpAndSettle();

      expect(library.settings.countdown, isFalse);
      expect(library.settings.sounds, isTrue);
    });
  });

  group('on a tablet', () {
    const landscape = Size(1280, 800);
    const portrait = Size(800, 1280);

    testWidgets('the list and the editor keep a readable width', (
      tester,
    ) async {
      await pumpApp(tester, pro: true, size: landscape);

      final card = find
          .ancestor(of: find.text('Tabata'), matching: find.byType(Material))
          .first;
      expect(tester.getSize(card).width, 640);
      expect(tester.getCenter(card).dx, 640);

      await tester.tap(find.text('Tabata'));
      await tester.pumpAndSettle();
      final start = find.widgetWithText(FilledButton, 'Start');
      expect(tester.getSize(start).width, 640);
      expect(tester.getCenter(start).dx, 640);
    });

    testWidgets('the free screen keeps a readable width', (tester) async {
      await pumpApp(tester, pro: false, size: landscape);

      final start = find.widgetWithText(FilledButton, 'Start');
      expect(tester.getSize(start).width, 640);
      expect(tester.getCenter(start).dx, 640);
    });

    testWidgets('in landscape the timer puts its buttons beside the ring', (
      tester,
    ) async {
      await pumpApp(tester, pro: true, size: landscape);
      await start(tester, find.bySemanticsLabel('Start Tabata'));

      final ring = tester.getCenter(find.text('Warm-up'));
      final pause = tester.getCenter(find.bySemanticsLabel('Pause'));
      expect(pause.dx, greaterThan(ring.dx + 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('in portrait the timer keeps its buttons below the ring', (
      tester,
    ) async {
      await pumpApp(tester, pro: true, size: portrait);
      await start(tester, find.bySemanticsLabel('Start Tabata'));

      final ring = tester.getCenter(find.text('Warm-up'));
      final pause = tester.getCenter(find.bySemanticsLabel('Pause'));
      expect(pause.dy, greaterThan(ring.dy + 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a low split-screen window still fits', (tester) async {
      await pumpApp(tester, pro: true, size: const Size(1280, 390));
      expect(tester.takeException(), isNull);

      await start(tester, find.bySemanticsLabel('Start HIIT 1:1'));
      expect(tester.takeException(), isNull);
    });
  });
}
