import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spurtly/app.dart';
import 'package:spurtly/models/app_settings.dart';
import 'package:spurtly/models/presets.dart';
import 'package:spurtly/services/app_services.dart';
import 'package:spurtly/services/live_activity.dart';
import 'package:spurtly/services/pro.dart';
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

  @override
  Future<ProOutcome> buy() async {
    _unlocked = true;
    notifyListeners();
    return ProOutcome.unlocked;
  }

  @override
  Future<ProOutcome> restore() async => ProOutcome.notFound;

  @override
  Future<void> redeemCode() async {}
}

void main() {
  late WorkoutLibrary library;

  /// [size] is in logical pixels; by default an iPhone, so every row is on
  /// screen.
  Future<void> pumpApp(
    WidgetTester tester, {
    bool pro = false,
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
          notifications: _NoNotifications(),
          liveActivity: _NoLiveActivity(),
          pro: _FakePro(unlocked: pro),
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
    await pumpApp(tester, pro: true);

    await tester.drag(find.text('Tabata'), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Tabata'), findsOneWidget);
    expect(find.text('Tabata copy'), findsOneWidget);
    expect(library.workouts, hasLength(4));
  });

  testWidgets('without Pro, a fourth workout offers Pro; buying unlocks it', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('PRO'), findsOneWidget);

    await tester.tap(find.text('New workout'));
    await tester.pumpAndSettle();
    expect(library.workouts, hasLength(3));
    expect(
      find.text('The free version keeps 3 workouts. Unlock Pro to add more.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Unlock for 4,99 €'));
    await tester.pumpAndSettle();
    expect(find.text('Unlocked. Thank you for supporting Spurtly!'), findsOne);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('PRO'), findsNothing);
    await tester.tap(find.text('New workout'));
    await tester.pumpAndSettle();
    expect(library.workouts, hasLength(4));
  });

  testWidgets('without Pro, swiping right offers Pro instead of a copy', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.drag(find.text('Tabata'), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Tabata copy'), findsNothing);
    expect(find.text('Spurtly Pro'), findsOneWidget);
  });

  testWidgets('without Pro, a deleted workout makes room for a new one', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.drag(find.text('HIIT 2:1'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('PRO'), findsNothing);

    await tester.tap(find.text('New workout'));
    await tester.pumpAndSettle();
    expect(find.text('My workout'), findsOneWidget);
  });

  testWidgets('settings offer Pro, restore reports nothing found', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spurtly Pro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore purchase'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No earlier purchase found'), findsOneWidget);
  });

  group('on a tablet', () {
    const landscape = Size(1280, 800);
    const portrait = Size(800, 1280);

    setUp(() {
      // The timer keeps the screen on through wakelock_plus.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.'
            'WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]),
          );
    });

    Future<void> start(WidgetTester tester, String workout) async {
      await tester.tap(find.bySemanticsLabel('Start $workout'));
      // The ring animates while the timer runs, so it never settles.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('the list and the editor keep a readable width', (
      tester,
    ) async {
      await pumpApp(tester, size: landscape);

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

    testWidgets('in landscape the timer puts its buttons beside the ring', (
      tester,
    ) async {
      await pumpApp(tester, size: landscape);
      await start(tester, 'Tabata');

      final ring = tester.getCenter(find.text('Warm-up'));
      final pause = tester.getCenter(find.bySemanticsLabel('Pause'));
      expect(pause.dx, greaterThan(ring.dx + 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('in portrait the timer keeps its buttons below the ring', (
      tester,
    ) async {
      await pumpApp(tester, size: portrait);
      await start(tester, 'Tabata');

      final ring = tester.getCenter(find.text('Warm-up'));
      final pause = tester.getCenter(find.bySemanticsLabel('Pause'));
      expect(pause.dy, greaterThan(ring.dy + 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a low split-screen window still fits', (tester) async {
      await pumpApp(tester, size: const Size(1280, 390));
      expect(tester.takeException(), isNull);

      await start(tester, 'HIIT 1:1');
      expect(tester.takeException(), isNull);
    });
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
