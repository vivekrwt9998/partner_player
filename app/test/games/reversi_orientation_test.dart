import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/reversi/reversi_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for AGENTS.md §8 and Reversi's `fixedPortrait`
/// composition.
///
/// An 8x8 board is square, so it reads the same whether the physical
/// device is portrait or landscape: this screen never needs a software
/// pixel rotation trick, it only ever aspect-fits the same composition to
/// whatever space it is given.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> pumpScreen(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: ReversiScreen(mode: GameMode.local)),
    );
    await settle(tester);
  }

  Rect boardScreenRect(WidgetTester tester) =>
      tester.getRect(find.byKey(const ValueKey('reversi_board')));

  testWidgets('opening and leaving Reversi never calls setPreferredOrientations',
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
    // rotation for a "portrait" game.
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
                builder: (_) => const ReversiScreen(mode: GameMode.local),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(ReversiScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(ReversiScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(ReversiScreen), findsNothing);

    final orientationCalls = calls
        .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
        .toList();
    expect(
      orientationCalls,
      isEmpty,
      reason: 'Reversi must not force a physical device rotation; a square '
          'board never needs one.',
    );
  });

  group('the square board fits the screen regardless of device orientation',
      () {
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
    });
  });

  testWidgets('rotating the device live keeps the board square and the match',
      (WidgetTester tester) async {
    await pumpScreen(tester, const Size(390, 844));

    await tester.tap(find.byKey(const ValueKey('reversi_cell_2_3')));
    await settle(tester);

    final portraitRect = boardScreenRect(tester);
    expect(portraitRect.width, closeTo(portraitRect.height, 0.5));

    // The user physically turns the phone sideways.
    tester.view.physicalSize = const Size(844, 390);
    await settle(tester);

    final landscapeRect = boardScreenRect(tester);
    expect(landscapeRect.width, closeTo(landscapeRect.height, 0.5));
    expect(tester.takeException(), isNull);

    final blueScore = tester
        .widget<Text>(find.byKey(const ValueKey('reversi_score_blue')))
        .data;
    expect(blueScore, '4', reason: 'the match survived the rotation');
  });
}
