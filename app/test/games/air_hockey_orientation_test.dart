import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/air_hockey/air_hockey_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for AGENTS.md §8 and Air Hockey's `fixedPortrait`
/// composition.
///
/// The table is a real one stood on its end -- 1 wide by 2 tall -- and it
/// keeps that shape whatever it is fitted into. It never rotates pixels
/// and never touches the device orientation.
void main() {
  /// Air Hockey's ticker runs for as long as the match does, so nothing
  /// here may use `pumpAndSettle`.
  Future<void> run(WidgetTester tester, {int frames = 6}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> pumpScreen(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AirHockeyScreen(mode: GameMode.local)),
    );
    await run(tester);
  }

  Rect deckScreenRect(WidgetTester tester) =>
      tester.getRect(find.byKey(const ValueKey('air_hockey_deck')));

  testWidgets(
      'opening and leaving Air Hockey never calls setPreferredOrientations',
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

    // Landscape device: the case most likely to tempt a game-level
    // rotation for a tall table.
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
                builder: (_) => const AirHockeyScreen(mode: GameMode.local),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await run(tester, frames: 30);
    expect(find.byType(AirHockeyScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(AirHockeyScreen))).pop();
    await run(tester, frames: 30);
    expect(find.byType(AirHockeyScreen), findsNothing);

    final orientationCalls = calls
        .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
        .toList();
    expect(
      orientationCalls,
      isEmpty,
      reason: 'Air Hockey must not force a physical device rotation; a tall '
          'table is a layout shape, not a device orientation.',
    );
  });

  group('the table keeps its shape regardless of device orientation', () {
    testWidgets('portrait phone', (WidgetTester tester) async {
      await pumpScreen(tester, const Size(390, 844));

      expect(tester.takeException(), isNull);
      final rect = deckScreenRect(tester);
      expect(rect.height / rect.width, closeTo(2, 0.01));
      expect(rect.right, lessThanOrEqualTo(390.5));
      expect(rect.bottom, lessThanOrEqualTo(844.5));
    });

    testWidgets('landscape phone', (WidgetTester tester) async {
      await pumpScreen(tester, const Size(844, 390));

      expect(tester.takeException(), isNull);
      final rect = deckScreenRect(tester);
      expect(rect.height / rect.width, closeTo(2, 0.01));
      expect(rect.right, lessThanOrEqualTo(844.5));
      expect(rect.bottom, lessThanOrEqualTo(390.5));
    });

    testWidgets('large tablet landscape', (WidgetTester tester) async {
      await pumpScreen(tester, const Size(1280, 720));

      expect(tester.takeException(), isNull);
      final rect = deckScreenRect(tester);
      expect(rect.height / rect.width, closeTo(2, 0.01));
      expect(rect.right, lessThanOrEqualTo(1280.5));
      expect(rect.bottom, lessThanOrEqualTo(720.5));
    });
  });

  testWidgets('rotating the device live keeps the shape and the match',
      (WidgetTester tester) async {
    await pumpScreen(tester, const Size(390, 844));

    final table = deckScreenRect(tester);
    final finger = await tester.startGesture(
      Offset(table.left + (table.width * 0.2), table.center.dy + 120),
      pointer: 1,
    );
    await run(tester, frames: 30);
    await finger.up();

    final portraitRect = deckScreenRect(tester);
    expect(portraitRect.height / portraitRect.width, closeTo(2, 0.01));

    // The user physically turns the phone sideways.
    tester.view.physicalSize = const Size(844, 390);
    await run(tester, frames: 10);

    final landscapeRect = deckScreenRect(tester);
    expect(landscapeRect.height / landscapeRect.width, closeTo(2, 0.01));
    expect(landscapeRect.height, lessThan(portraitRect.height),
        reason: 'it shrinks to fit rather than cropping');
    expect(tester.takeException(), isNull);

    expect(find.byKey(const ValueKey('air_hockey_mallet_blue')),
        findsOneWidget,
        reason: 'the match survived the rotation');
  });
}
