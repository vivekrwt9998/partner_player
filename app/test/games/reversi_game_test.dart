import 'package:app/games/reversi/logic/reversi_game.dart';
import 'package:app/games/reversi/models/reversi_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _blue = ReversiPlayer.player1;
const _red = ReversiPlayer.player2;

/// Builds an 8x8 board from a compact description; everything not listed
/// is an empty square.
List<List<ReversiPlayer?>> _board(List<(int, int, ReversiPlayer)> discs) {
  final grid = List.generate(
    ReversiGame.size,
    (_) => List<ReversiPlayer?>.filled(ReversiGame.size, null),
  );
  for (final (row, col, player) in discs) {
    grid[row][col] = player;
  }
  return grid;
}

/// A whole row of one colour, for filling a board quickly.
List<(int, int, ReversiPlayer)> _row(int row, ReversiPlayer player) => [
      for (var col = 0; col < ReversiGame.size; col++) (row, col, player),
    ];

void main() {
  group('Setup', () {
    test('opens with the four centre discs and Blue to move', () {
      final game = ReversiGame();

      expect(game.discAt(3, 3), _red);
      expect(game.discAt(4, 4), _red);
      expect(game.discAt(3, 4), _blue);
      expect(game.discAt(4, 3), _blue);
      expect(game.blueScore, 2);
      expect(game.redScore, 2);
      expect(game.currentPlayer, _blue);
      expect(game.status, ReversiGameStatus.playing);
      expect(game.canRevert, isFalse);
    });

    test('Blue opens with exactly the four classic moves', () {
      final game = ReversiGame();

      expect(
        game.legalSquares.toSet(),
        {
          const ReversiPosition(2, 3),
          const ReversiPosition(3, 2),
          const ReversiPosition(4, 5),
          const ReversiPosition(5, 4),
        },
      );
    });
  });

  group('Playing a disc', () {
    test('lays the disc, turns the run over and passes the turn', () {
      final game = ReversiGame();

      final move = game.tryPlace(2, 3);

      expect(move, isNotNull);
      expect(move!.player, _blue);
      expect(move.flipped, [const ReversiPosition(3, 3)]);
      expect(game.discAt(2, 3), _blue);
      expect(game.discAt(3, 3), _blue, reason: 'the outflanked disc turned');
      expect(game.blueScore, 4);
      expect(game.redScore, 1);
      expect(game.currentPlayer, _red);
      expect(move.passedPlayer, isNull);
      expect(move.isTerminal, isFalse);
    });

    test('one disc can turn runs over in several directions at once', () {
      // Blue at (4,2) outflanks a row of Red to its right *and* a
      // diagonal of Red below it.
      final game = ReversiGame()
        ..debugConfigure(
          cells: _board([
            (4, 3, _red),
            (4, 4, _red),
            (4, 5, _blue),
            (5, 3, _red),
            (6, 4, _blue),
          ]),
          currentPlayer: _blue,
        );

      final move = game.tryPlace(4, 2);

      expect(move, isNotNull);
      expect(
        move!.flipped.toSet(),
        {
          const ReversiPosition(4, 3),
          const ReversiPosition(4, 4),
          const ReversiPosition(5, 3),
        },
      );
      expect(game.discAt(4, 4), _blue);
      expect(game.discAt(5, 3), _blue);
      expect(game.redScore, 0);
    });

    test('a square that turns nothing over is not a move', () {
      final game = ReversiGame();

      expect(game.canPlace(0, 0), isFalse);
      expect(game.tryPlace(0, 0), isNull);
      expect(game.currentPlayer, _blue, reason: 'a refused move costs nothing');
    });

    test('an occupied square and an off-board square are both refused', () {
      final game = ReversiGame();

      expect(game.tryPlace(3, 3), isNull);
      expect(game.tryPlace(-1, 0), isNull);
      expect(game.tryPlace(0, ReversiGame.size), isNull);
    });

    test('the opponent only gets the squares that work for them', () {
      final game = ReversiGame();
      game.tryPlace(2, 3);

      expect(game.currentPlayer, _red);
      expect(
        game.legalSquares.toSet(),
        {
          const ReversiPosition(2, 2),
          const ReversiPosition(2, 4),
          const ReversiPosition(4, 2),
        },
      );
    });
  });

  group('Passing', () {
    test('a player with no move is skipped and the turn comes back', () {
      // Blue owns the top two rows apart from a gap at (1,0) and a pair
      // of Red discs beside it. Taking that pair leaves Red with one
      // disc down at (7,6), walled in with no run of Blue it can close --
      // so Red is skipped. Blue still has (7,5) to play, so the game goes
      // on rather than ending.
      final game = ReversiGame()
        ..debugConfigure(
          cells: _board([
            ..._row(0, _blue),
            (1, 1, _red),
            (1, 2, _red),
            for (var col = 3; col < ReversiGame.size; col++) (1, col, _blue),
            (7, 6, _red),
            (7, 7, _blue),
          ]),
          currentPlayer: _blue,
        );

      final move = game.tryPlace(1, 0);

      expect(move, isNotNull);
      expect(move!.flipped.toSet(),
          {const ReversiPosition(1, 1), const ReversiPosition(1, 2)});
      expect(game.redScore, 1, reason: 'only the far disc survived');
      expect(move.passedPlayer, _red);
      expect(game.currentPlayer, _blue, reason: 'the turn came straight back');
      expect(game.status, ReversiGameStatus.playing);
      expect(game.legalSquares, contains(const ReversiPosition(7, 5)));
    });
  });

  group('Finishing', () {
    test('neither side able to move ends it, counted by discs', () {
      // Blue fills the first two rows, Red the third; Blue takes the last
      // empty square in row 3, which leaves nobody with a legal move.
      final game = ReversiGame()
        ..debugConfigure(
          cells: _board([
            ..._row(0, _blue),
            ..._row(1, _blue),
            (2, 0, _blue),
            for (var col = 1; col < ReversiGame.size - 1; col++)
              (2, col, _red),
          ]),
          currentPlayer: _blue,
        );

      final move = game.tryPlace(2, 7);

      expect(move, isNotNull);
      expect(game.isGameOver, isTrue);
      expect(game.status, ReversiGameStatus.won);
      expect(game.winner, _blue);
      expect(game.redScore, 0);
      expect(game.legalSquares, isEmpty);
    });

    test('an even split is a draw', () {
      // Two discs each, nothing adjacent to outflank: nobody can move.
      final game = ReversiGame()
        ..debugConfigure(
          cells: _board([
            (0, 0, _blue),
            (0, 7, _blue),
            (7, 0, _red),
            (7, 7, _red),
          ]),
          currentPlayer: _blue,
        );

      expect(game.isGameOver, isTrue);
      expect(game.status, ReversiGameStatus.draw);
      expect(game.winner, isNull);
      expect(game.blueScore, game.redScore);
    });

    test('a finished game ignores further input', () {
      final game = ReversiGame()
        ..debugConfigure(
          cells: _board([
            (0, 0, _blue),
            (0, 7, _blue),
            (7, 0, _red),
            (7, 7, _red),
          ]),
          currentPlayer: _blue,
        );

      expect(game.tryPlace(3, 3), isNull);
      expect(game.canPlace(3, 3), isFalse);
    });
  });

  group('Revert and reset', () {
    test('revert puts back the disc and everything it turned over', () {
      final game = ReversiGame();
      final before = [
        for (var row = 0; row < ReversiGame.size; row++)
          [
            for (var col = 0; col < ReversiGame.size; col++)
              game.discAt(row, col),
          ],
      ];

      game.tryPlace(2, 3);
      expect(game.canRevert, isTrue);
      expect(game.revert(), isTrue);

      for (var row = 0; row < ReversiGame.size; row++) {
        for (var col = 0; col < ReversiGame.size; col++) {
          expect(game.discAt(row, col), before[row][col],
              reason: 'square $row,$col');
        }
      }
      expect(game.currentPlayer, _blue);
      expect(game.canRevert, isFalse);
      expect(game.legalSquares.length, 4, reason: 'the hints came back too');
    });

    test('revert can take back the move that ended the game', () {
      final game = ReversiGame()
        ..debugConfigure(
          cells: _board([
            ..._row(0, _blue),
            ..._row(1, _blue),
            (2, 0, _blue),
            for (var col = 1; col < ReversiGame.size - 1; col++)
              (2, col, _red),
          ]),
          currentPlayer: _blue,
        );
      game.tryPlace(2, 7);
      expect(game.isGameOver, isTrue);

      game.revert();

      expect(game.isGameOver, isFalse);
      expect(game.winner, isNull);
      expect(game.redScore, 6);
      expect(game.currentPlayer, _blue);
    });

    test('reset returns the opening position', () {
      final game = ReversiGame();
      game.tryPlace(2, 3);
      game.tryPlace(2, 2);

      game.reset();

      expect(game.blueScore, 2);
      expect(game.redScore, 2);
      expect(game.currentPlayer, _blue);
      expect(game.canRevert, isFalse);
      expect(game.status, ReversiGameStatus.playing);
      expect(game.legalSquares.length, 4);
    });
  });
}
