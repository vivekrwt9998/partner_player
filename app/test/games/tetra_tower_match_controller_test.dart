import 'dart:math';

import 'package:app/games/tetra_tower/logic/tetra_tower_game.dart';
import 'package:app/games/tetra_tower/models/tetra_tower_models.dart';
import 'package:app/games/tetra_tower/presentation/tetra_tower_match_controller.dart';
import 'package:app/models/game_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TetraTowerMatchController - Local', () {
    test('allows both local players to place pieces and alternates turns', () {
      final controller = TetraTowerMatchController(
        mode: GameMode.local,
        game: TetraTowerGame(random: Random(1)),
      );
      addTearDown(controller.dispose);

      expect(controller.submitLocalPlacement(0, 0), isTrue);
      expect(controller.game.currentPlayer, TetraTowerPlayer.player2);
      expect(controller.game.moveCount, 1);

      expect(controller.submitLocalPlacement(1, 1), isTrue);
      expect(controller.game.currentPlayer, TetraTowerPlayer.player1);
      expect(controller.supportsRevert, isTrue);
    });

    test('rejects an illegal placement', () {
      final controller = TetraTowerMatchController(mode: GameMode.local);
      addTearDown(controller.dispose);

      expect(controller.submitLocalPlacement(TetraTowerGame.gridSize, 0), isFalse);
      expect(controller.game.moveCount, 0);
    });

    test('rotate cycles the current piece without consuming the turn', () {
      final controller = TetraTowerMatchController(
        mode: GameMode.local,
        game: TetraTowerGame(random: Random(1)),
      );
      addTearDown(controller.dispose);

      expect(controller.game.currentRotationIndex, 0);
      controller.rotatePiece();
      expect(controller.game.currentRotationIndex, 1);
      expect(controller.game.moveCount, 0);
      expect(controller.game.currentPlayer, TetraTowerPlayer.player1);
    });

    test('revert undoes the last placement and restart resets the match', () {
      final controller = TetraTowerMatchController(
        mode: GameMode.local,
        game: TetraTowerGame(random: Random(1)),
      );
      addTearDown(controller.dispose);

      controller.submitLocalPlacement(0, 0);
      expect(controller.canRevert, isTrue);

      controller.revert();
      expect(controller.game.moveCount, 0);
      expect(controller.game.currentPlayer, TetraTowerPlayer.player1);

      controller.submitLocalPlacement(0, 0);
      controller.restart();
      expect(controller.game.moveCount, 0);
      expect(controller.canRevert, isFalse);
      expect(controller.game.layers.length, 1);
    });

    test('rejects further input once the game is over', () {
      final controller = TetraTowerMatchController(
        mode: GameMode.local,
        game: TetraTowerGame(random: Random(1)),
      );
      addTearDown(controller.dispose);

      const playthrough = [
        (0, 0), (1, 1), (0, 0), (1, 0), (2, 1), (0, 0), (2, 0), (0, 0),
      ];
      for (final anchor in playthrough) {
        controller.submitLocalPlacement(anchor.$1, anchor.$2);
        if (controller.game.isGameOver) break;
      }

      expect(controller.game.isGameOver, isTrue);
      expect(controller.canAcceptLocalInput, isFalse);
      expect(controller.submitLocalPlacement(0, 0), isFalse);
    });
  });
}
