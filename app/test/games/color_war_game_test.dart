import 'package:app/games/color_war/logic/color_war_game.dart';
import 'package:app/games/color_war/models/color_war_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _p1 = ColorWarPlayer.player1;
const _p2 = ColorWarPlayer.player2;

/// Builds a 5x5 board from a compact description.
///
/// Each entry is `row, col, owner, orbs`; everything else is empty.
List<List<ColorWarCell>> _board(List<(int, int, ColorWarPlayer, int)> cells) {
  final grid = List.generate(
    ColorWarGame.defaultSize,
    (_) => List<ColorWarCell>.filled(
        ColorWarGame.defaultSize, ColorWarCell.empty),
  );
  for (final (row, col, owner, orbs) in cells) {
    grid[row][col] = ColorWarCell(owner: owner, orbs: orbs);
  }
  return grid;
}

void main() {
  group('Setup', () {
    test('starts on an empty 5x5 board with Blue to move', () {
      final game = ColorWarGame();

      expect(game.rows, 5);
      expect(game.cols, 5);
      expect(game.currentPlayer, _p1);
      expect(game.status, ColorWarGameStatus.playing);
      expect(game.cellsOwnedBy(_p1), 0);
      expect(game.cellsOwnedBy(_p2), 0);
      expect(game.hasPendingBlasts, isFalse);
      expect(game.canRevert, isFalse);
    });

    test('a cell bursts at one orb per neighbour', () {
      final game = ColorWarGame();

      expect(game.criticalMass(0, 0), 2, reason: 'corner');
      expect(game.criticalMass(0, 2), 3, reason: 'top edge');
      expect(game.criticalMass(2, 0), 3, reason: 'left edge');
      expect(game.criticalMass(2, 2), 4, reason: 'middle');
      expect(game.criticalMass(4, 4), 2, reason: 'far corner');
    });
  });

  group('Dropping an orb', () {
    test('claims the cell and passes the turn', () {
      final game = ColorWarGame();

      final move = game.tryPlaceOrb(2, 2);

      expect(move, isNotNull);
      expect(move!.player, _p1);
      expect(move.willExplode, isFalse);
      expect(game.cellAt(2, 2), const ColorWarCell(owner: _p1, orbs: 1));
      expect(game.currentPlayer, _p2);
      expect(game.cellsOwnedBy(_p1), 1);
    });

    test('stacks on a cell you already own', () {
      final game = ColorWarGame();
      game.tryPlaceOrb(2, 2);
      game.tryPlaceOrb(0, 4);
      game.tryPlaceOrb(2, 2);

      expect(game.cellAt(2, 2), const ColorWarCell(owner: _p1, orbs: 2));
      expect(game.cellsOwnedBy(_p1), 1, reason: 'still one cell, two orbs');
      expect(game.orbsOwnedBy(_p1), 2);
    });

    test('never on the opponent\'s cell', () {
      final game = ColorWarGame();
      game.tryPlaceOrb(2, 2);

      expect(game.canPlace(2, 2), isFalse);
      expect(game.tryPlaceOrb(2, 2), isNull);
      expect(game.currentPlayer, _p2, reason: 'a refused move costs nothing');
    });

    test('never off the board', () {
      final game = ColorWarGame();

      expect(game.tryPlaceOrb(-1, 0), isNull);
      expect(game.tryPlaceOrb(0, 5), isNull);
    });
  });

  group('Bursting', () {
    test('a corner bursts at two orbs and paints both neighbours', () {
      final game = ColorWarGame()
        ..debugConfigure(
          cells: _board([(0, 0, _p1, 1), (4, 4, _p2, 1)]),
          currentPlayer: _p1,
        );

      final move = game.tryPlaceOrb(0, 0);

      expect(move!.willExplode, isTrue);
      expect(game.currentPlayer, _p1,
          reason: 'the turn waits until the board settles');

      final blast = game.stepBlast();

      expect(blast!.sources, [const ColorWarPosition(0, 0)]);
      expect(game.cellAt(0, 0), ColorWarCell.empty);
      expect(game.cellAt(0, 1), const ColorWarCell(owner: _p1, orbs: 1));
      expect(game.cellAt(1, 0), const ColorWarCell(owner: _p1, orbs: 1));
      expect(game.hasPendingBlasts, isFalse);
      expect(game.currentPlayer, _p2, reason: 'settled, so the turn passes');
    });

    test('a middle cell holds three orbs and only bursts on the fourth', () {
      final game = ColorWarGame()
        ..debugConfigure(
          cells: _board([(2, 2, _p1, 2), (4, 4, _p2, 1)]),
          currentPlayer: _p1,
        );

      game.tryPlaceOrb(2, 2);
      expect(game.hasPendingBlasts, isFalse, reason: 'three of four orbs');
      expect(game.cellAt(2, 2).orbs, 3);

      game.tryPlaceOrb(4, 0); // Red, somewhere harmless.
      game.tryPlaceOrb(2, 2); // Blue again -- now it goes.

      expect(game.hasPendingBlasts, isTrue);
      game.settle();
      expect(game.cellAt(2, 2), ColorWarCell.empty);
      for (final neighbour in const [(1, 2), (3, 2), (2, 1), (2, 3)]) {
        expect(game.cellAt(neighbour.$1, neighbour.$2).owner, _p1,
            reason: 'neighbour $neighbour');
      }
    });

    test('a burst captures the opponent cells it lands on, orbs and all', () {
      final game = ColorWarGame()
        ..debugConfigure(
          cells: _board([
            (0, 0, _p1, 1),
            (0, 1, _p2, 1),
            (1, 0, _p2, 1),
            (4, 4, _p2, 1),
          ]),
          currentPlayer: _p1,
        );

      game.tryPlaceOrb(0, 0);
      game.settle();

      expect(game.cellAt(0, 1), const ColorWarCell(owner: _p1, orbs: 2));
      expect(game.cellAt(1, 0), const ColorWarCell(owner: _p1, orbs: 2));
      expect(game.cellsOwnedBy(_p2), 1, reason: 'only the far corner is left');
    });

    test('one orb can set off several waves', () {
      // A corner primed to burst into two more primed cells.
      final game = ColorWarGame()
        ..debugConfigure(
          cells: _board([
            (0, 0, _p1, 1),
            (0, 1, _p1, 2),
            (1, 0, _p1, 2),
            (4, 4, _p2, 1),
          ]),
          currentPlayer: _p1,
        );

      game.tryPlaceOrb(0, 0);

      final first = game.stepBlast();
      expect(first!.sources, [const ColorWarPosition(0, 0)]);
      expect(first.hasMore, isTrue, reason: 'both edge cells are now full');

      final second = game.stepBlast();
      expect(
        second!.sources,
        containsAll(const [ColorWarPosition(0, 1), ColorWarPosition(1, 0)]),
      );

      game.settle();
      expect(game.hasPendingBlasts, isFalse);
      expect(game.cellsOwnedBy(_p1), greaterThan(2));
    });

    test('the board cannot be played while a reaction is spreading', () {
      final game = ColorWarGame()
        ..debugConfigure(
          cells: _board([(0, 0, _p1, 1), (4, 4, _p2, 1)]),
          currentPlayer: _p1,
        );

      game.tryPlaceOrb(0, 0);

      expect(game.hasPendingBlasts, isTrue);
      expect(game.canPlace(3, 3), isFalse);
      expect(game.tryPlaceOrb(3, 3), isNull);
      expect(game.canRevert, isFalse);
    });
  });

  group('Winning', () {
    test('taking the opponent\'s last cell wins', () {
      final game = ColorWarGame()
        ..debugConfigure(
          cells: _board([
            (0, 0, _p1, 1),
            (0, 1, _p2, 1),
          ]),
          currentPlayer: _p1,
        );

      game.tryPlaceOrb(0, 0);
      game.settle();

      expect(game.status, ColorWarGameStatus.won);
      expect(game.winner, _p1);
      expect(game.isGameOver, isTrue);
      expect(game.cellsOwnedBy(_p2), 0);
      expect(game.hasPendingBlasts, isFalse,
          reason: 'a won board must not keep reacting forever');
    });

    test('the first move does not win just because Red owns nothing yet', () {
      final game = ColorWarGame();

      game.tryPlaceOrb(2, 2);

      expect(game.status, ColorWarGameStatus.playing);
      expect(game.winner, isNull);
      expect(game.cellsOwnedBy(_p2), 0);
    });

    test('a finished game ignores further input', () {
      final game = ColorWarGame()
        ..debugConfigure(
          cells: _board([(0, 0, _p1, 1), (0, 1, _p2, 1)]),
          currentPlayer: _p1,
        );
      game.tryPlaceOrb(0, 0);
      game.settle();

      expect(game.tryPlaceOrb(4, 4), isNull);
      expect(game.stepBlast(), isNull);
    });

    test('a runaway cascade still terminates', () {
      // Almost every cell primed one short of bursting: the wave front
      // sweeps the whole board.
      final reference = ColorWarGame();
      final cells = List.generate(
        ColorWarGame.defaultSize,
        (row) => List.generate(
          ColorWarGame.defaultSize,
          (col) => ColorWarCell(
            owner: _p1,
            orbs: reference.criticalMass(row, col) - 1,
          ),
        ),
      );
      cells[4][4] = const ColorWarCell(owner: _p2, orbs: 1);
      final game = ColorWarGame()
        ..debugConfigure(cells: cells, currentPlayer: _p1);

      game.tryPlaceOrb(0, 0);
      game.settle();

      expect(game.hasPendingBlasts, isFalse);
      expect(game.status, ColorWarGameStatus.won);
      expect(game.winner, _p1);
    });
  });

  group('Revert and reset', () {
    test('revert puts back the whole cascade in one go', () {
      final game = ColorWarGame()
        ..debugConfigure(
          cells: _board([
            (0, 0, _p1, 1),
            (0, 1, _p1, 2),
            (4, 4, _p2, 1),
          ]),
          currentPlayer: _p1,
        );
      final before = [
        for (var row = 0; row < game.rows; row++)
          [for (var col = 0; col < game.cols; col++) game.cellAt(row, col)],
      ];

      game.tryPlaceOrb(0, 0);
      game.settle();
      expect(game.canRevert, isTrue);
      expect(game.revert(), isTrue);

      for (var row = 0; row < game.rows; row++) {
        for (var col = 0; col < game.cols; col++) {
          expect(game.cellAt(row, col), before[row][col],
              reason: 'cell $row,$col');
        }
      }
      expect(game.currentPlayer, _p1);
      expect(game.canRevert, isFalse, reason: 'nothing further to undo');
    });

    test('revert can take back a won game', () {
      final game = ColorWarGame()
        ..debugConfigure(
          cells: _board([(0, 0, _p1, 1), (0, 1, _p2, 1)]),
          currentPlayer: _p1,
        );
      game.tryPlaceOrb(0, 0);
      game.settle();
      expect(game.isGameOver, isTrue);

      game.revert();

      expect(game.isGameOver, isFalse);
      expect(game.winner, isNull);
      expect(game.cellsOwnedBy(_p2), 1);
    });

    test('reset empties the board and hands it back to Blue', () {
      final game = ColorWarGame();
      game.tryPlaceOrb(0, 0);
      game.tryPlaceOrb(4, 4);

      game.reset();

      expect(game.cellsOwnedBy(_p1), 0);
      expect(game.cellsOwnedBy(_p2), 0);
      expect(game.currentPlayer, _p1);
      expect(game.canRevert, isFalse);
      expect(game.status, ColorWarGameStatus.playing);
    });
  });

  test('a copy can be played out without touching the original', () {
    final game = ColorWarGame();
    game.tryPlaceOrb(2, 2);

    final clone = game.copy()
      ..tryPlaceOrb(0, 0)
      ..settle();

    expect(clone.cellsOwnedBy(_p2), 1);
    expect(game.cellsOwnedBy(_p2), 0);
    expect(game.currentPlayer, _p2);
  });
}
