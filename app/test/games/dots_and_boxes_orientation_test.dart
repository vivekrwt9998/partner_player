import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/dots_and_boxes/dots_and_boxes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for AGENTS.md §8 and Dots and Boxes's
/// `fixedPortrait` composition.
///
/// The grid is taller than it is wide, which is exactly the shape that
/// tempts a game-level rotation. It must instead fit itself to whatever
/// space it is given.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> pumpScreen(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: DotsAndBoxesScreen(mode: GameMode.local)),
    );
    await settle(tester);
  }

  Rect boardScreenRect(WidgetTester tester) =>
      tester.getRect(find.byKey(const ValueKey('dots_and_boxes_board')));

  testWidgets(
      'opening and leaving Dots and Boxes never calls setPreferredOrientations',
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
                builder: (_) => const DotsAndBoxesScreen(mode: GameMode.local),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(DotsAndBoxesScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(DotsAndBoxesScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(DotsAndBoxesScreen), findsNothing);

    final orientationCalls = calls
        .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
        .toList();
    expect(
      orientationCalls,
      isEmpty,
      reason: 'a tall board is not a reason to turn the phone over.',
    );
  });

  group('the board fits whatever space it is given', () {
    testWidgets('portrait phone', (WidgetTester tester) async {
      await pumpScreen(tester, const Size(390, 844));

      expect(tester.takeException(), isNull);
      final rect = boardScreenRect(tester);
      expect(rect.height, greaterThan(rect.width));
      expect(rect.right, lessThanOrEqualTo(390.5));
      expect(rect.bottom, lessThanOrEqualTo(844.5));
    });

    testWidgets('landscape phone', (WidgetTester tester) async {
      await pumpScreen(tester, const Size(844, 390));

      expect(tester.takeException(), isNull);
      final rect = boardScreenRect(tester);
      expect(rect.height, greaterThan(rect.width),
          reason: 'the grid keeps its own shape, narrower rather than rotated');
      expect(rect.right, lessThanOrEqualTo(844.5));
      expect(rect.bottom, lessThanOrEqualTo(390.5));
    });

    testWidgets('large tablet landscape', (WidgetTester tester) async {
      await pumpScreen(tester, const Size(1280, 720));

      expect(tester.takeException(), isNull);
      final rect = boardScreenRect(tester);
      expect(rect.height, greaterThan(rect.width));
      expect(rect.bottom, lessThanOrEqualTo(720.5));
    });
  });

  testWidgets('rotating the device live keeps the match',
      (WidgetTester tester) async {
    await pumpScreen(tester, const Size(390, 844));

    await tester.tap(find.byKey(const ValueKey('dab_edge_h_0_0')));
    await settle(tester);

    tester.view.physicalSize = const Size(844, 390);
    await settle(tester);

    expect(tester.takeException(), isNull);
    final opacity = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('RED'),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(opacity.opacity, 1.0, reason: 'still Red to draw after the turn');
  });
}
