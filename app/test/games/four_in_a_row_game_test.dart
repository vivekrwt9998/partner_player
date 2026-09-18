import 'package:flutter_test/flutter_test.dart';
import 'package:app/games/four_in_a_row/logic/four_in_a_row_game.dart';
import 'package:app/games/four_in_a_row/models/four_in_a_row_models.dart';

void main() {
  group('FourInARowGame - Board Initialization', () {
    test('starts with an empty 6x7 board', () {
      final game = FourInARowGame();

      expect(FourInARowGame.rows, 6);
      expect(FourInARowGame.cols, 7);
      expect(game.board.length, 6);
      for (int r = 0; r < 6; r++) {
        expect(game.board[r].length, 7);
        for (int c = 0; c < 7; c++) {
          expect(game.getCell(r, c), isNull);
        }
      }
      expect(game.currentPlayer, FourInARowPlayer.player1);
      expect(game.status, FourInARowGameStatus.playing);
      expect(game.winner, isNull);
      expect(game.winningPositions, isEmpty);
      expect(game.isGameOver, isFalse);
      expect(game.canRevert, isFalse);
      expect(game.moveCount, 0);
    });
  });

  group('FourInARowGame - Move and Gravity Mechanics', () {
    test('returns the applied move with its engine-calculated landing row', () {
      final game = FourInARowGame();

      final firstMove = game.tryDropDisc(3);
      expect(firstMove, isNotNull);
      expect(firstMove!.player, FourInARowPlayer.player1);
      expect(firstMove.column, 3);
      expect(firstMove.row, 5);
      expect(firstMove.status, FourInARowGameStatus.playing);
      expect(firstMove.winner, isNull);

      final secondMove = game.tryDropDisc(3);
      expect(secondMove, isNotNull);
      expect(secondMove!.player, FourInARowPlayer.player2);
      expect(secondMove.row, 4);
    });

    test('drops disc to the lowest empty row and alternates turns', () {
      final game = FourInARowGame();

      // P1 drops into col 3 -> lands on row 5 (bottom)
      final move1 = game.dropDisc(3);
      expect(move1, isTrue);
      expect(game.getCell(5, 3), FourInARowPlayer.player1);
      expect(game.currentPlayer, FourInARowPlayer.player2);
      expect(game.moveCount, 1);
      expect(game.canRevert, isTrue);

      // P2 drops into col 3 -> lands on row 4
      final move2 = game.dropDisc(3);
      expect(move2, isTrue);
      expect(game.getCell(4, 3), FourInARowPlayer.player2);
      expect(game.currentPlayer, FourInARowPlayer.player1);
      expect(game.moveCount, 2);

      // P1 drops into col 3 -> lands on row 3
      final move3 = game.dropDisc(3);
      expect(move3, isTrue);
      expect(game.getCell(3, 3), FourInARowPlayer.player1);
      expect(game.moveCount, 3);
    });

    test('rejects moves into a full column without changing turn or board', () {
      final game = FourInARowGame();

      // Fill column 0 completely (6 pieces)
      for (int i = 0; i < 6; i++) {
        expect(game.dropDisc(0), isTrue);
      }

      expect(game.isColumnFull(0), isTrue);
      expect(game.canDrop(0), isFalse);

      final currentPlayerBefore = game.currentPlayer;
      final boardBefore = game.board.map((row) => List.of(row)).toList();

      // Attempting 7th drop into full column 0
      final invalidMove = game.dropDisc(0);
      expect(invalidMove, isFalse);
      expect(game.currentPlayer, currentPlayerBefore);
      expect(game.board, boardBefore);
    });

    test('rejects out of bounds columns', () {
      final game = FourInARowGame();
      expect(game.dropDisc(-1), isFalse);
      expect(game.dropDisc(7), isFalse);
      expect(game.currentPlayer, FourInARowPlayer.player1);
    });
  });

  group('FourInARowGame - Revert Capability', () {
    test('cannot revert on empty board', () {
      final game = FourInARowGame();
      expect(game.canRevert, isFalse);
      expect(game.revert(), isFalse);
    });

    test('reverts last move and restores previous turn correctly', () {
      final game = FourInARowGame();

      game.dropDisc(3); // P1 moves -> (5, 3)
      expect(game.getCell(5, 3), FourInARowPlayer.player1);
      expect(game.currentPlayer, FourInARowPlayer.player2);

      final reverted = game.revert();
      expect(reverted, isTrue);
      expect(game.getCell(5, 3), isNull);
      expect(game.currentPlayer, FourInARowPlayer.player1);
      expect(game.canRevert, isFalse);
      expect(game.moveCount, 0);
    });

    test('reverts multiple consecutive moves cleanly', () {
      final game = FourInARowGame();

      game.dropDisc(0); // P1
      game.dropDisc(1); // P2
      game.dropDisc(2); // P1

      expect(game.moveCount, 3);
      expect(game.currentPlayer, FourInARowPlayer.player2);

      // Revert move 3 (P1 at col 2)
      expect(game.revert(), isTrue);
      expect(game.getCell(5, 2), isNull);
      expect(game.currentPlayer, FourInARowPlayer.player1);
      expect(game.moveCount, 2);

      // Revert move 2 (P2 at col 1)
      expect(game.revert(), isTrue);
      expect(game.getCell(5, 1), isNull);
      expect(game.currentPlayer, FourInARowPlayer.player2);
      expect(game.moveCount, 1);

      // Revert move 1 (P1 at col 0)
      expect(game.revert(), isTrue);
      expect(game.getCell(5, 0), isNull);
      expect(game.currentPlayer, FourInARowPlayer.player1);
      expect(game.moveCount, 0);
      expect(game.canRevert, isFalse);
    });

    test('reverting after a win restores playing state', () {
      final game = FourInARowGame();

      // Quick vertical win for P1
      game.dropDisc(0); // P1
      game.dropDisc(1); // P2
      game.dropDisc(0); // P1
      game.dropDisc(1); // P2
      game.dropDisc(0); // P1
      game.dropDisc(1); // P2
      game.dropDisc(0); // P1 -> WIN!

      expect(game.status, FourInARowGameStatus.won);
      expect(game.winner, FourInARowPlayer.player1);

      // Revert winning move
      expect(game.revert(), isTrue);
      expect(game.status, FourInARowGameStatus.playing);
      expect(game.winner, isNull);
      expect(game.winningPositions, isEmpty);
      expect(game.currentPlayer, FourInARowPlayer.player1);
      expect(game.getCell(2, 0), isNull);
    });
  });

  group('FourInARowGame - Win Detection', () {
    test('detects horizontal win', () {
      final game = FourInARowGame();

      // P1: col 0, P2: col 0
      // P1: col 1, P2: col 1
      // P1: col 2, P2: col 2
      // P1: col 3 (P1 gets row 5, cols 0, 1, 2, 3)
      game.dropDisc(0); // P1 -> (5, 0)
      game.dropDisc(0); // P2 -> (4, 0)
      game.dropDisc(1); // P1 -> (5, 1)
      game.dropDisc(1); // P2 -> (4, 1)
      game.dropDisc(2); // P1 -> (5, 2)
      game.dropDisc(2); // P2 -> (4, 2)
      game.dropDisc(3); // P1 -> (5, 3) - WIN!

      expect(game.status, FourInARowGameStatus.won);
      expect(game.winner, FourInARowPlayer.player1);
      expect(game.isGameOver, isTrue);
      expect(game.winningPositions.length, greaterThanOrEqualTo(4));
      expect(
        game.winningPositions,
        containsAll([
          const BoardPosition(5, 0),
          const BoardPosition(5, 1),
          const BoardPosition(5, 2),
          const BoardPosition(5, 3),
        ]),
      );
    });

    test('detects vertical win', () {
      final game = FourInARowGame();

      // P1: col 0, P2: col 1
      // P1: col 0, P2: col 1
      // P1: col 0, P2: col 1
      // P1: col 0 -> WIN (col 0 rows 5, 4, 3, 2)
      game.dropDisc(0); // P1 (5, 0)
      game.dropDisc(1); // P2 (5, 1)
      game.dropDisc(0); // P1 (4, 0)
      game.dropDisc(1); // P2 (4, 1)
      game.dropDisc(0); // P1 (3, 0)
      game.dropDisc(1); // P2 (3, 1)
      game.dropDisc(0); // P1 (2, 0) - WIN!

      expect(game.status, FourInARowGameStatus.won);
      expect(game.winner, FourInARowPlayer.player1);
      expect(game.isGameOver, isTrue);
      expect(
        game.winningPositions,
        containsAll([
          const BoardPosition(5, 0),
          const BoardPosition(4, 0),
          const BoardPosition(3, 0),
          const BoardPosition(2, 0),
        ]),
      );
    });

    test('detects diagonal up-right (/) win', () {
      final game = FourInARowGame();

      // Goal: P1 connects (5,0), (4,1), (3,2), (2,3)
      game.dropDisc(0); // P1 (5,0)
      game.dropDisc(1); // P2 (5,1)
      game.dropDisc(1); // P1 (4,1)
      game.dropDisc(2); // P2 (5,2)
      game.dropDisc(2); // P1 (4,2)
      game.dropDisc(3); // P2 (5,3)
      game.dropDisc(2); // P1 (3,2)
      game.dropDisc(3); // P2 (4,3)
      game.dropDisc(3); // P1 (3,3)
      game.dropDisc(0); // P2 (4,0)
      game.dropDisc(3); // P1 (2,3) -> WIN!

      expect(game.status, FourInARowGameStatus.won);
      expect(game.winner, FourInARowPlayer.player1);
      expect(
        game.winningPositions,
        containsAll([
          const BoardPosition(5, 0),
          const BoardPosition(4, 1),
          const BoardPosition(3, 2),
          const BoardPosition(2, 3),
        ]),
      );
    });

    test('detects diagonal down-right (\\) win', () {
      final game = FourInARowGame();

      // Goal: P1 connects (2,0), (3,1), (4,2), (5,3)
      game.dropDisc(3); // P1 (5,3)
      game.dropDisc(2); // P2 (5,2)
      game.dropDisc(2); // P1 (4,2)
      game.dropDisc(1); // P2 (5,1)
      game.dropDisc(1); // P1 (4,1)
      game.dropDisc(0); // P2 (5,0)
      game.dropDisc(1); // P1 (3,1)
      game.dropDisc(0); // P2 (4,0)
      game.dropDisc(0); // P1 (3,0)
      game.dropDisc(4); // P2 (5,4)
      game.dropDisc(0); // P1 (2,0) -> WIN!

      expect(game.status, FourInARowGameStatus.won);
      expect(game.winner, FourInARowPlayer.player1);
      expect(
        game.winningPositions,
        containsAll([
          const BoardPosition(2, 0),
          const BoardPosition(3, 1),
          const BoardPosition(4, 2),
          const BoardPosition(5, 3),
        ]),
      );
    });

    test('does not trigger false positive on 3 connected discs', () {
      final game = FourInARowGame();

      game.dropDisc(0); // P1 (5,0)
      game.dropDisc(0); // P2 (4,0)
      game.dropDisc(1); // P1 (5,1)
      game.dropDisc(1); // P2 (4,1)
      game.dropDisc(2); // P1 (5,2)
      game.dropDisc(2); // P2 (4,2)

      expect(game.status, FourInARowGameStatus.playing);
      expect(game.winner, isNull);
      expect(game.isGameOver, isFalse);
    });
  });

  group('FourInARowGame - Draw and Game End', () {
    test('declares draw when board is completely full with no winner', () {
      final game = FourInARowGame();

      // Fill board deterministically to avoid 4-in-a-row:
      const moves = [
        0, 1, 0, 1, 0, 1, // cols 0, 1
        1, 0, 1, 0, 1, 0, // cols 1, 0
        2, 3, 2, 3, 2, 3, // cols 2, 3
        3, 2, 3, 2, 3, 2, // cols 3, 2
        4, 5, 4, 5, 4, 5, // cols 4, 5
        5, 4, 5, 4, 5, 4, // cols 5, 4
        6, 6, 6, 6, 6, 6, // col 6
      ];

      for (final col in moves) {
        if (!game.isGameOver) {
          game.dropDisc(col);
        }
      }

      expect(game.status, FourInARowGameStatus.draw);
      expect(game.winner, isNull);
      expect(game.isGameOver, isTrue);
    });

    test('rejects moves after a player has won', () {
      final game = FourInARowGame();

      // Quick vertical win for P1
      game.dropDisc(0); // P1
      game.dropDisc(1); // P2
      game.dropDisc(0); // P1
      game.dropDisc(1); // P2
      game.dropDisc(0); // P1
      game.dropDisc(1); // P2
      game.dropDisc(0); // P1 -> WIN!

      expect(game.status, FourInARowGameStatus.won);

      // Subsequent moves must be rejected
      final subsequentMove = game.dropDisc(2);
      expect(subsequentMove, isFalse);
      expect(game.getCell(5, 2), isNull);
    });
  });

  group('FourInARowGame - Reset', () {
    test('resets all state cleanly', () {
      final game = FourInARowGame();

      // Win game
      game.dropDisc(0);
      game.dropDisc(1);
      game.dropDisc(0);
      game.dropDisc(1);
      game.dropDisc(0);
      game.dropDisc(1);
      game.dropDisc(0);
      expect(game.isGameOver, isTrue);

      // Reset
      game.reset();

      expect(game.status, FourInARowGameStatus.playing);
      expect(game.currentPlayer, FourInARowPlayer.player1);
      expect(game.winner, isNull);
      expect(game.winningPositions, isEmpty);
      expect(game.isGameOver, isFalse);
      expect(game.canRevert, isFalse);
      expect(game.moveCount, 0);

      for (int r = 0; r < 6; r++) {
        for (int c = 0; c < 7; c++) {
          expect(game.getCell(r, c), isNull);
        }
      }
    });
  });
}
