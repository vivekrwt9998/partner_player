import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/snakes_and_ladders/snakes_and_ladders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for AGENTS.md §8 and Snakes and Ladders'
/// `fixedPortrait` composition.
///
/// A 10x10 board is square, so it reads the same whether the device is
/// held portrait or landscape: this screen never needs a pixel rotation
/// trick, it only aspect-fits the same composition to whatever space it
/// is given.
void main() {
  /// Never `pumpAndSettle`: the die spins on a repeating timer.
  Future<void> settle(WidgetTester tester, {int frames = 8}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> pumpScreen(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: SnakesAndLaddersScreen(mode: GameMode.local)),
    );
    await settle(tester);
  }

  Rect boardScreenRect(WidgetTester tester) =>
      tester.getRect(find.byKey(const ValueKey('snakes_and_ladders_board')));

  testWidgets(
      'opening and leaving the game never calls setPreferredOrientations',
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
    // rotation for a tall-looking board.
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
                builder: (_) =>
                    const SnakesAndLaddersScreen(mode: GameMode.local),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await settle(tester);
    expect(find.byType(SnakesAndLaddersScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(SnakesAndLaddersScreen))).pop();
    await settle(tester);
    expect(find.byType(SnakesAndLaddersScreen), findsNothing);

    final orientationCalls = calls
        .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
        .toList();
    expect(
      orientationCalls,
      isEmpty,
      reason: 'a square board never needs a device rotation.',
    );
  });

  group('the board stays square regardless of device orientation', () {
    testWidgets('portrait phone', (WidgetTester tester) async {
      await pumpScreen(tester, const Size(390, 844));

      expect(tester.takeException(), isNull);
      final rect = boardScreenRect(tester);
      expect(rect.width, closeTo(rect.height, 0.5));
      expect(rect.right, lessThanOrEqualTo(390.5));
      expect(rect.bottom, lessThanOrEqualTo(844.5));
    });

    testWidgets('landscape phone', (WidgetTester tester) async {
      await pumpScreen(tester, const Size(844, 390));

      expect(tester.takeException(), isNull);
      final rect = boardScreenRect(tester);
      expect(rect.width, closeTo(rect.height, 0.5));
      expect(rect.right, lessThanOrEqualTo(844.5));
      expect(rect.bottom, lessThanOrEqualTo(390.5));
    });

    testWidgets('large tablet landscape', (WidgetTester tester) async {
      await pumpScreen(tester, const Size(1280, 720));

      expect(tester.takeException(), isNull);
      final rect = boardScreenRect(tester);
      expect(rect.width, closeTo(rect.height, 0.5));
      expect(rect.bottom, lessThanOrEqualTo(720.5));
    });
  });

  testWidgets('rotating the device live keeps the board square and the match',
      (WidgetTester tester) async {
    await pumpScreen(tester, const Size(390, 844));

    await tester.tap(find.byKey(const ValueKey('snakes_and_ladders_die')));
    await settle(tester);

    final portrait = boardScreenRect(tester);
    expect(portrait.width, closeTo(portrait.height, 0.5));

    // The user physically turns the phone sideways.
    tester.view.physicalSize = const Size(844, 390);
    await settle(tester);

    final landscape = boardScreenRect(tester);
    expect(landscape.width, closeTo(landscape.height, 0.5));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('snakes_and_ladders_token_blue')),
        findsOneWidget,
        reason: 'the match survived the rotation');
  });
}
