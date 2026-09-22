import 'package:app/games/sling_puck/logic/game_tuning.dart';
import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/sling_puck/sling_puck_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for AGENTS.md §8 and Sling Puck's `fixedPortrait`
/// composition: the board always stays portrait-shaped (tall), fit/scaled
/// to whatever space it is given, never rotating the device or the pixels
/// (mirroring tetra_tower_orientation_test.dart's structure).
void main() {
  const aspectRatio = GameTuning.fieldWidth / GameTuning.fieldHeight;

  Future<void> pumpScreen(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: SlingPuckScreen(mode: GameMode.local)),
    );
    await tester.pumpAndSettle();
  }

  Rect boardScreenRect(WidgetTester tester) {
    return tester.getRect(find.byKey(const ValueKey('sling_puck_board')));
  }

  testWidgets(
      'opening and leaving Sling Puck never calls setPreferredOrientations',
      (WidgetTester tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    // Landscape device: the case most likely to tempt a game-level rotation
    // for a "portrait" game.
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SlingPuckScreen(mode: GameMode.local),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(SlingPuckScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(SlingPuckScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(SlingPuckScreen), findsNothing);

    final orientationCalls = calls
        .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
        .toList();
    expect(
      orientationCalls,
      isEmpty,
      reason:
          'Sling Puck must not force a physical device rotation; the '
          'portrait-shaped board simply scales down on a landscape device, '
          'it never rotates.',
    );
  });

  group('the board stays portrait-shaped regardless of device orientation', () {
    testWidgets('portrait phone', (WidgetTester tester) async {
      await pumpScreen(tester, const Size(390, 844));

      expect(tester.takeException(), isNull);
      final rect = boardScreenRect(tester);
      expect(rect.height, greaterThan(rect.width));
      expect(rect.width / rect.height, closeTo(aspectRatio, 0.01));
      expect(rect.right, lessThanOrEqualTo(390.5));
      expect(rect.bottom, lessThanOrEqualTo(844.5));
    });

    testWidgets('landscape phone', (WidgetTester tester) async {
      await pumpScreen(tester, const Size(844, 390));

      expect(tester.takeException(), isNull);
      final rect = boardScreenRect(tester);
      expect(rect.height, greaterThan(rect.width));
      expect(rect.width / rect.height, closeTo(aspectRatio, 0.01));
      expect(rect.right, lessThanOrEqualTo(844.5));
      expect(rect.bottom, lessThanOrEqualTo(390.5));
    });

    testWidgets('large tablet landscape', (WidgetTester tester) async {
      await pumpScreen(tester, const Size(1280, 720));

      expect(tester.takeException(), isNull);
      final rect = boardScreenRect(tester);
      expect(rect.height, greaterThan(rect.width));
      expect(rect.width / rect.height, closeTo(aspectRatio, 0.01));
    });
  });

  testWidgets(
      'rotating the device live keeps the board portrait-shaped, with no restart',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: SlingPuckScreen(mode: GameMode.local)),
    );
    await tester.pumpAndSettle();

    final portraitRect = boardScreenRect(tester);
    expect(portraitRect.height, greaterThan(portraitRect.width));

    // The user physically turns the phone sideways.
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();

    final landscapeRect = boardScreenRect(tester);
    expect(landscapeRect.height, greaterThan(landscapeRect.width));
    expect(tester.takeException(), isNull);
  });
}
