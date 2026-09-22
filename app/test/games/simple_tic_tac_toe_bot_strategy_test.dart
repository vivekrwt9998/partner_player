import 'package:app/games/tic_tac_toe/bot/simple_tic_tac_toe_bot_strategy.dart';
import 'package:app/games/tic_tac_toe/logic/tic_tac_toe_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final strategy = SimpleTicTacToeBotStrategy();

  test('prefers the center cell on an empty board', () {
    expect(strategy.chooseCell(TicTacToeGame()), (1, 1));
  });

  test('takes an immediate winning move', () {
    final game = TicTacToeGame();
    // P1: (0,0), (0,1). P2 (bot): (1,0), (1,1) -- one move from winning row 1.
    for (final move in [(0, 0), (1, 0), (0, 1), (1, 1)]) {
      game.tryPlaceMark(move.$1, move.$2);
    }

    expect(strategy.chooseCell(game), (1, 2));
  });

  test('blocks an immediate Blue winning move', () {
    final game = TicTacToeGame();
    // P1: (0,0), (0,1) -- one move from winning row 0. P2 only has the center.
    for (final move in [(0, 0), (1, 1), (0, 1)]) {
      game.tryPlaceMark(move.$1, move.$2);
    }

    expect(strategy.chooseCell(game), (0, 2));
  });

  test('never selects an already-occupied preferred cell', () {
    final game = TicTacToeGame();
    game.tryPlaceMark(1, 1); // P1 takes the center.

    final cell = strategy.chooseCell(game);
    expect(cell, isNotNull);
    expect(cell, isNot((1, 1)));
    expect(game.getCell(cell!.$1, cell.$2), isNull);
  });

  test('returns null after a terminal game', () {
    final game = TicTacToeGame();
    for (final move in [(0, 0), (1, 0), (0, 1), (1, 1), (0, 2)]) {
      game.tryPlaceMark(move.$1, move.$2);
    }
    expect(game.isGameOver, isTrue);

    expect(strategy.chooseCell(game), isNull);
  });
}
