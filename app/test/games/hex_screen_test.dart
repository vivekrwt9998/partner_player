import 'dart:math' as math;

import 'package:app/games/hex/logic/hex_game.dart';
import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/hex/hex_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String _blueStone = 'blue';
const String _redStone = 'red';

/// The board keeps a 17 : 16*sqrt(3) outline whatever it is fitted into.
final double _boardAspect = 17 / (16 * math.sqrt(3));

/// Walks the clock past the stone-landing animation.
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

  await tester.pumpWidget(MaterialApp(home: HexScreen(mode: mode)));
  await _settle(tester);
}

Finder _cell(int row, int col) => find.byKey(ValueKey('hex_cell_${row}_$col'));

/// Whose stone is sitting in a cell, or null when it is empty. The
/// stone is painted rather than decorated, so its owner is read off its
/// key instead of out of a painter.
String? _stoneColourAt(WidgetTester tester, int row, int col) {
  for (final side in const [_blueStone, _redStone]) {
    final stone = find.byKey(ValueKey('hex_stone_${side}_${row}_$col'));
    if (stone.evaluate().isNotEmpty) return side;
  }
  return null;
}

double _opacityOfLabel(WidgetTester tester, String label) {
  final opacity = tester.widget<AnimatedOpacity>(
    find.ancestor(of: find.text(label), matching: find.byType(AnimatedOpacity)),
  );
  return opacity.opacity;
}

void main() {
  testWidgets('renders a tap target for all 121 cells',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(find.byKey(const ValueKey('hex_board')), findsOneWidget);
    expect(HexGame.size, 11);
    for (var row = 0; row < HexGame.size; row++) {
      for (var col = 0; col < HexGame.size; col++) {
        expect(_cell(row, col), findsOneWidget);
      }
    }
  });

  testWidgets('the board keeps its rhombus shape and fits the screen',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final board = tester.getRect(find.byKey(const ValueKey('hex_board')));

    expect(board.width / board.height, closeTo(_boardAspect, 0.01));
    expect(board.height, greaterThan(board.width),
        reason: 'the rhombus is stood up tall, to fill a portrait screen');
    expect(board.left, greaterThanOrEqualTo(-0.5));
    expect(board.top, greaterThanOrEqualTo(-0.5));
    expect(board.right, lessThanOrEqualTo(390.5));
    expect(board.bottom, lessThanOrEqualTo(844.5));
  });

  testWidgets('starts on Blue with an empty board',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(_opacityOfLabel(tester, 'BLUE'), 1.0);
    expect(_opacityOfLabel(tester, 'RED'), 0.0);
    expect(_stoneColourAt(tester, 5, 5), isNull);
  });

  testWidgets('placing a stone shows it and passes the turn',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_cell(5, 5));
    await _settle(tester);

    expect(_stoneColourAt(tester, 5, 5), _blueStone);
    expect(_opacityOfLabel(tester, 'RED'), 1.0);
    expect(_opacityOfLabel(tester, 'BLUE'), 0.0);

    await tester.tap(_cell(5, 6));
    await _settle(tester);

    expect(_stoneColourAt(tester, 5, 6), _redStone);
    expect(_stoneColourAt(tester, 5, 5), _blueStone,
        reason: 'a Hex stone is never taken or turned over');
    expect(_opacityOfLabel(tester, 'BLUE'), 1.0);
  });

  testWidgets('a stone is a hexagon, not a disc',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_cell(5, 5));
    await _settle(tester);

    final circles = tester
        .widgetList<DecoratedBox>(
          find.descendant(of: _cell(5, 5), matching: find.byType(DecoratedBox)),
        )
        .where((box) =>
            box.decoration is BoxDecoration &&
            (box.decoration as BoxDecoration).shape == BoxShape.circle);

    expect(circles, isEmpty,
        reason: 'the stone fills its cell rather than sitting on it');
  });

  testWidgets('both pairs of sides keep breathing, whoever is to play',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(find.byKey(const ValueKey('hex_sides_pulsing')), findsOneWidget);

    await tester.tap(_cell(5, 5));
    await _settle(tester);
    expect(find.byKey(const ValueKey('hex_sides_pulsing')), findsOneWidget,
        reason: 'the turn changing does not quiet either side');
  });

  testWidgets('the sides go still once the game has been won',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    for (var col = 0; col < HexGame.size; col++) {
      await tester.tap(_cell(5, col));
      await _settle(tester);
      if (col == HexGame.size - 1) break;
      await tester.tap(_cell(0, col));
      await _settle(tester);
    }

    expect(find.byKey(const ValueKey('hex_sides_still')), findsOneWidget,
        reason: 'the winning chain is what should hold the eye now');
  });

  testWidgets('a cell that is already taken cannot be taken again',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_cell(2, 2));
    await _settle(tester);
    await tester.tap(_cell(2, 2));
    await _settle(tester);

    expect(_stoneColourAt(tester, 2, 2), _blueStone);
    expect(_opacityOfLabel(tester, 'RED'), 1.0,
        reason: 'the second tap was refused, so it is still Red');
  });

  testWidgets('the other player cannot play while the stone is still landing',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_cell(0, 0));
    await tester.pump(const Duration(milliseconds: 60));

    await tester.tap(_cell(0, 1));
    await _settle(tester);

    expect(_stoneColourAt(tester, 0, 1), isNull);
    expect(_opacityOfLabel(tester, 'RED'), 1.0,
        reason: 'the second tap was ignored, so it is still Red to play');
  });

  testWidgets('joining the two straight sides wins it for Blue',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    // Blue walks straight across row 5 while Red fills row 0 behind it,
    // which goes nowhere: Red has to join the top row to the bottom.
    for (var col = 0; col < HexGame.size; col++) {
      await tester.tap(_cell(5, col));
      await _settle(tester);
      if (col == HexGame.size - 1) break;

      await tester.tap(_cell(0, col));
      await _settle(tester);
    }

    expect(_stoneColourAt(tester, 5, HexGame.size - 1), _blueStone);

    // Past the win highlight and the hold before the result screen.
    await _settle(tester);
    expect(find.text('BLUE PLAYER\nWINS!'), findsOneWidget);
  });

  testWidgets('the whole winning chain pulses at once',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    for (var col = 0; col < HexGame.size; col++) {
      await tester.tap(_cell(5, col));
      // The winning tap is left unsettled: what follows is the pulse,
      // and settling would walk straight past it.
      if (col == HexGame.size - 1) break;
      await _settle(tester);
      await tester.tap(_cell(0, col));
      await _settle(tester);
    }

    // The first pump only starts the clock -- a ticker reports nothing
    // elapsed on its opening tick -- so the one after it is what lands
    // partway into the dip.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final scales = <double>[];
    for (var col = 0; col < HexGame.size; col++) {
      final scaled = find.ancestor(
        of: find.byKey(ValueKey('hex_stone_blue_5_$col')),
        matching: find.byType(Transform),
      );
      expect(scaled, findsWidgets, reason: 'every stone on the line animates');
      scales.add(tester.widget<Transform>(scaled.first).transform[0]);
    }

    expect(scales, hasLength(HexGame.size));
    expect(scales.reduce(math.min), lessThan(0.8),
        reason: 'the chain visibly shrinks');
    expect(scales.reduce(math.max) - scales.reduce(math.min), lessThan(0.01),
        reason: 'the whole line is the same size at the same moment, '
            'rather than lighting up one end to the other');
  });

  testWidgets('a tap in the overlap goes to the hexagon under the finger',
      (WidgetTester tester) async {
    // Neighbouring hexagons have overlapping bounding boxes, so a cell
    // that accepted its whole box would steal taps from the cell next
    // to it. This picks a point inside (3,4) that also lies inside
    // (3,3)'s box, and insists the stone lands in (3,4).
    await _pumpGameScreen(tester);

    final board = tester.getRect(find.byKey(const ValueKey('hex_board')));
    final radius = board.width / 17;
    Offset centreOf(int row, int col) => board.topLeft +
        Offset(
          radius + (1.5 * radius * col),
          math.sqrt(3) * radius * (0.5 + row + (col / 2)),
        );

    final neighbour = centreOf(3, 4);
    final point = neighbour + Offset(-0.85 * radius, -0.1 * radius);

    // Sanity: the point really is inside (3,3)'s bounding box, so this
    // is a genuine overlap and not a trivially safe tap.
    final ownBox = Rect.fromCenter(
      center: centreOf(3, 3),
      width: radius * 2,
      height: math.sqrt(3) * radius,
    );
    expect(ownBox.contains(point), isTrue);

    await tester.tapAt(point);
    await _settle(tester);

    expect(_stoneColourAt(tester, 3, 4), _blueStone);
    expect(_stoneColourAt(tester, 3, 3), isNull,
        reason: 'the neighbour must not swallow the tap');
  });

  testWidgets('options menu offers Revert, Restart and Exit',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await _settle(tester);

    expect(find.text('Revert'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Exit Game'), findsOneWidget);
  });

  testWidgets('Revert lifts the last stone back off',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_cell(4, 4));
    await _settle(tester);
    await tester.tap(_cell(4, 5));
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await _settle(tester);
    await tester.tap(find.text('Revert'));
    await _settle(tester);

    expect(_stoneColourAt(tester, 4, 5), isNull);
    expect(_stoneColourAt(tester, 4, 4), _blueStone,
        reason: 'only the last stone goes');
    expect(_opacityOfLabel(tester, 'RED'), 1.0);
  });

  group('Bot mode', () {
    testWidgets('never offers Revert', (WidgetTester tester) async {
      await _pumpGameScreen(tester, mode: GameMode.bot);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await _settle(tester);

      expect(find.text('Revert'), findsNothing);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Exit Game'), findsOneWidget);
    });

    testWidgets('the bot holds off until the stone has landed',
        (WidgetTester tester) async {
      await _pumpGameScreen(tester, mode: GameMode.bot);

      await tester.tap(_cell(5, 5));
      // Past the bot's think delay but short of the stone finishing:
      // a reply landing here is the flicker.
      await tester.pump(const Duration(milliseconds: 100));

      expect(_opacityOfLabel(tester, 'RED'), 1.0,
          reason: 'still the bot to play, it has not gone yet');

      await _settle(tester);
      expect(_opacityOfLabel(tester, 'BLUE'), 1.0,
          reason: 'once it settles the bot does answer');
    });
  });

  testWidgets('Restart clears the board', (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_cell(1, 1));
    await _settle(tester);
    expect(_opacityOfLabel(tester, 'RED'), 1.0);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await _settle(tester);
    await tester.tap(find.text('Restart'));
    await _settle(tester);

    expect(_stoneColourAt(tester, 1, 1), isNull);
    expect(_opacityOfLabel(tester, 'BLUE'), 1.0);
  });
}
