import 'package:flutter_test/flutter_test.dart';
import 'package:app/games/checkers/logic/checkers_game.dart';
import 'package:app/games/checkers/models/checkers_models.dart';

void main() {
  group('CheckersGame - Board Initialization', () {
    test('starts with the standard 8x8 layout, 12 pieces per side', () {
      final game = CheckersGame();

      expect(CheckersGame.size, 8);
      expect(game.currentPlayer, CheckersPlayer.player1);
      expect(game.status, CheckersGameStatus.playing);
      expect(game.winner, isNull);
      expect(game.isGameOver, isFalse);
      expect(game.canRevert, isFalse);
      expect(game.moveCount, 0);
      expect(game.mustContinueFrom, isNull);

      var player1Count = 0;
      var player2Count = 0;
      for (var row = 0; row < 8; row++) {
        for (var col = 0; col < 8; col++) {
          final piece = game.getCell(row, col);
          if (piece == null) continue;

          // Pieces only ever sit on dark (odd row+col) squares.
          expect((row + col).isOdd, isTrue);
          expect(piece.isKing, isFalse);

          if (row < 3) {
            expect(piece.player, CheckersPlayer.player2);
            player2Count++;
          } else if (row >= 5) {
            expect(piece.player, CheckersPlayer.player1);
            player1Count++;
          } else {
            fail('Unexpected piece in the empty middle rows at ($row, $col)');
          }
        }
      }
      expect(player1Count, 12);
      expect(player2Count, 12);
    });
  });

  group('CheckersGame - Simple Moves', () {
    test('moves a man one square diagonally forward and switches turns', () {
      final game = CheckersGame();

      expect(game.legalMovesFrom(5, 0), containsAll([const BoardPosition(4, 1)]));

      final move = game.tryMove(5, 0, 4, 1);
      expect(move, isNotNull);
      expect(move!.player, CheckersPlayer.player1);
      expect(move.captured, isNull);
      expect(move.promoted, isFalse);
      expect(move.mustContinue, isFalse);
      expect(game.getCell(4, 1), const CheckersPiece(player: CheckersPlayer.player1, isKing: false));
      expect(game.getCell(5, 0), isNull);
      expect(game.currentPlayer, CheckersPlayer.player2);
      expect(game.moveCount, 1);
    });

    test('rejects a backward move for a man', () {
      final game = CheckersGame();
      // Player1 moves toward row 0; row 6 is backward for a row-5 piece.
      expect(game.tryMove(5, 0, 6, 1), isNull);
    });

    test('rejects a non-diagonal move', () {
      final game = CheckersGame();
      expect(game.tryMove(5, 0, 5, 2), isNull); // sideways
      expect(game.tryMove(5, 0, 3, 0), isNull); // straight forward
    });

    test('rejects moving into an occupied square', () {
      final game = CheckersGame();
      expect(game.tryMove(6, 1, 5, 0), isNull); // (5,0) still has a piece
    });

    test('rejects a 2-square jump with no piece to capture', () {
      final game = CheckersGame();
      // (4,1) and (3,2) are both empty -- nothing to jump.
      game.tryMove(5, 0, 4, 1);
      expect(game.tryMove(6, 3, 4, 1), isNull);
    });

    test('rejects moving a piece that is not the current player\'s', () {
      final game = CheckersGame();
      expect(game.tryMove(2, 1, 3, 0), isNull); // Player 2's piece, but it's Player 1's turn
    });
  });

  group('CheckersGame - Capturing', () {
    test('captures an adjacent opponent piece, jumping into the empty square beyond', () {
      final game = CheckersGame();
      game.tryMove(5, 4, 4, 5);
      game.tryMove(2, 3, 3, 4);

      expect(game.legalMovesFrom(4, 5), [const BoardPosition(2, 3)]);

      final move = game.tryMove(4, 5, 2, 3);
      expect(move, isNotNull);
      expect(move!.captured, const BoardPosition(3, 4));
      expect(move.mustContinue, isFalse);
      expect(game.getCell(2, 3), const CheckersPiece(player: CheckersPlayer.player1, isKing: false));
      expect(game.getCell(3, 4), isNull, reason: 'the jumped piece is removed');
      expect(game.getCell(4, 5), isNull);
      expect(game.currentPlayer, CheckersPlayer.player2);
    });

    test('forces a capture: a player with any capture available cannot make a different move', () {
      final game = CheckersGame();
      game.tryMove(5, 0, 4, 1);
      game.tryMove(2, 1, 3, 0);
      game.tryMove(4, 1, 3, 2);

      // Player 2's (2,3) can now capture the piece at (3,2), landing on the
      // square Player 1 just vacated at (4,1).
      expect(game.legalMovesFrom(2, 3), [const BoardPosition(4, 1)]);

      // A different Player 2 piece that could otherwise move (its own
      // square (2,1) is empty since move 2) is blocked by the forced capture.
      expect(game.legalMovesFrom(1, 0), isEmpty);
      expect(game.tryMove(1, 0, 2, 1), isNull);

      // The capture itself is legal.
      final move = game.tryMove(2, 3, 4, 1);
      expect(move, isNotNull);
      expect(move!.captured, const BoardPosition(3, 2));
    });
  });

  group('CheckersGame - Multi-Jump Chains', () {
    test('a capture landing next to another capturable piece forces the chain to continue', () {
      final game = CheckersGame();
      const setup = [
        (5, 0, 4, 1),
        (2, 1, 3, 0),
        (4, 1, 3, 2),
        (2, 3, 4, 1),
        (6, 1, 5, 0),
        (1, 0, 2, 1),
      ];
      for (final m in setup) {
        expect(game.tryMove(m.$1, m.$2, m.$3, m.$4), isNotNull, reason: 'setup move $m failed');
      }

      final firstJump = game.tryMove(5, 0, 3, 2);
      expect(firstJump, isNotNull);
      expect(firstJump!.captured, const BoardPosition(4, 1));
      expect(firstJump.mustContinue, isTrue);
      expect(game.mustContinueFrom, const BoardPosition(3, 2));
      // The turn must not have passed yet.
      expect(game.currentPlayer, CheckersPlayer.player1);

      // Only the jumping piece may move; everything else is locked out.
      expect(game.legalMovesFrom(5, 2), isEmpty);
      expect(game.legalMovesFrom(3, 2), [const BoardPosition(1, 0)]);

      final secondJump = game.tryMove(3, 2, 1, 0);
      expect(secondJump, isNotNull);
      expect(secondJump!.captured, const BoardPosition(2, 1));
      expect(secondJump.mustContinue, isFalse);
      expect(game.mustContinueFrom, isNull);
      expect(game.currentPlayer, CheckersPlayer.player2);
    });
  });

  group('CheckersGame - Promotion', () {
    test('a capture that lands on the back row promotes and ends the turn immediately', () {
      final game = CheckersGame();
      const setup = [
        (5, 0, 4, 1),
        (2, 1, 3, 0),
        (4, 1, 3, 2),
        (2, 3, 4, 1),
        (5, 2, 4, 3),
        (1, 0, 2, 1),
        (6, 1, 5, 2),
        (4, 1, 5, 0),
        (7, 2, 6, 1),
      ];
      for (final m in setup) {
        expect(game.tryMove(m.$1, m.$2, m.$3, m.$4), isNotNull, reason: 'setup move $m failed');
      }

      expect(game.currentPlayer, CheckersPlayer.player2);
      final move = game.tryMove(5, 0, 7, 2);
      expect(move, isNotNull);
      expect(move!.player, CheckersPlayer.player2);
      expect(move.captured, const BoardPosition(6, 1));
      expect(move.promoted, isTrue);
      // Kinging ends the turn even though this is a capture landing spot.
      expect(move.mustContinue, isFalse);
      expect(game.getCell(7, 2), const CheckersPiece(player: CheckersPlayer.player2, isKing: true));
      expect(game.currentPlayer, CheckersPlayer.player1);
    });
  });

  group('CheckersGame - Revert', () {
    test('cannot revert on a fresh game', () {
      final game = CheckersGame();
      expect(game.canRevert, isFalse);
      expect(game.revert(), isFalse);
    });

    test('reverts a simple move, restoring the board and the turn', () {
      final game = CheckersGame();
      game.tryMove(5, 0, 4, 1);

      expect(game.revert(), isTrue);
      expect(game.getCell(5, 0), const CheckersPiece(player: CheckersPlayer.player1, isKing: false));
      expect(game.getCell(4, 1), isNull);
      expect(game.currentPlayer, CheckersPlayer.player1);
      expect(game.canRevert, isFalse);
      expect(game.moveCount, 0);
    });

    test('reverts a capture, restoring the captured piece', () {
      final game = CheckersGame();
      game.tryMove(5, 4, 4, 5);
      game.tryMove(2, 3, 3, 4);
      game.tryMove(4, 5, 2, 3);

      expect(game.revert(), isTrue);
      expect(game.getCell(4, 5), const CheckersPiece(player: CheckersPlayer.player1, isKing: false));
      expect(game.getCell(3, 4), const CheckersPiece(player: CheckersPlayer.player2, isKing: false));
      expect(game.getCell(2, 3), isNull);
      expect(game.currentPlayer, CheckersPlayer.player1);
    });

    test('reverting a promotion un-crowns the piece', () {
      final game = CheckersGame();
      const setup = [
        (5, 0, 4, 1),
        (2, 1, 3, 0),
        (4, 1, 3, 2),
        (2, 3, 4, 1),
        (5, 2, 4, 3),
        (1, 0, 2, 1),
        (6, 1, 5, 2),
        (4, 1, 5, 0),
        (7, 2, 6, 1),
      ];
      for (final m in setup) {
        game.tryMove(m.$1, m.$2, m.$3, m.$4);
      }
      game.tryMove(5, 0, 7, 2); // captures + promotes

      expect(game.revert(), isTrue);
      expect(game.getCell(5, 0), const CheckersPiece(player: CheckersPlayer.player2, isKing: false));
      expect(game.getCell(6, 1), const CheckersPiece(player: CheckersPlayer.player1, isKing: false));
      expect(game.getCell(7, 2), isNull);
    });
  });

  group('CheckersGame - Win Detection', () {
    test('a player with no legal moves loses; the game never draws', () {
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
        final move = game.tryMove(m.$1, m.$2, m.$3, m.$4);
        expect(move, isNotNull, reason: 'move $m failed, game likely diverged from the verified script');
        if (move!.isTerminal) break;
      }

      expect(game.isGameOver, isTrue);
      expect(game.status, CheckersGameStatus.won);
      expect(game.winner, CheckersPlayer.player2);
    });

    test('rejects moves after the game has ended', () {
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
        final move = game.tryMove(m.$1, m.$2, m.$3, m.$4);
        if (move != null && move.isTerminal) break;
      }

      expect(game.isGameOver, isTrue);
      expect(game.tryMove(0, 1, 1, 2), isNull);
    });
  });

  group('CheckersGame - Reset', () {
    test('resets all state cleanly after moves have been made', () {
      final game = CheckersGame();
      game.tryMove(5, 0, 4, 1);
      game.tryMove(2, 1, 3, 0);
      expect(game.moveCount, 2);

      game.reset();

      expect(game.status, CheckersGameStatus.playing);
      expect(game.currentPlayer, CheckersPlayer.player1);
      expect(game.winner, isNull);
      expect(game.isGameOver, isFalse);
      expect(game.canRevert, isFalse);
      expect(game.moveCount, 0);
      expect(game.mustContinueFrom, isNull);
      expect(game.getCell(5, 0), isNotNull);
      expect(game.getCell(2, 1), isNotNull);
    });
  });
}
