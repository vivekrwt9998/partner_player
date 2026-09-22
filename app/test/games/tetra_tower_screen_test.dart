import 'dart:math';

import 'package:app/games/tetra_tower/logic/tetra_tower_game.dart';
import 'package:app/games/tetra_tower/models/tetra_tower_models.dart';
import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/tetra_tower/tetra_tower_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fixed seed makes every piece the game hands out fully predictable
/// (verified out-of-band, same sequence used by the engine's own tests):
/// Player 1 is given a T (fits at anchor (0,0)), then Player 2 an S (fits
/// at (1,1), and starts floor 2 since nothing else fits floor 1 afterwards).
TetraTowerGame _seededGame() => TetraTowerGame(random: Random(1));

Future<TetraTowerGame> _pumpGameScreen(
  WidgetTester tester, {
  GameMode mode = GameMode.local,
}) async {
  final game = _seededGame();
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(home: TetraTowerScreen(mode: mode, debugGame: game)),
  );
  await tester.pumpAndSettle();
  return game;
}

Finder _cell(int row, int col) => find.byKey(ValueKey('tetra_tower_cell_${row}_$col'));

double _opacityOfLabel(WidgetTester tester, String label) {
  final opacity = tester.widget<AnimatedOpacity>(
    find.ancestor(of: find.text(label), matching: find.byType(AnimatedOpacity)),
  );
  return opacity.opacity;
}

void main() {
  testWidgets('renders the first floor, empty grid, and Blue holding the first piece',
      (WidgetTester tester) async {
    final game = await _pumpGameScreen(tester);

    expect(find.text('FLOOR 1'), findsOneWidget);
    expect(find.text('STABILITY'), findsOneWidget);
    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
    expect(_opacityOfLabel(tester, 'RED TURN'), 0.0);
    expect(game.currentShape, TetrominoShape.t);
    expect(game.moveCount, 0);
  });

  testWidgets('tapping a legal cell places the current piece and switches turns',
      (WidgetTester tester) async {
    final game = await _pumpGameScreen(tester);

    await tester.tap(_cell(0, 0));
    await tester.pumpAndSettle();

    expect(game.moveCount, 1);
    expect(game.getCell(0, 0, 0), TetraTowerPlayer.player1);
    expect(game.currentPlayer, TetraTowerPlayer.player2);
    expect(_opacityOfLabel(tester, 'RED TURN'), 1.0);
    expect(_opacityOfLabel(tester, 'BLUE TURN'), 0.0);
  });

  testWidgets('tapping the rotate button cycles the current piece\'s rotation',
      (WidgetTester tester) async {
    final game = await _pumpGameScreen(tester);

    expect(game.currentRotationIndex, 0);
    await tester.tap(find.byIcon(Icons.rotate_right_rounded));
    await tester.pumpAndSettle();

    expect(game.currentRotationIndex, 1);
    expect(game.moveCount, 0, reason: 'rotating must not consume the turn');
  });

  testWidgets('options menu lists Revert, Restart and Exit in order',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Revert'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Exit Game'), findsOneWidget);

    final revertY = tester.getRect(find.text('Revert')).top;
    final restartY = tester.getRect(find.text('Restart')).top;
    final exitY = tester.getRect(find.text('Exit Game')).top;
    expect(revertY, lessThan(restartY));
    expect(restartY, lessThan(exitY));
  });

  testWidgets('tapping outside the open options menu dismisses it without acting',
      (WidgetTester tester) async {
    final game = await _pumpGameScreen(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Restart'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('Restart'), findsNothing);
    expect(game.moveCount, 0);
    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
  });

  testWidgets('Restart from the options menu resets the tower',
      (WidgetTester tester) async {
    final game = await _pumpGameScreen(tester);

    await tester.tap(_cell(0, 0));
    await tester.pumpAndSettle();
    expect(game.moveCount, 1);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();

    expect(game.moveCount, 0);
    expect(game.layers.length, 1);
    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
  });

  testWidgets('Revert from the options menu undoes the last placement',
      (WidgetTester tester) async {
    final game = await _pumpGameScreen(tester);

    await tester.tap(_cell(0, 0));
    await tester.pumpAndSettle();
    expect(game.moveCount, 1);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revert'));
    await tester.pumpAndSettle();

    expect(game.moveCount, 0);
    expect(game.getCell(0, 0, 0), isNull);
    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
  });
}
