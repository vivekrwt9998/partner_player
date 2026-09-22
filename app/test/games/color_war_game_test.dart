import 'package:app/games/color_war/logic/color_war_game.dart';
import 'package:app/games/color_war/models/color_war_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _p1 = ColorWarPlayer.player1;
const _p2 = ColorWarPlayer.player2;

/// One short of bursting.
const _primed = ColorWarGame.burstLimit - 1;

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

    test('every cell holds four orbs, corner or middle alike', () {
      expect(ColorWarGame.burstLimit, 4);

      // A corner is no more fragile than anywhere else: three orbs sit
      // there quite happily.
      for (final corner in const [(0, 0), (0, 4), (4, 0), (4, 4)]) {
        final game = ColorWarGame()
          ..debugConfigure(
            cells: _board([(corner.$1, corner.$2, _p1, 2), (2, 2, _p2, 1)]),
            currentPlayer: _p1,
          );

        game.tryPlaceOrb(corner.$1, corner.$2);

        expect(game.hasPendingBlasts, isFalse,
            reason: 'three orbs in corner $corner must not burst');
        expect(game.cellAt(corner.$1, corner.$2).orbs, _primed);
      }
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
    test('a cell empties at four orbs and feeds each neighbour one', () {
      final game = ColorWarGame()
        ..debugConfigure(
          cells: _board([(2, 2, _p1, _primed), (4, 4, _p2, 1)]),
          currentPlayer: _p1,
        );

      final move = game.tryPlaceOrb(2, 2);

      expect(move!.willExplode, isTrue);
      expect(game.currentPlayer, _p1,
          reason: 'the turn waits until the board settles');

      final blast = game.stepBlast();

      expect(blast!.sources, [const ColorWarPosition(2, 2)]);
      expect(game.cellAt(2, 2), ColorWarCell.empty);
      for (final neighbour in const [(1, 2), (3, 2), (2, 1), (2, 3)]) {
        expect(game.cellAt(neighbour.$1, neighbour.$2),
            const ColorWarCell(owner: _p1, orbs: 1),
            reason: 'neighbour $neighbour');
      }
      expect(game.hasPendingBlasts, isFalse);
      expect(game.currentPlayer, _p2, reason: 'settled, so the turn passes');
    });

    test('a cell at the rim loses the orbs it has no neighbour for', () {
      final game = ColorWarGame()
        ..debugConfigure(
          cells: _board([(0, 0, _p1, _primed), (4, 4, _p2, 1)]),
          currentPlayer: _p1,
        );

      game.tryPlaceOrb(0, 0);
      game.settle();

      expect(game.cellAt(0, 0), ColorWarCell.empty);
      expect(game.cellAt(0, 1), const ColorWarCell(owner: _p1, orbs: 1));
      expect(game.cellAt(1, 0), const ColorWarCell(owner: _p1, orbs: 1));
      expect(game.orbsOwnedBy(_p1), 2,
          reason: 'a corner has two neighbours, so two orbs go over the edge');
    });

    test('a burst captures the opponent cells it lands on, orbs and all', () {
      final game = ColorWarGame()
        ..debugConfigure(
          cells: _board([
            (0, 0, _p1, _primed),
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
      final game = ColorWarGame()
        ..debugConfigure(
          cells: _board([
            (0, 0, _p1, _primed),
            (0, 1, _p1, _primed),
            (1, 0, _p1, _primed),
            (4, 4, _p2, 1),
          ]),
          currentPlayer: _p1,
        );

      game.tryPlaceOrb(0, 0);

      final first = game.stepBlast();
      expect(first!.sources, [const ColorWarPosition(0, 0)]);
      expect(first.hasMore, isTrue, reason: 'both neighbours are now full');

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
          cells: _board([(0, 0, _p1, _primed), (4, 4, _p2, 1)]),
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
            (0, 0, _p1, _primed),
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
          cells: _board([(0, 0, _p1, _primed), (0, 1, _p2, 1)]),
          currentPlayer: _p1,
        );
      game.tryPlaceOrb(0, 0);
      game.settle();

      expect(game.tryPlaceOrb(4, 4), isNull);
      expect(game.stepBlast(), isNull);
    });

    test('a runaway cascade still terminates', () {
      // Every cell one orb short: the wave front sweeps the whole board.
      final cells = List.generate(
        ColorWarGame.defaultSize,
        (row) => List.generate(
          ColorWarGame.defaultSize,
          (col) => const ColorWarCell(owner: _p1, orbs: _primed),
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
            (0, 0, _p1, _primed),
            (0, 1, _p1, _primed),
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
          cells: _board([(0, 0, _p1, _primed), (0, 1, _p2, 1)]),
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
