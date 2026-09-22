import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/games/tetra_tower/logic/tetra_tower_game.dart';
import 'package:app/games/tetra_tower/models/tetra_tower_models.dart';

void main() {
  group('TetraTowerGame - Initialization', () {
    test('starts with a single empty layer and Player 1 holding a piece', () {
      final game = TetraTowerGame();

      expect(TetraTowerGame.gridSize, 4);
      expect(game.layers.length, 1);
      expect(game.currentLayerIndex, 0);
      expect(game.currentPlayer, TetraTowerPlayer.player1);
      expect(game.status, TetraTowerGameStatus.playing);
      expect(game.winner, isNull);
      expect(game.totalInstability, 0);
      expect(game.isGameOver, isFalse);
      expect(game.canRevert, isFalse);
      expect(game.moveCount, 0);
      expect(game.currentRotationIndex, 0);
      expect(game.currentPieceCells.length, 4);

      for (var row = 0; row < TetraTowerGame.gridSize; row++) {
        for (var col = 0; col < TetraTowerGame.gridSize; col++) {
          expect(game.getCell(0, row, col), isNull);
        }
      }
    });
  });

  group('TetrominoShape - Rotations', () {
    test('every shape rotation has exactly 4 cells', () {
      for (final shape in TetrominoShape.values) {
        for (final rotation in shape.rotations) {
          expect(rotation.length, 4, reason: '$shape produced a malformed rotation');
        }
      }
    });

    test('rotation counts match each shape\'s real symmetry', () {
      expect(TetrominoShape.o.rotations.length, 1);
      expect(TetrominoShape.i.rotations.length, 2);
      expect(TetrominoShape.s.rotations.length, 2);
      expect(TetrominoShape.z.rotations.length, 2);
      expect(TetrominoShape.t.rotations.length, 4);
      expect(TetrominoShape.j.rotations.length, 4);
      expect(TetrominoShape.l.rotations.length, 4);
    });
  });

  group('TetraTowerGame - Rotating the current piece', () {
    test('cycles through every rotation and wraps back to the first', () {
      // Seed 1's very first piece is a T (verified out-of-band), which has
      // exactly 4 distinct rotations.
      final game = TetraTowerGame(random: Random(1));
      expect(game.currentShape, TetrominoShape.t);
      expect(game.currentRotationIndex, 0);

      final seen = <int>{0};
      for (var i = 1; i <= 4; i++) {
        game.rotatePiece();
        seen.add(game.currentRotationIndex);
      }

      expect(game.currentRotationIndex, 0, reason: '4 rotations of a 4-rotation piece wraps around');
      expect(seen, {0, 1, 2, 3});
    });

    test('rotating does not consume the turn or touch the board', () {
      final game = TetraTowerGame();
      game.rotatePiece();
      expect(game.moveCount, 0);
      expect(game.currentPlayer, TetraTowerPlayer.player1);
    });
  });

  group('TetraTowerGame - Placement', () {
    test('placing on an empty ground layer is always fully supported (no instability)', () {
      final game = TetraTowerGame();
      final anchor = game.legalAnchorsForCurrentPiece().first;

      final move = game.tryPlacePiece(anchor.row, anchor.col);
      expect(move, isNotNull);
      expect(move!.layerIndex, 0);
      expect(move.instabilityAdded, 0);
      expect(move.totalInstability, 0);
      expect(game.totalInstability, 0);
      for (final cell in move.cells) {
        expect(game.getCell(0, cell.row, cell.col), move.player);
      }
      expect(game.currentPlayer, TetraTowerPlayer.player1.opponent);
      expect(game.moveCount, 1);
    });

    test('rejects placing out of bounds', () {
      final game = TetraTowerGame();
      expect(game.canPlaceAt(TetraTowerGame.gridSize, 0), isFalse);
      expect(game.tryPlacePiece(TetraTowerGame.gridSize, 0), isNull);
      expect(game.moveCount, 0);
    });

    test('rejects placing on top of already-filled cells', () {
      final game = TetraTowerGame();
      final anchor = game.legalAnchorsForCurrentPiece().first;
      final move = game.tryPlacePiece(anchor.row, anchor.col);
      expect(move, isNotNull);

      // The anchor is the piece's bounding-box corner, not necessarily one
      // of its actual cells (e.g. an S/Z/L/J/T piece has gaps in its own
      // bounding box) -- check the cells the move itself reports filling.
      for (final cell in move!.cells) {
        expect(game.getCell(0, cell.row, cell.col), isNotNull);
      }

      // Re-placing anything at one of those same cells must fail, whatever
      // shape/rotation is currently up -- try every rotation of the fresh
      // piece to be sure none of them can land back on an occupied cell.
      final stillFilled = move.cells.first;
      for (final rotation in game.currentShape.rotations) {
        for (final cell in rotation) {
          final anchorRow = stillFilled.row - cell.$1;
          final anchorCol = stillFilled.col - cell.$2;
          expect(game.canPlaceAt(anchorRow, anchorCol), isFalse);
        }
      }
    });

    test('rejects placement once the game has ended', () {
      final game = TetraTowerGame(random: Random(1));
      const playthrough = [
        (0, 0), (1, 1), (0, 0), (1, 0), (2, 1), (0, 0), (2, 0), (0, 0),
      ];
      for (final anchor in playthrough) {
        game.tryPlacePiece(anchor.$1, anchor.$2);
        if (game.isGameOver) break;
      }
      expect(game.isGameOver, isTrue);
      expect(game.tryPlacePiece(0, 0), isNull);
    });
  });

  group('TetraTowerGame - A fully verified playthrough (seed 1)', () {
    // This exact sequence (shape, rotation, and anchor for each move) was
    // captured by actually running the engine with this seed, not guessed --
    // see the PR/commit description for how. It pins down the instability
    // math, layer-advancement rule, and collapse/winner determination all
    // at once, end to end.
    test('produces the same shapes, layers, instability and collapse every time', () {
      final game = TetraTowerGame(random: Random(1));

      TetraTowerMove expectMove(
        int anchorRow,
        int anchorCol, {
        required TetrominoShape shape,
        required int layerBefore,
        required double instabilityAdded,
        required double total,
        required bool startedNewLayer,
      }) {
        expect(game.currentShape, shape);
        expect(game.currentLayerIndex, layerBefore);
        final move = game.tryPlacePiece(anchorRow, anchorCol);
        expect(move, isNotNull);
        expect(move!.instabilityAdded, instabilityAdded);
        expect(move.totalInstability, total);
        expect(move.startedNewLayer, startedNewLayer);
        return move;
      }

      expectMove(0, 0,
          shape: TetrominoShape.t, layerBefore: 0, instabilityAdded: 0, total: 0, startedNewLayer: false);
      expectMove(1, 1,
          shape: TetrominoShape.s, layerBefore: 0, instabilityAdded: 0, total: 0, startedNewLayer: true);
      expectMove(0, 0,
          shape: TetrominoShape.o, layerBefore: 1, instabilityAdded: 14, total: 14, startedNewLayer: false);
      expectMove(1, 0,
          shape: TetrominoShape.l, layerBefore: 1, instabilityAdded: 14, total: 28, startedNewLayer: false);
      expectMove(2, 1,
          shape: TetrominoShape.l, layerBefore: 1, instabilityAdded: 50, total: 78, startedNewLayer: true);
      expectMove(0, 0,
          shape: TetrominoShape.l, layerBefore: 2, instabilityAdded: 16, total: 94, startedNewLayer: false);
      expectMove(2, 0,
          shape: TetrominoShape.t, layerBefore: 2, instabilityAdded: 4, total: 98, startedNewLayer: true);
      final finalMove = expectMove(0, 0,
          shape: TetrominoShape.z, layerBefore: 3, instabilityAdded: 30, total: 128, startedNewLayer: false);

      expect(finalMove.status, TetraTowerGameStatus.collapsed);
      expect(finalMove.winner, TetraTowerPlayer.player1);
      expect(game.isGameOver, isTrue);
      expect(game.layers.length, 4);
      expect(game.moveCount, 8);
    });
  });

  group('TetraTowerGame - Revert', () {
    test('cannot revert on a fresh game', () {
      final game = TetraTowerGame();
      expect(game.canRevert, isFalse);
      expect(game.revert(), isFalse);
    });

    test('reverts a placement, restoring the board, turn, piece and instability', () {
      final game = TetraTowerGame(random: Random(1));
      final shapeBefore = game.currentShape;
      final anchor = game.legalAnchorsForCurrentPiece().first;
      game.tryPlacePiece(anchor.row, anchor.col);

      expect(game.revert(), isTrue);
      expect(game.currentPlayer, TetraTowerPlayer.player1);
      expect(game.currentShape, shapeBefore);
      expect(game.currentRotationIndex, 0);
      expect(game.totalInstability, 0);
      expect(game.canRevert, isFalse);
      expect(game.moveCount, 0);
      for (var row = 0; row < TetraTowerGame.gridSize; row++) {
        for (var col = 0; col < TetraTowerGame.gridSize; col++) {
          expect(game.getCell(0, row, col), isNull);
        }
      }
    });

    test('reverting a move that started a new layer removes that layer too', () {
      final game = TetraTowerGame(random: Random(1));
      game.tryPlacePiece(0, 0); // T on layer 0
      expect(game.layers.length, 1);

      game.tryPlacePiece(1, 1); // S -- starts layer 1
      expect(game.layers.length, 2);

      expect(game.revert(), isTrue);
      expect(game.layers.length, 1);
      expect(game.currentLayerIndex, 0);
    });

    test('reverting after a collapse restores playing status', () {
      final game = TetraTowerGame(random: Random(1));
      const playthrough = [
        (0, 0), (1, 1), (0, 0), (1, 0), (2, 1), (0, 0), (2, 0), (0, 0),
      ];
      for (final anchor in playthrough) {
        game.tryPlacePiece(anchor.$1, anchor.$2);
        if (game.isGameOver) break;
      }
      expect(game.isGameOver, isTrue);

      expect(game.revert(), isTrue);
      expect(game.status, TetraTowerGameStatus.playing);
      expect(game.winner, isNull);
      expect(game.isGameOver, isFalse);
    });
  });

  group('TetraTowerGame - Reset', () {
    test('resets all state cleanly after moves have been made', () {
      final game = TetraTowerGame(random: Random(1));
      const playthrough = [
        (0, 0), (1, 1), (0, 0), (1, 0), (2, 1), (0, 0), (2, 0), (0, 0),
      ];
      for (final anchor in playthrough) {
        game.tryPlacePiece(anchor.$1, anchor.$2);
        if (game.isGameOver) break;
      }
      expect(game.isGameOver, isTrue);

      game.reset();

      expect(game.status, TetraTowerGameStatus.playing);
      expect(game.currentPlayer, TetraTowerPlayer.player1);
      expect(game.winner, isNull);
      expect(game.totalInstability, 0);
      expect(game.layers.length, 1);
      expect(game.currentLayerIndex, 0);
      expect(game.isGameOver, isFalse);
      expect(game.canRevert, isFalse);
      expect(game.moveCount, 0);
    });
  });
}
