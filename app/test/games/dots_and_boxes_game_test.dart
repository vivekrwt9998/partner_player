import 'package:app/games/dots_and_boxes/logic/dots_and_boxes_game.dart';
import 'package:app/games/dots_and_boxes/models/dots_and_boxes_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _blue = DotsAndBoxesPlayer.player1;
const _red = DotsAndBoxesPlayer.player2;

/// The three sides of box (row, col) other than its top.
List<BoxEdge> _threeSidesOf(int row, int col) => [
      BoxEdge.vertical(row, col),
      BoxEdge.vertical(row, col + 1),
      BoxEdge.horizontal(row + 1, col),
    ];

/// Every line on the board, in a fixed order.
List<BoxEdge> _allEdges() => [
      for (var row = 0; row < DotsAndBoxesGame.dotRows; row++)
        for (var col = 0; col < DotsAndBoxesGame.boxColumns; col++)
          BoxEdge.horizontal(row, col),
      for (var row = 0; row < DotsAndBoxesGame.boxRows; row++)
        for (var col = 0; col < DotsAndBoxesGame.dotColumns; col++)
          BoxEdge.vertical(row, col),
    ];

void main() {
  group('Setup', () {
    test('opens on an empty 6 x 9 grid of dots with Blue to draw', () {
      final game = DotsAndBoxesGame();

      expect(DotsAndBoxesGame.dotColumns, 6);
      expect(DotsAndBoxesGame.dotRows, 9);
      expect(DotsAndBoxesGame.boxColumns, 5);
      expect(DotsAndBoxesGame.boxRows, 8);
      expect(DotsAndBoxesGame.totalEdges, 93);

      expect(game.currentPlayer, _blue);
      expect(game.status, DotsAndBoxesGameStatus.playing);
      expect(game.blueScore, 0);
      expect(game.redScore, 0);
      expect(game.moveCount, 0);
      expect(game.canRevert, isFalse);
      expect(game.lastEdge, isNull);
      expect(game.lastEdgePlayer, isNull);
    });

    test('forty boxes, so the two sides really can come out level', () {
      expect(DotsAndBoxesGame.boxRows * DotsAndBoxesGame.boxColumns, 40);
    });
  });

  group('Drawing a line', () {
    test('claims nothing and passes the turn', () {
      final game = DotsAndBoxesGame();

      final move = game.tryDrawEdge(const BoxEdge.horizontal(0, 0));

      expect(move, isNotNull);
      expect(move!.player, _blue);
      expect(move.claimedBoxes, isEmpty);
      expect(move.playsAgain, isFalse);
      expect(game.isDrawn(const BoxEdge.horizontal(0, 0)), isTrue);
      expect(game.currentPlayer, _red);
    });

    test('the same line cannot be drawn twice', () {
      final game = DotsAndBoxesGame();
      game.tryDrawEdge(const BoxEdge.horizontal(0, 0));

      expect(game.canDraw(const BoxEdge.horizontal(0, 0)), isFalse);
      expect(game.tryDrawEdge(const BoxEdge.horizontal(0, 0)), isNull);
      expect(game.currentPlayer, _red, reason: 'a refused line costs nothing');
    });

    test('lines off the board are refused', () {
      final game = DotsAndBoxesGame();

      expect(game.tryDrawEdge(const BoxEdge.horizontal(-1, 0)), isNull);
      expect(
        game.tryDrawEdge(
            const BoxEdge.horizontal(0, DotsAndBoxesGame.dotColumns - 1)),
        isNull,
        reason: 'there are only boxColumns horizontal lines in a row',
      );
      expect(
        game.tryDrawEdge(
            BoxEdge.vertical(DotsAndBoxesGame.dotRows - 1, 0)),
        isNull,
        reason: 'the bottom row of dots has nothing below it',
      );
      expect(game.tryDrawEdge(const BoxEdge.vertical(0, 0)), isNotNull);
    });
  });

  group('Closing boxes', () {
    test('the fourth side claims the box and earns another go', () {
      final game = DotsAndBoxesGame()
        ..debugPlay(_threeSidesOf(0, 0), startingPlayer: _red);
      // Red laid three sides and the turn has come round to Blue, who
      // closes it.
      expect(game.currentPlayer, _blue);
      expect(game.boxOwner(0, 0), isNull);

      final move = game.tryDrawEdge(const BoxEdge.horizontal(0, 0));

      expect(move!.claimedBoxes, [const BoxCell(0, 0)]);
      expect(move.playsAgain, isTrue);
      expect(game.boxOwner(0, 0), _blue);
      expect(game.blueScore, 1);
      expect(game.currentPlayer, _blue, reason: 'Blue goes again');
    });

    test('one line can close the box on either side of it', () {
      // Everything except the line between the two boxes.
      final game = DotsAndBoxesGame()
        ..debugPlay([
          const BoxEdge.horizontal(0, 0),
          const BoxEdge.horizontal(1, 0),
          const BoxEdge.horizontal(2, 0),
          const BoxEdge.vertical(0, 0),
          const BoxEdge.vertical(1, 0),
          const BoxEdge.vertical(0, 1),
          const BoxEdge.vertical(1, 1),
        ]);

      final move = game.tryDrawEdge(const BoxEdge.horizontal(1, 0));
      expect(move, isNull, reason: 'that one is already drawn');

      // Rebuild leaving the shared line open.
      final other = DotsAndBoxesGame()
        ..debugPlay([
          const BoxEdge.horizontal(0, 0),
          const BoxEdge.horizontal(2, 0),
          const BoxEdge.vertical(0, 0),
          const BoxEdge.vertical(1, 0),
          const BoxEdge.vertical(0, 1),
          const BoxEdge.vertical(1, 1),
        ], startingPlayer: _red);

      final both = other.tryDrawEdge(const BoxEdge.horizontal(1, 0));

      expect(both!.claimedBoxes.length, 2);
      expect(both.claimedBoxes,
          containsAll(const [BoxCell(0, 0), BoxCell(1, 0)]));
      expect(both.playsAgain, isTrue);
      expect(other.boxesOwnedBy(both.player), 2);
    });

    test('a line that only makes a third side claims nothing', () {
      final game = DotsAndBoxesGame()
        ..debugPlay([
          const BoxEdge.horizontal(0, 0),
          const BoxEdge.vertical(0, 0),
        ]);

      final move = game.tryDrawEdge(const BoxEdge.vertical(0, 1));

      expect(move!.claimedBoxes, isEmpty);
      expect(move.playsAgain, isFalse);
      expect(game.boxOwner(0, 0), isNull);
    });
  });

  group('Showing the newest line', () {
    test('the newest line is the one picked out', () {
      final game = DotsAndBoxesGame();
      game.tryDrawEdge(const BoxEdge.horizontal(0, 0));

      expect(game.lastEdgePlayer, _blue);
      expect(game.lastEdge, const BoxEdge.horizontal(0, 0));

      game.tryDrawEdge(const BoxEdge.horizontal(3, 2));

      expect(game.lastEdgePlayer, _red, reason: 'now it is Red being shown');
      expect(game.lastEdge, const BoxEdge.horizontal(3, 2));
    });

    test('a turn that ran on still only shows its newest line', () {
      final game = DotsAndBoxesGame()
        ..debugPlay(_threeSidesOf(0, 0), startingPlayer: _red);
      // Blue closes the box and then draws again in the same turn.
      game.tryDrawEdge(const BoxEdge.horizontal(0, 0));
      game.tryDrawEdge(const BoxEdge.horizontal(5, 4));

      expect(game.lastEdgePlayer, _blue);
      expect(game.lastEdge, const BoxEdge.horizontal(5, 4),
          reason: 'a whole run in colour would read as a block, not lines');
    });
  });

  group('Finishing', () {
    test('the last line ends it and the boxes are counted', () {
      final game = DotsAndBoxesGame();
      final edges = _allEdges();

      for (final edge in edges.take(edges.length - 1)) {
        expect(game.tryDrawEdge(edge), isNotNull, reason: 'line $edge');
      }
      expect(game.isGameOver, isFalse);

      final last = game.tryDrawEdge(edges.last);

      expect(last!.isTerminal, isTrue);
      expect(game.blueScore + game.redScore,
          DotsAndBoxesGame.boxRows * DotsAndBoxesGame.boxColumns);
      if (game.blueScore == game.redScore) {
        expect(game.status, DotsAndBoxesGameStatus.draw);
        expect(game.winner, isNull);
      } else {
        expect(game.status, DotsAndBoxesGameStatus.won);
        expect(game.winner, game.blueScore > game.redScore ? _blue : _red);
      }
    });

    test('a finished game ignores further lines', () {
      final game = DotsAndBoxesGame();
      for (final edge in _allEdges()) {
        game.tryDrawEdge(edge);
      }

      expect(game.isGameOver, isTrue);
      expect(game.canDraw(const BoxEdge.horizontal(0, 0)), isFalse);
      expect(game.tryDrawEdge(const BoxEdge.horizontal(0, 0)), isNull);
    });
  });

  group('Revert and reset', () {
    test('revert takes back the line and the box it closed', () {
      final game = DotsAndBoxesGame()
        ..debugPlay(_threeSidesOf(0, 0), startingPlayer: _red);
      game.tryDrawEdge(const BoxEdge.horizontal(0, 0));
      expect(game.boxOwner(0, 0), _blue);

      expect(game.revert(), isTrue);

      expect(game.boxOwner(0, 0), isNull);
      expect(game.isDrawn(const BoxEdge.horizontal(0, 0)), isFalse);
      expect(game.blueScore, 0);
      expect(game.currentPlayer, _blue, reason: 'it was Blue about to draw');
      expect(game.canRevert, isFalse, reason: 'the setup is not undoable');
    });

    test('revert restores whose turn it was', () {
      final game = DotsAndBoxesGame();
      game.tryDrawEdge(const BoxEdge.horizontal(0, 0));
      expect(game.currentPlayer, _red);

      game.revert();

      expect(game.currentPlayer, _blue);
      expect(game.moveCount, 0);
      expect(game.lastEdge, isNull);
    });

    test('reset clears the board and hands it back to Blue', () {
      final game = DotsAndBoxesGame();
      game.tryDrawEdge(const BoxEdge.horizontal(0, 0));
      game.tryDrawEdge(const BoxEdge.vertical(0, 0));

      game.reset();

      expect(game.moveCount, 0);
      expect(game.blueScore, 0);
      expect(game.currentPlayer, _blue);
      expect(game.isDrawn(const BoxEdge.horizontal(0, 0)), isFalse);
      expect(game.canRevert, isFalse);
      expect(game.status, DotsAndBoxesGameStatus.playing);
    });
  });
}
