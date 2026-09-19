import 'package:flutter_test/flutter_test.dart';
import 'package:app/games/tic_tac_toe/logic/tic_tac_toe_game.dart';
import 'package:app/games/tic_tac_toe/models/tic_tac_toe_models.dart';

void main() {
  group('TicTacToeGame - Board Initialization', () {
    test('starts with an empty 3x3 board', () {
      final game = TicTacToeGame();

      expect(TicTacToeGame.rows, 3);
      expect(TicTacToeGame.cols, 3);
      expect(game.board.length, 3);
      for (int r = 0; r < 3; r++) {
        expect(game.board[r].length, 3);
        for (int c = 0; c < 3; c++) {
          expect(game.getCell(r, c), isNull);
        }
      }
      expect(game.currentPlayer, TicTacToePlayer.player1);
      expect(game.status, TicTacToeGameStatus.playing);
      expect(game.winner, isNull);
      expect(game.winningPositions, isEmpty);
      expect(game.isGameOver, isFalse);
      expect(game.canRevert, isFalse);
      expect(game.moveCount, 0);
    });
  });

  group('TicTacToeGame - Move Mechanics', () {
    test('places a mark and alternates turns', () {
      final game = TicTacToeGame();

      final move1 = game.tryPlaceMark(1, 1);
      expect(move1, isNotNull);
      expect(move1!.player, TicTacToePlayer.player1);
      expect(move1.row, 1);
      expect(move1.col, 1);
      expect(move1.status, TicTacToeGameStatus.playing);
      expect(game.getCell(1, 1), TicTacToePlayer.player1);
      expect(game.currentPlayer, TicTacToePlayer.player2);
      expect(game.moveCount, 1);
      expect(game.canRevert, isTrue);

      final move2 = game.tryPlaceMark(0, 0);
      expect(move2, isNotNull);
      expect(move2!.player, TicTacToePlayer.player2);
      expect(game.getCell(0, 0), TicTacToePlayer.player2);
      expect(game.currentPlayer, TicTacToePlayer.player1);
      expect(game.moveCount, 2);
    });

    test('rejects placing on an occupied cell without changing turn or board', () {
      final game = TicTacToeGame();

      game.tryPlaceMark(1, 1); // P1
      final currentPlayerBefore = game.currentPlayer;
      final boardBefore = game.board.map((row) => List.of(row)).toList();

      final invalidMove = game.tryPlaceMark(1, 1);
      expect(invalidMove, isNull);
      expect(game.currentPlayer, currentPlayerBefore);
      expect(game.board, boardBefore);
    });

    test('rejects out of bounds cells', () {
      final game = TicTacToeGame();
      expect(game.tryPlaceMark(-1, 0), isNull);
      expect(game.tryPlaceMark(0, 3), isNull);
      expect(game.currentPlayer, TicTacToePlayer.player1);
    });
  });

  group('TicTacToeGame - Revert Capability', () {
    test('cannot revert on empty board', () {
      final game = TicTacToeGame();
      expect(game.canRevert, isFalse);
      expect(game.revert(), isFalse);
    });

    test('reverts last move and restores previous turn correctly', () {
      final game = TicTacToeGame();

      game.tryPlaceMark(1, 1); // P1
      expect(game.getCell(1, 1), TicTacToePlayer.player1);
      expect(game.currentPlayer, TicTacToePlayer.player2);

      final reverted = game.revert();
      expect(reverted, isTrue);
      expect(game.getCell(1, 1), isNull);
      expect(game.currentPlayer, TicTacToePlayer.player1);
      expect(game.canRevert, isFalse);
      expect(game.moveCount, 0);
    });

    test('reverting after a win restores playing state', () {
      final game = TicTacToeGame();

      // P1 wins on the top row.
      game.tryPlaceMark(0, 0); // P1
      game.tryPlaceMark(1, 0); // P2
      game.tryPlaceMark(0, 1); // P1
      game.tryPlaceMark(1, 1); // P2
      game.tryPlaceMark(0, 2); // P1 -> WIN!

      expect(game.status, TicTacToeGameStatus.won);
      expect(game.winner, TicTacToePlayer.player1);

      expect(game.revert(), isTrue);
      expect(game.status, TicTacToeGameStatus.playing);
      expect(game.winner, isNull);
      expect(game.winningPositions, isEmpty);
      expect(game.currentPlayer, TicTacToePlayer.player1);
      expect(game.getCell(0, 2), isNull);
    });
  });

  group('TicTacToeGame - Win Detection', () {
    test('detects horizontal win', () {
      final game = TicTacToeGame();

      game.tryPlaceMark(0, 0); // P1
      game.tryPlaceMark(1, 0); // P2
      game.tryPlaceMark(0, 1); // P1
      game.tryPlaceMark(1, 1); // P2
      game.tryPlaceMark(0, 2); // P1 -> WIN!

      expect(game.status, TicTacToeGameStatus.won);
      expect(game.winner, TicTacToePlayer.player1);
      expect(game.isGameOver, isTrue);
      expect(game.winningPositions.length, 3);
      expect(
        game.winningPositions,
        containsAll([
          const BoardPosition(0, 0),
          const BoardPosition(0, 1),
          const BoardPosition(0, 2),
        ]),
      );
    });

    test('detects vertical win', () {
      final game = TicTacToeGame();

      game.tryPlaceMark(0, 0); // P1
      game.tryPlaceMark(0, 1); // P2
      game.tryPlaceMark(1, 0); // P1
      game.tryPlaceMark(1, 1); // P2
      game.tryPlaceMark(2, 0); // P1 -> WIN!

      expect(game.status, TicTacToeGameStatus.won);
      expect(game.winner, TicTacToePlayer.player1);
      expect(
        game.winningPositions,
        containsAll([
          const BoardPosition(0, 0),
          const BoardPosition(1, 0),
          const BoardPosition(2, 0),
        ]),
      );
    });

    test('detects diagonal down-right (\\) win', () {
      final game = TicTacToeGame();

      game.tryPlaceMark(0, 0); // P1
      game.tryPlaceMark(0, 1); // P2
      game.tryPlaceMark(1, 1); // P1
      game.tryPlaceMark(0, 2); // P2
      game.tryPlaceMark(2, 2); // P1 -> WIN!

      expect(game.status, TicTacToeGameStatus.won);
      expect(game.winner, TicTacToePlayer.player1);
      expect(
        game.winningPositions,
        containsAll([
          const BoardPosition(0, 0),
          const BoardPosition(1, 1),
          const BoardPosition(2, 2),
        ]),
      );
    });

    test('detects diagonal up-right (/) win', () {
      final game = TicTacToeGame();

      game.tryPlaceMark(2, 0); // P1
      game.tryPlaceMark(0, 1); // P2
      game.tryPlaceMark(1, 1); // P1
      game.tryPlaceMark(1, 0); // P2
      game.tryPlaceMark(0, 2); // P1 -> WIN!

      expect(game.status, TicTacToeGameStatus.won);
      expect(game.winner, TicTacToePlayer.player1);
      expect(
        game.winningPositions,
        containsAll([
          const BoardPosition(2, 0),
          const BoardPosition(1, 1),
          const BoardPosition(0, 2),
        ]),
      );
    });

    test('does not trigger false positive on 2 connected marks', () {
      final game = TicTacToeGame();

      game.tryPlaceMark(0, 0); // P1
      game.tryPlaceMark(1, 0); // P2
      game.tryPlaceMark(0, 1); // P1

      expect(game.status, TicTacToeGameStatus.playing);
      expect(game.winner, isNull);
      expect(game.isGameOver, isFalse);
    });
  });

  group('TicTacToeGame - Draw and Game End', () {
    test('declares draw when board is completely full with no winner', () {
      final game = TicTacToeGame();

      // A deterministic filling of the board with no 3-in-a-row for either
      // player:
      // P1 O O
      // O  P1 P1
      // P1 P1 O
      const moves = [
        (0, 0), // P1
        (0, 1), // P2
        (1, 1), // P1
        (0, 2), // P2
        (1, 2), // P1
        (1, 0), // P2
        (2, 0), // P1
        (2, 2), // P2
        (2, 1), // P1
      ];

      for (final move in moves) {
        game.tryPlaceMark(move.$1, move.$2);
      }

      expect(game.status, TicTacToeGameStatus.draw);
      expect(game.winner, isNull);
      expect(game.isGameOver, isTrue);
    });

    test('rejects moves after a player has won', () {
      final game = TicTacToeGame();

      game.tryPlaceMark(0, 0); // P1
      game.tryPlaceMark(1, 0); // P2
      game.tryPlaceMark(0, 1); // P1
      game.tryPlaceMark(1, 1); // P2
      game.tryPlaceMark(0, 2); // P1 -> WIN!

      expect(game.status, TicTacToeGameStatus.won);

      final subsequentMove = game.tryPlaceMark(2, 2);
      expect(subsequentMove, isNull);
      expect(game.getCell(2, 2), isNull);
    });
  });

  group('TicTacToeGame - Reset', () {
    test('resets all state cleanly', () {
      final game = TicTacToeGame();

      game.tryPlaceMark(0, 0); // P1
      game.tryPlaceMark(1, 0); // P2
      game.tryPlaceMark(0, 1); // P1
      game.tryPlaceMark(1, 1); // P2
      game.tryPlaceMark(0, 2); // P1 -> WIN!
      expect(game.isGameOver, isTrue);

      game.reset();

      expect(game.status, TicTacToeGameStatus.playing);
      expect(game.currentPlayer, TicTacToePlayer.player1);
      expect(game.winner, isNull);
      expect(game.winningPositions, isEmpty);
      expect(game.isGameOver, isFalse);
      expect(game.canRevert, isFalse);
      expect(game.moveCount, 0);

      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
          expect(game.getCell(r, c), isNull);
        }
      }
    });
  });
}
