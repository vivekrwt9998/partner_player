import 'package:app/games/checkers/bot/simple_checkers_bot_strategy.dart';
import 'package:app/games/checkers/logic/checkers_game.dart';
import 'package:app/games/checkers/models/checkers_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final strategy = SimpleCheckersBotStrategy();

  test('returns a legal move for the current player on the opening position', () {
    final game = CheckersGame();
    final move = strategy.chooseMove(game);

    expect(move, isNotNull);
    expect(game.tryMove(move!.$1, move.$2, move.$3, move.$4), isNotNull);
  });

  test('never mutates the game while choosing', () {
    final game = CheckersGame();
    strategy.chooseMove(game);

    expect(game.moveCount, 0);
    expect(game.currentPlayer, CheckersPlayer.player1);
    expect(game.getCell(5, 0), isNotNull);
    expect(game.canRevert, isFalse);
  });

  test('takes the only legal move when a capture is forced', () {
    final game = CheckersGame();
    // Reproduces the same forced-capture position covered in
    // checkers_game_test.dart: after these 3 moves, Player 2's (2,3) is the
    // only piece with a legal move at all (a forced capture landing at (4,1)).
    game.tryMove(5, 0, 4, 1);
    game.tryMove(2, 1, 3, 0);
    game.tryMove(4, 1, 3, 2);
    expect(game.currentPlayer, CheckersPlayer.player2);

    final move = strategy.chooseMove(game);
    expect(move, (2, 3, 4, 1));
  });

  test('returns null once the game has ended', () {
    final game = CheckersGame();
    const playthrough = [
      (5, 0, 4, 1), (2, 1, 3, 0), (4, 1, 3, 2), (2, 3, 4, 1), (5, 2, 4, 3),
      (1, 0, 2, 1), (4, 3, 3, 2), (2, 1, 4, 3), (5, 4, 3, 2), (0, 1, 1, 0),
      (3, 2, 2, 1), (1, 0, 3, 2), (5, 6, 4, 5), (1, 2, 2, 1), (4, 5, 3, 4),
      (2, 5, 4, 3), (6, 1, 5, 0), (0, 3, 1, 2), (6, 3, 5, 2), (4, 1, 6, 3),
      (7, 2, 5, 4), (1, 2, 2, 3), (5, 0, 4, 1), (3, 0, 5, 2), (5, 4, 4, 5),
      (1, 4, 2, 5), (4, 5, 3, 4), (2, 3, 4, 5), (6, 5, 5, 4), (4, 3, 6, 5),
      (7, 4, 5, 6), (5, 6, 3, 4), (2, 5, 4, 3), (6, 7, 5, 6), (0, 5, 1, 4),
      (5, 6, 4, 5), (1, 4, 2, 3), (4, 5, 3, 4), (2, 3, 4, 5), (7, 0, 6, 1),
      (5, 2, 7, 0), (7, 6, 6, 5), (1, 6, 2, 5), (6, 5, 5, 4), (4, 3, 6, 5),
    ];
    for (final m in playthrough) {
      game.tryMove(m.$1, m.$2, m.$3, m.$4);
      if (game.isGameOver) break;
    }
    expect(game.isGameOver, isTrue);

    expect(strategy.chooseMove(game), isNull);
  });
}
