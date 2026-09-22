import 'package:app/games/checkers/models/checkers_models.dart';
import 'package:app/games/checkers/presentation/checkers_match_controller.dart';
import 'package:app/models/game_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CheckersMatchController - Local', () {
    test('allows both local players to move and alternates turns', () {
      final controller = CheckersMatchController(mode: GameMode.local);
      addTearDown(controller.dispose);

      expect(controller.submitLocalMove(5, 0, 4, 1), isTrue);
      expect(controller.game.getCell(4, 1), const CheckersPiece(player: CheckersPlayer.player1, isKing: false));
      expect(controller.game.currentPlayer, CheckersPlayer.player2);

      expect(controller.submitLocalMove(2, 1, 3, 0), isTrue);
      expect(controller.game.currentPlayer, CheckersPlayer.player1);
      expect(controller.supportsRevert, isTrue);
    });

    test('rejects an illegal move', () {
      final controller = CheckersMatchController(mode: GameMode.local);
      addTearDown(controller.dispose);

      expect(controller.submitLocalMove(5, 0, 5, 2), isFalse);
      expect(controller.game.moveCount, 0);
    });

    test('revert undoes the last move and restart resets the match', () {
      final controller = CheckersMatchController(mode: GameMode.local);
      addTearDown(controller.dispose);

      controller.submitLocalMove(5, 0, 4, 1);
      expect(controller.canRevert, isTrue);

      controller.revert();
      expect(controller.game.moveCount, 0);
      expect(controller.game.getCell(5, 0), isNotNull);

      controller.submitLocalMove(5, 0, 4, 1);
      controller.restart();
      expect(controller.game.moveCount, 0);
      expect(controller.canRevert, isFalse);
      expect(controller.game.getCell(5, 0), isNotNull);
    });

    test('rejects further input once the game is over', () {
      final controller = CheckersMatchController(mode: GameMode.local);
      addTearDown(controller.dispose);

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
        controller.submitLocalMove(m.$1, m.$2, m.$3, m.$4);
        if (controller.game.isGameOver) break;
      }

      expect(controller.game.isGameOver, isTrue);
      expect(controller.canAcceptLocalInput, isFalse);
      expect(controller.submitLocalMove(0, 1, 1, 2), isFalse);
    });
  });

  group('CheckersMatchController - Bot', () {
    test('accepts Blue input, then produces a Red engine move', () async {
      final controller = CheckersMatchController(
        mode: GameMode.bot,
        botThinkDuration: Duration.zero,
      );
      addTearDown(controller.dispose);

      expect(controller.submitLocalMove(5, 0, 4, 1), isTrue);
      expect(controller.isBotThinking, isTrue);
      expect(controller.submitLocalMove(6, 1, 5, 0), isFalse);

      await Future<void>.delayed(Duration.zero);
      expect(controller.game.moveCount, 2);
      expect(controller.game.currentPlayer, CheckersPlayer.player1);
      expect(controller.supportsRevert, isFalse);
      expect(controller.redWinnerLabel, 'BOT\nWINS!');
    });

    test('cancels a pending Bot move when restarted', () async {
      final controller = CheckersMatchController(
        mode: GameMode.bot,
        botThinkDuration: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);

      controller.submitLocalMove(5, 0, 4, 1);
      controller.restart();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.game.moveCount, 0);
      expect(controller.game.currentPlayer, CheckersPlayer.player1);
    });

    test('cancels a pending Bot move when disposed', () async {
      final controller = CheckersMatchController(
        mode: GameMode.bot,
        botThinkDuration: const Duration(milliseconds: 10),
      );

      controller.submitLocalMove(5, 0, 4, 1);
      controller.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.game.moveCount, 1);
      expect(controller.submitLocalMove(6, 1, 5, 0), isFalse);
    });
  });
}
