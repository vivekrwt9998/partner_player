import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/checkers/checkers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Regression tests for AGENTS.md §8 and Checkers' `fixedPortrait`
// composition.
//
// Like Tic Tac Toe's board, an 8x8 checkerboard is square, so it reads the
// same whether the physical device is portrait or landscape: this screen
// never needs a software pixel rotation trick, it only ever aspect-fits
// the same composition to whatever space it is given.

/// A bounded stand-in for `pumpAndSettle()`: the board's "you can move
/// this" sparkle ring animates forever by design, so `pumpAndSettle()`
/// itself would never see the frame queue go idle and would time out.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  Future<void> pumpScreen(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: CheckersScreen(mode: GameMode.local)),
    );
    await _settle(tester);
  }

  Rect boardScreenRect(WidgetTester tester) {
    return tester.getRect(find.byKey(const ValueKey('checkers_board')));
  }

  testWidgets(
      'opening and leaving Checkers never calls setPreferredOrientations',
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
                builder: (_) => const CheckersScreen(mode: GameMode.local),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await _settle(tester);
    expect(find.byType(CheckersScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(CheckersScreen))).pop();
    await _settle(tester);
    expect(find.byType(CheckersScreen), findsNothing);

    final orientationCalls = calls
        .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
        .toList();
    expect(
      orientationCalls,
      isEmpty,
      reason: 'Checkers must not force a physical device rotation; a '
          'square board never needs one.',
    );
  });

  group('the square board fits the screen regardless of device orientation', () {
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

  testWidgets(
      'rotating the device live keeps the board square, with no restart',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: CheckersScreen(mode: GameMode.local)),
    );
    await _settle(tester);

    final portraitRect = boardScreenRect(tester);
    expect(portraitRect.width, closeTo(portraitRect.height, 0.5));

    // The user physically turns the phone sideways.
    tester.view.physicalSize = const Size(844, 390);
    await _settle(tester);

    final landscapeRect = boardScreenRect(tester);
    expect(landscapeRect.width, closeTo(landscapeRect.height, 0.5));
    expect(tester.takeException(), isNull);
  });
}
