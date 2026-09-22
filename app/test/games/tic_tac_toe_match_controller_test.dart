import 'package:app/games/tic_tac_toe/models/tic_tac_toe_models.dart';
import 'package:app/games/tic_tac_toe/presentation/tic_tac_toe_match_controller.dart';
import 'package:app/models/game_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TicTacToeMatchController - Local', () {
    test('allows both local players to place marks and alternates turns', () {
      final controller = TicTacToeMatchController(mode: GameMode.local);
      addTearDown(controller.dispose);

      expect(controller.submitLocalCell(1, 1), isTrue);
      expect(controller.game.getCell(1, 1), TicTacToePlayer.player1);
      expect(controller.game.currentPlayer, TicTacToePlayer.player2);

      expect(controller.submitLocalCell(0, 0), isTrue);
      expect(controller.game.getCell(0, 0), TicTacToePlayer.player2);
      expect(controller.game.currentPlayer, TicTacToePlayer.player1);
      expect(controller.supportsRevert, isTrue);
    });

    test('rejects placing on an already occupied cell', () {
      final controller = TicTacToeMatchController(mode: GameMode.local);
      addTearDown(controller.dispose);

      expect(controller.submitLocalCell(1, 1), isTrue);
      expect(controller.submitLocalCell(1, 1), isFalse);
      expect(controller.game.moveCount, 1);
    });

    test('rejects further input once the game is over', () {
      final controller = TicTacToeMatchController(mode: GameMode.local);
      addTearDown(controller.dispose);

      controller.submitLocalCell(0, 0); // P1
      controller.submitLocalCell(1, 0); // P2
      controller.submitLocalCell(0, 1); // P1
      controller.submitLocalCell(1, 1); // P2
      controller.submitLocalCell(0, 2); // P1 -> WIN!

      expect(controller.game.isGameOver, isTrue);
      expect(controller.canAcceptLocalInput, isFalse);
      expect(controller.submitLocalCell(2, 2), isFalse);
    });

    test('revert undoes the last move and restart resets the match', () {
      final controller = TicTacToeMatchController(mode: GameMode.local);
      addTearDown(controller.dispose);

      controller.submitLocalCell(1, 1);
      expect(controller.canRevert, isTrue);

      controller.revert();
      expect(controller.game.moveCount, 0);
      expect(controller.game.getCell(1, 1), isNull);

      controller.submitLocalCell(0, 0); // P1
      controller.submitLocalCell(1, 0); // P2
      controller.submitLocalCell(0, 1); // P1
      controller.submitLocalCell(1, 1); // P2
      controller.submitLocalCell(0, 2); // P1 -> WIN!
      expect(controller.game.isGameOver, isTrue);

      controller.restart();
      expect(controller.game.isGameOver, isFalse);
      expect(controller.game.moveCount, 0);
      expect(controller.canRevert, isFalse);
    });
  });

  group('TicTacToeMatchController - Bot', () {
    test('accepts Blue input, then produces a Red engine move', () async {
      final controller = TicTacToeMatchController(
        mode: GameMode.bot,
        botThinkDuration: Duration.zero,
      );
      addTearDown(controller.dispose);

      expect(controller.submitLocalCell(0, 0), isTrue);
      expect(controller.game.getCell(0, 0), TicTacToePlayer.player1);
      expect(controller.isBotThinking, isTrue);
      expect(controller.submitLocalCell(1, 1), isFalse);

      await Future<void>.delayed(Duration.zero);
      expect(controller.game.moveCount, 2);
      expect(controller.game.currentPlayer, TicTacToePlayer.player1);
      expect(controller.supportsRevert, isFalse);
      expect(controller.redWinnerLabel, 'BOT\nWINS!');
    });

    test('cancels a pending Bot move when restarted', () async {
      final controller = TicTacToeMatchController(
        mode: GameMode.bot,
        botThinkDuration: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);

      controller.submitLocalCell(0, 0);
      controller.restart();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.game.moveCount, 0);
      expect(controller.game.currentPlayer, TicTacToePlayer.player1);
    });

    test('cancels a pending Bot move when disposed', () async {
      final controller = TicTacToeMatchController(
        mode: GameMode.bot,
        botThinkDuration: const Duration(milliseconds: 10),
      );

      controller.submitLocalCell(0, 0);
      controller.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.game.moveCount, 1);
      expect(controller.submitLocalCell(1, 1), isFalse);
    });
  });
}
