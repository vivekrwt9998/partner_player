import 'package:app/games/four_in_a_row/models/four_in_a_row_models.dart';
import 'package:app/games/four_in_a_row/presentation/four_in_a_row_match_controller.dart';
import 'package:app/models/game_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FourInARowMatchController - Local', () {
    test('allows both local players to provide moves', () {
      final controller = FourInARowMatchController(mode: GameMode.local);
      addTearDown(controller.dispose);

      expect(controller.submitLocalColumn(3), isTrue);
      expect(controller.activeMove!.player, FourInARowPlayer.player1);
      controller.onMoveAnimationCompleted();

      expect(controller.submitLocalColumn(3), isTrue);
      expect(controller.activeMove!.player, FourInARowPlayer.player2);
      expect(controller.supportsRevert, isTrue);
      expect(controller.redWinnerLabel, 'RED PLAYER\nWINS!');
    });

    test('rejects rapid input while a move is animating', () {
      final controller = FourInARowMatchController(mode: GameMode.local);
      addTearDown(controller.dispose);

      expect(controller.submitLocalColumn(3), isTrue);
      expect(controller.submitLocalColumn(4), isFalse);
      expect(controller.game.moveCount, 1);
    });
  });

  group('FourInARowMatchController - Bot', () {
    test('accepts Blue input, then produces a Red engine move', () async {
      final controller = FourInARowMatchController(
        mode: GameMode.bot,
        botThinkDuration: Duration.zero,
      );
      addTearDown(controller.dispose);

      expect(controller.submitLocalColumn(3), isTrue);
      expect(controller.activeMove!.player, FourInARowPlayer.player1);
      expect(controller.submitLocalColumn(4), isFalse);

      controller.onMoveAnimationCompleted();
      expect(controller.isBotThinking, isTrue);
      expect(controller.submitLocalColumn(4), isFalse);

      await Future<void>.delayed(Duration.zero);
      expect(controller.activeMove, isNotNull);
      expect(controller.activeMove!.player, FourInARowPlayer.player2);
      expect(controller.game.moveCount, 2);
      expect(controller.supportsRevert, isFalse);
      expect(controller.redWinnerLabel, 'BOT\nWINS!');
    });

    test('cancels a pending Bot move when restarted', () async {
      final controller = FourInARowMatchController(
        mode: GameMode.bot,
        botThinkDuration: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);

      controller.submitLocalColumn(3);
      controller.onMoveAnimationCompleted();
      controller.restart();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.game.moveCount, 0);
      expect(controller.game.currentPlayer, FourInARowPlayer.player1);
    });

    test('cancels a pending Bot move when disposed', () async {
      final controller = FourInARowMatchController(
        mode: GameMode.bot,
        botThinkDuration: const Duration(milliseconds: 10),
      );

      controller.submitLocalColumn(3);
      controller.onMoveAnimationCompleted();
      controller.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.game.moveCount, 1);
      expect(controller.submitLocalColumn(4), isFalse);
    });
  });
}
