import 'package:app/games/hex/logic/hex_game.dart';
import 'package:app/games/hex/models/hex_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _blue = HexPlayer.player1;
const _red = HexPlayer.player2;

List<List<HexPlayer?>> _board(List<(int, int, HexPlayer)> stones) {
  final cells = List.generate(
    HexGame.size,
    (_) => List<HexPlayer?>.filled(HexGame.size, null),
  );
  for (final (row, col, player) in stones) {
    cells[row][col] = player;
  }
  return cells;
}

/// A straight line along one row -- the direction Blue has to join.
List<(int, int, HexPlayer)> _across(int row, HexPlayer player, {int? skip}) => [
      for (var col = 0; col < HexGame.size; col++)
        if (col != skip) (row, col, player),
    ];

/// A straight line down one column -- the direction Red has to join.
List<(int, int, HexPlayer)> _down(int col, HexPlayer player, {int? skip}) => [
      for (var row = 0; row < HexGame.size; row++)
        if (row != skip) (row, col, player),
    ];

bool _isAdjacent(HexCell a, HexCell b) => HexGame.neighbourOffsets.any(
      (offset) =>
          a.row + offset.$1 == b.row && a.col + offset.$2 == b.col,
    );

void main() {
  group('Adjacency', () {
    test('the six neighbour offsets are distinct and symmetric', () {
      const offsets = HexGame.neighbourOffsets;

      expect(offsets, hasLength(6));
      expect(offsets.toSet(), hasLength(6));

      // Symmetry is what lets the engine walk a chain from either end:
      // if A touches B then B must touch A.
      for (final (dr, dc) in offsets) {
        expect(offsets.contains((-dr, -dc)), isTrue,
            reason: '($dr, $dc) has no opposite');
      }
    });
  });

  group('Setup', () {
    test('starts empty with Blue to play', () {
      final game = HexGame();

      expect(HexGame.size, 11);
      expect(game.currentPlayer, _blue);
      expect(game.status, HexGameStatus.playing);
      expect(game.isGameOver, isFalse);
      expect(game.winner, isNull);
      expect(game.winningPath, isEmpty);
      expect(game.moveCount, 0);
      expect(game.canRevert, isFalse);

      for (var row = 0; row < HexGame.size; row++) {
        for (var col = 0; col < HexGame.size; col++) {
          expect(game.stoneAt(row, col), isNull);
        }
      }
    });

    test('every empty cell is playable, and an occupied one is not', () {
      final game = HexGame();

      for (var row = 0; row < HexGame.size; row++) {
        for (var col = 0; col < HexGame.size; col++) {
          expect(game.canPlace(row, col), isTrue);
        }
      }

      game.tryPlace(4, 4);
      expect(game.canPlace(4, 4), isFalse);
    });
  });

  group('Placing a stone', () {
    test('lands where it was asked for and hands the turn over', () {
      final game = HexGame();

      final move = game.tryPlace(3, 7);

      expect(move, isNotNull);
      expect(move!.player, _blue);
      expect(move.cell, const HexCell(3, 7));
      expect(move.isTerminal, isFalse);
      expect(move.winningPath, isEmpty);
      expect(game.stoneAt(3, 7), _blue);
      expect(game.currentPlayer, _red);
      expect(game.moveCount, 1);
    });

    test('is refused off the board, and costs no turn', () {
      final game = HexGame();

      expect(game.tryPlace(-1, 0), isNull);
      expect(game.tryPlace(0, -1), isNull);
      expect(game.tryPlace(HexGame.size, 0), isNull);
      expect(game.tryPlace(0, HexGame.size), isNull);

      expect(game.moveCount, 0);
      expect(game.currentPlayer, _blue);
    });

    test('is refused on a cell that is already taken', () {
      final game = HexGame()..tryPlace(2, 2);

      expect(game.tryPlace(2, 2), isNull);
      expect(game.moveCount, 1);
      expect(game.currentPlayer, _red, reason: 'the refusal cost Red nothing');
    });

    test('is refused once the game has been won', () {
      final game = HexGame()
        ..debugConfigure(cells: _board(_across(5, _blue, skip: 10)));

      expect(game.tryPlace(5, 10), isNotNull);
      expect(game.isGameOver, isTrue);

      expect(game.tryPlace(0, 0), isNull);
      expect(game.canPlace(0, 0), isFalse);
    });
  });

  group('Winning', () {
    test('Blue joins the two straight sides', () {
      final game = HexGame()
        ..debugConfigure(cells: _board(_across(5, _blue, skip: 10)));

      final move = game.tryPlace(5, 10);

      expect(move!.isTerminal, isTrue);
      expect(game.status, HexGameStatus.won);
      expect(game.winner, _blue);
    });

    test('Red joins the two slanted sides', () {
      final game = HexGame()
        ..debugConfigure(
          cells: _board(_down(5, _red, skip: 10)),
          currentPlayer: _red,
        );

      final move = game.tryPlace(10, 5);

      expect(move!.isTerminal, isTrue);
      expect(game.status, HexGameStatus.won);
      expect(game.winner, _red);
    });

    test('a chain that wanders across still counts', () {
      // A pure diagonal: every step goes up one row and right one
      // column, which is one of the six neighbours.
      final diagonal = [
        for (var i = 0; i < HexGame.size; i++)
          (HexGame.size - 1 - i, i, _blue),
      ];
      final game = HexGame()
        ..debugConfigure(cells: _board(diagonal.sublist(0, 10)));

      final move = game.tryPlace(0, HexGame.size - 1);

      expect(move!.isTerminal, isTrue);
      expect(game.winner, _blue);
    });

    test('a chain one cell short of the far side does not win', () {
      // Columns 0-8 are Blue, so playing column 9 still leaves the
      // last column of the board untouched.
      final game = HexGame()
        ..debugConfigure(
          cells: _board([
            for (var col = 0; col < HexGame.size - 2; col++) (5, col, _blue),
          ]),
        );

      final move = game.tryPlace(5, 9);

      expect(move, isNotNull);
      expect(move!.isTerminal, isFalse);
      expect(game.status, HexGameStatus.playing);
      expect(game.currentPlayer, _red);
    });

    test('an opponent stone in the way breaks the chain', () {
      final game = HexGame()
        ..debugConfigure(
          cells: _board([
            for (var col = 0; col < 5; col++) (5, col, _blue),
            (5, 5, _red),
            for (var col = 6; col < HexGame.size; col++) (5, col, _blue),
          ]),
        );

      // (4,5) touches the left run but not the right one, so the two
      // halves are still apart.
      final move = game.tryPlace(4, 5);

      expect(move!.isTerminal, isFalse);
      expect(game.status, HexGameStatus.playing);
    });

    test('but a chain may go round that stone', () {
      final game = HexGame()
        ..debugConfigure(
          cells: _board([
            for (var col = 0; col < 5; col++) (5, col, _blue),
            (4, 5, _blue),
            (5, 5, _red),
            for (var col = 6; col < HexGame.size; col++) (5, col, _blue),
          ]),
        );

      final move = game.tryPlace(4, 6);

      expect(move!.isTerminal, isTrue);
      expect(game.winner, _blue);
    });

    test('the winning path is a real chain from one side to the other', () {
      final game = HexGame()
        ..debugConfigure(cells: _board(_across(5, _blue, skip: 10)));

      final path = game.tryPlace(5, 10)!.winningPath;

      expect(path, hasLength(HexGame.size),
          reason: 'the straight run is also the shortest one');
      expect(path.first.col, 0, reason: 'starts on one of Blue sides');
      expect(path.last.col, HexGame.size - 1, reason: 'ends on the other');

      for (final cell in path) {
        expect(game.stoneAt(cell.row, cell.col), _blue);
      }
      for (var i = 1; i < path.length; i++) {
        expect(_isAdjacent(path[i - 1], path[i]), isTrue,
            reason: '${path[i - 1]} does not touch ${path[i]}');
      }

      expect(game.winningPath, path);
    });

    test('a path round an obstacle is still unbroken', () {
      final game = HexGame()
        ..debugConfigure(
          cells: _board([
            for (var col = 0; col < 5; col++) (5, col, _blue),
            (4, 5, _blue),
            (5, 5, _red),
            for (var col = 6; col < HexGame.size; col++) (5, col, _blue),
          ]),
        );

      final path = game.tryPlace(4, 6)!.winningPath;

      expect(path.map((c) => c.row).toSet(), {4, 5},
          reason: 'it has to step off row 5 to get past the red stone');
      for (var i = 1; i < path.length; i++) {
        expect(_isAdjacent(path[i - 1], path[i]), isTrue);
      }
    });
  });

  group('Revert and reset', () {
    test('revert lifts one stone and gives the turn back', () {
      final game = HexGame()
        ..tryPlace(1, 1)
        ..tryPlace(2, 2);

      expect(game.currentPlayer, _blue);
      expect(game.revert(), isTrue);

      expect(game.stoneAt(2, 2), isNull);
      expect(game.stoneAt(1, 1), _blue, reason: 'only the last stone goes');
      expect(game.currentPlayer, _red);
      expect(game.moveCount, 1);
    });

    test('revert on an empty board does nothing', () {
      final game = HexGame();

      expect(game.revert(), isFalse);
      expect(game.canRevert, isFalse);
    });

    test('reverting the winning move puts the game back in play', () {
      final game = HexGame()
        ..debugConfigure(cells: _board(_across(5, _blue, skip: 10)))
        ..tryPlace(5, 10);

      expect(game.isGameOver, isTrue);

      expect(game.revert(), isTrue);
      expect(game.status, HexGameStatus.playing);
      expect(game.winner, isNull);
      expect(game.winningPath, isEmpty);
      expect(game.stoneAt(5, 10), isNull);
      expect(game.currentPlayer, _blue);
      expect(game.canPlace(5, 10), isTrue);
    });

    test('reset clears the board and the history', () {
      final game = HexGame()
        ..tryPlace(0, 0)
        ..tryPlace(1, 0)
        ..reset();

      expect(game.moveCount, 0);
      expect(game.canRevert, isFalse);
      expect(game.currentPlayer, _blue);
      expect(game.stoneAt(0, 0), isNull);
      expect(game.stoneAt(1, 0), isNull);
    });
  });

  group('debugConfigure', () {
    test('drops a board in without disturbing the history', () {
      final game = HexGame()
        ..debugConfigure(
          cells: _board([(0, 0, _blue), (1, 1, _red)]),
          currentPlayer: _red,
        );

      expect(game.stoneAt(0, 0), _blue);
      expect(game.stoneAt(1, 1), _red);
      expect(game.currentPlayer, _red);
      expect(game.moveCount, 0);
      expect(game.canRevert, isFalse);
      expect(game.status, HexGameStatus.playing);
    });

    test('spots a board that has already been won', () {
      final game = HexGame()
        ..debugConfigure(cells: _board(_across(5, _blue)), currentPlayer: _red);

      expect(game.isGameOver, isTrue);
      expect(game.winner, _blue);
      expect(game.winningPath, hasLength(HexGame.size));
    });
  });
}
