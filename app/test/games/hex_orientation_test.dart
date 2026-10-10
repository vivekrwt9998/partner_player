import 'dart:math' as math;

import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/hex/hex_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for AGENTS.md §8 and Hex's `fixedPortrait`
/// composition.
///
/// Unlike the square boards on this platform, the Hex rhombus has a
/// shape of its own -- 17 : 16*sqrt(3) -- which it has to keep whatever
/// it is fitted into. It never rotates pixels and never touches the
/// device orientation; it only ever aspect-fits the same composition to
/// whatever space it is given.
void main() {
  final boardAspect = 17 / (16 * math.sqrt(3));

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
      const MaterialApp(home: HexScreen(mode: GameMode.local)),
    );
    await settle(tester);
  }

  Rect boardScreenRect(WidgetTester tester) =>
      tester.getRect(find.byKey(const ValueKey('hex_board')));

  bool hasBlueStoneAt(WidgetTester tester, int row, int col) => find
      .byKey(ValueKey('hex_stone_blue_${row}_$col'))
      .evaluate()
      .isNotEmpty;

  testWidgets('opening and leaving Hex never calls setPreferredOrientations',
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
    // rotation for a tall board.
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
                builder: (_) => const HexScreen(mode: GameMode.local),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await settle(tester);
    expect(find.byType(HexScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(HexScreen))).pop();
    await settle(tester);
    expect(find.byType(HexScreen), findsNothing);

    final orientationCalls = calls
        .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
        .toList();
    expect(
      orientationCalls,
      isEmpty,
      reason: 'Hex must not force a physical device rotation; a tall board '
          'is a layout shape, not a device orientation.',
    );
  });

  group('the rhombus keeps its shape regardless of device orientation', () {
    testWidgets('portrait phone', (WidgetTester tester) async {
      await pumpScreen(tester, const Size(390, 844));

      expect(tester.takeException(), isNull);
      final rect = boardScreenRect(tester);
      expect(rect.width / rect.height, closeTo(boardAspect, 0.01));
      expect(rect.right, lessThanOrEqualTo(390.5));
      expect(rect.bottom, lessThanOrEqualTo(844.5));
    });

    testWidgets('landscape phone', (WidgetTester tester) async {
      await pumpScreen(tester, const Size(844, 390));

      expect(tester.takeException(), isNull);
      final rect = boardScreenRect(tester);
      expect(rect.width / rect.height, closeTo(boardAspect, 0.01));
      expect(rect.right, lessThanOrEqualTo(844.5));
      expect(rect.bottom, lessThanOrEqualTo(390.5));
    });

    testWidgets('large tablet landscape', (WidgetTester tester) async {
      await pumpScreen(tester, const Size(1280, 720));

      expect(tester.takeException(), isNull);
      final rect = boardScreenRect(tester);
      expect(rect.width / rect.height, closeTo(boardAspect, 0.01));
      expect(rect.right, lessThanOrEqualTo(1280.5));
      expect(rect.bottom, lessThanOrEqualTo(720.5));
    });
  });

  testWidgets('rotating the device live keeps the shape and the match',
      (WidgetTester tester) async {
    await pumpScreen(tester, const Size(390, 844));

    await tester.tap(find.byKey(const ValueKey('hex_cell_2_3')));
    await settle(tester);
    expect(hasBlueStoneAt(tester, 2, 3), isTrue);

    final portraitRect = boardScreenRect(tester);
    expect(portraitRect.width / portraitRect.height,
        closeTo(boardAspect, 0.01));

    // The user physically turns the phone sideways.
    tester.view.physicalSize = const Size(844, 390);
    await settle(tester);

    final landscapeRect = boardScreenRect(tester);
    expect(
        landscapeRect.width / landscapeRect.height, closeTo(boardAspect, 0.01));
    expect(landscapeRect.height, lessThan(portraitRect.height),
        reason: 'it shrinks to fit rather than cropping');
    expect(tester.takeException(), isNull);

    expect(hasBlueStoneAt(tester, 2, 3), isTrue,
        reason: 'the match survived the rotation');
  });
}
