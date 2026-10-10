import 'package:app/games/dots_and_boxes/logic/dots_and_boxes_game.dart';
import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/dots_and_boxes/dots_and_boxes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Walks the clock past the line-drawing animation.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _pumpGameScreen(
  WidgetTester tester, {
  GameMode mode = GameMode.local,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: DotsAndBoxesScreen(mode: mode)));
  await _settle(tester);
}

Finder _horizontal(int row, int col) =>
    find.byKey(ValueKey('dab_edge_h_${row}_$col'));

Finder _vertical(int row, int col) =>
    find.byKey(ValueKey('dab_edge_v_${row}_$col'));

String _score(WidgetTester tester, String side) => tester
    .widget<Text>(find.byKey(ValueKey('dots_and_boxes_score_$side')))
    .data!;

double _opacityOfLabel(WidgetTester tester, String label) {
  final opacity = tester.widget<AnimatedOpacity>(
    find.ancestor(of: find.text(label), matching: find.byType(AnimatedOpacity)),
  );
  return opacity.opacity;
}

void main() {
  testWidgets('renders a tap target for every line on the board',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(find.byKey(const ValueKey('dots_and_boxes_board')), findsOneWidget);
    for (var row = 0; row < DotsAndBoxesGame.dotRows; row++) {
      for (var col = 0; col < DotsAndBoxesGame.boxColumns; col++) {
        expect(_horizontal(row, col), findsOneWidget);
      }
    }
    for (var row = 0; row < DotsAndBoxesGame.boxRows; row++) {
      for (var col = 0; col < DotsAndBoxesGame.dotColumns; col++) {
        expect(_vertical(row, col), findsOneWidget);
      }
    }
  });

  testWidgets('the board is 6 dots across and 9 down, and fits the screen',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(DotsAndBoxesGame.dotColumns, 6);
    expect(DotsAndBoxesGame.dotRows, 9);

    final board =
        tester.getRect(find.byKey(const ValueKey('dots_and_boxes_board')));
    expect(board.height, greaterThan(board.width),
        reason: 'taller than it is wide, like the grid');
    expect(board.right, lessThanOrEqualTo(390.5));
    expect(board.bottom, lessThanOrEqualTo(844.5));
  });

  testWidgets('starts on Blue with an empty scoreboard',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(_opacityOfLabel(tester, 'BLUE'), 1.0);
    expect(_opacityOfLabel(tester, 'RED'), 0.0);
    expect(_score(tester, 'blue'), '0');
    expect(_score(tester, 'red'), '0');
  });

  testWidgets('drawing a line passes the turn', (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_horizontal(0, 0));
    await _settle(tester);

    expect(_opacityOfLabel(tester, 'RED'), 1.0);
    expect(_opacityOfLabel(tester, 'BLUE'), 0.0);
    expect(_score(tester, 'blue'), '0', reason: 'no box closed yet');
  });

  testWidgets('a line already drawn cannot be drawn again',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_horizontal(0, 0));
    await _settle(tester);
    await tester.tap(_horizontal(0, 0));
    await _settle(tester);

    expect(_opacityOfLabel(tester, 'RED'), 1.0,
        reason: 'the second tap was refused, so it is still Red');
  });

  testWidgets('closing a box scores it and keeps the turn',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    // Blue, Red, Blue lay three sides; Red closes the box and goes again.
    await tester.tap(_horizontal(0, 0));
    await _settle(tester);
    await tester.tap(_vertical(0, 0));
    await _settle(tester);
    await tester.tap(_vertical(0, 1));
    await _settle(tester);

    expect(_opacityOfLabel(tester, 'RED'), 1.0);
    await tester.tap(_horizontal(1, 0));
    await _settle(tester);

    expect(_score(tester, 'red'), '1');
    expect(_opacityOfLabel(tester, 'RED'), 1.0,
        reason: 'closing a box earns another line');
  });

  testWidgets('the other player cannot draw while the line is still growing',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_horizontal(0, 0));
    await tester.pump(const Duration(milliseconds: 80));

    await tester.tap(_vertical(0, 0));
    await _settle(tester);

    expect(_opacityOfLabel(tester, 'RED'), 1.0,
        reason: 'the second line was ignored, so it is still Red to draw');
  });

  testWidgets('options menu offers Revert, Restart and Exit',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Revert'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Exit Game'), findsOneWidget);
  });

  group('Bot mode', () {
    testWidgets('never offers Revert', (WidgetTester tester) async {
      await _pumpGameScreen(tester, mode: GameMode.bot);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Revert'), findsNothing);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Exit Game'), findsOneWidget);
    });

    testWidgets('the bot holds off until the line has finished drawing',
        (WidgetTester tester) async {
      await _pumpGameScreen(tester, mode: GameMode.bot);

      await tester.tap(_horizontal(0, 0));
      // Past the bot's think delay but well short of the line finishing:
      // a reply landing here is the flicker.
      await tester.pump(const Duration(milliseconds: 150));

      expect(_opacityOfLabel(tester, 'RED'), 1.0,
          reason: 'still the bot to draw, it has not gone yet');

      await _settle(tester);
      expect(_opacityOfLabel(tester, 'BLUE'), 1.0,
          reason: 'once it settles the bot does answer');
    });
  });

  testWidgets('Restart clears the board', (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_horizontal(0, 0));
    await _settle(tester);
    expect(_opacityOfLabel(tester, 'RED'), 1.0);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restart'));
    await _settle(tester);

    expect(_opacityOfLabel(tester, 'BLUE'), 1.0);
    expect(_score(tester, 'blue'), '0');
  });
}
