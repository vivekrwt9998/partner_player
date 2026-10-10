import 'package:app/games/dots_and_boxes/logic/dots_and_boxes_game.dart';
import 'package:app/games/dots_and_boxes/models/dots_and_boxes_models.dart';
import 'package:app/games/dots_and_boxes/presentation/dots_and_boxes_match_controller.dart';
import 'package:app/models/game_definition.dart';
import 'package:flutter_test/flutter_test.dart';

const _blue = DotsAndBoxesPlayer.player1;
const _red = DotsAndBoxesPlayer.player2;

void main() {
  test('both local players draw lines, turn about', () {
    final controller = DotsAndBoxesMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    expect(controller.submitLocalEdge(const BoxEdge.horizontal(0, 0)), isTrue);
    expect(controller.game.currentPlayer, _red);

    expect(controller.submitLocalEdge(const BoxEdge.vertical(0, 0)), isTrue);
    expect(controller.game.currentPlayer, _blue);
    expect(controller.supportsRevert, isTrue);
  });

  test('a line already on the board is refused and costs no turn', () {
    final controller = DotsAndBoxesMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    controller.submitLocalEdge(const BoxEdge.horizontal(0, 0));
    expect(controller.submitLocalEdge(const BoxEdge.horizontal(0, 0)), isFalse);

    expect(controller.game.moveCount, 1);
    expect(controller.game.currentPlayer, _red);
  });

  test('lastMove carries what the screen has to animate', () {
    final controller = DotsAndBoxesMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    controller.submitLocalEdge(const BoxEdge.horizontal(2, 1));

    final move = controller.lastMove;
    expect(move, isNotNull);
    expect(move!.player, _blue);
    expect(move.edge, const BoxEdge.horizontal(2, 1));
    expect(move.claimedBoxes, isEmpty);
    expect(move.playsAgain, isFalse);
  });

  test('restart and revert clear lastMove so the board snaps', () {
    final controller = DotsAndBoxesMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    controller.submitLocalEdge(const BoxEdge.horizontal(0, 0));
    expect(controller.lastMove, isNotNull);

    controller.revert();
    expect(controller.lastMove, isNull);
    expect(controller.game.moveCount, 0);
    expect(controller.game.isDrawn(const BoxEdge.horizontal(0, 0)), isFalse);

    controller.submitLocalEdge(const BoxEdge.horizontal(0, 0));
    controller.restart();
    expect(controller.lastMove, isNull);
    expect(controller.game.moveCount, 0);
  });

  test('notifies its listener once per accepted line', () {
    final controller = DotsAndBoxesMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.submitLocalEdge(const BoxEdge.horizontal(0, 0));
    controller.submitLocalEdge(const BoxEdge.horizontal(0, 0)); // refused
    controller.submitLocalEdge(const BoxEdge.vertical(0, 0));

    expect(notifications, 2);
  });

  test('a disposed controller stops accepting input', () {
    final controller = DotsAndBoxesMatchController(mode: GameMode.local);
    controller.dispose();

    expect(controller.canAcceptLocalInput, isFalse);
    expect(controller.submitLocalEdge(const BoxEdge.horizontal(0, 0)), isFalse);
  });

  group('Bot mode', () {
    test('answers a human line on its own', () async {
      final controller = DotsAndBoxesMatchController(
        mode: GameMode.bot,
        botThinkDuration: Duration.zero,
      );
      addTearDown(controller.dispose);

      expect(controller.submitLocalEdge(const BoxEdge.horizontal(0, 0)), isTrue);
      expect(controller.isBotThinking, isTrue);
      expect(controller.submitLocalEdge(const BoxEdge.vertical(0, 0)), isFalse,
          reason: 'the board belongs to the bot while it thinks');

      await Future<void>.delayed(Duration.zero);

      expect(controller.game.moveCount, 2);
      expect(controller.game.currentPlayer, _blue);
      expect(controller.isBotThinking, isFalse);
    });

    test('waits for the line to finish drawing before answering', () async {
      final controller = DotsAndBoxesMatchController(
        mode: GameMode.bot,
        botThinkDuration: Duration.zero,
      );
      addTearDown(controller.dispose);

      // Stand in for the screen: it claims the board the moment a line
      // lands and releases it when the line has drawn itself on.
      controller.addListener(() {
        if (controller.game.moveCount == 1) {
          controller.setPresentationBusy(true);
        }
      });

      controller.submitLocalEdge(const BoxEdge.horizontal(0, 0));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.game.moveCount, 1,
          reason: 'the bot must not draw over the line');

      controller.setPresentationBusy(false);
      await Future<void>.delayed(Duration.zero);

      expect(controller.game.moveCount, 2, reason: 'and then it answers');
    });

    test('keeps drawing while it is closing boxes', () async {
      // Three sides of two boxes are already down and it is Red's go, so
      // the bot should take both before handing the board back.
      final game = DotsAndBoxesGame()
        ..debugPlay([
          const BoxEdge.vertical(0, 0),
          const BoxEdge.vertical(0, 1),
          const BoxEdge.horizontal(1, 0),
          const BoxEdge.vertical(0, 2),
          const BoxEdge.vertical(0, 3),
          const BoxEdge.horizontal(1, 2),
        ], startingPlayer: _red);
      final controller = DotsAndBoxesMatchController(
        mode: GameMode.bot,
        game: game,
        botThinkDuration: Duration.zero,
      );
      addTearDown(controller.dispose);

      // Blue draws a quiet line, handing the turn to the bot.
      controller.submitLocalEdge(const BoxEdge.horizontal(8, 4));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.game.boxesOwnedBy(_red), 2,
          reason: 'closing a box earns another go, and it used both');
    });

    test('never offers Revert, and labels Red as the bot', () {
      final controller = DotsAndBoxesMatchController(mode: GameMode.bot);
      addTearDown(controller.dispose);

      expect(controller.supportsRevert, isFalse);
      expect(controller.canRevert, isFalse);
      expect(controller.redWinnerLabel, 'BOT\nWINS!');
    });

    test('a pending bot line is dropped on restart', () async {
      final controller = DotsAndBoxesMatchController(
        mode: GameMode.bot,
        botThinkDuration: const Duration(milliseconds: 20),
      );
      addTearDown(controller.dispose);

      controller.submitLocalEdge(const BoxEdge.horizontal(0, 0));
      controller.restart();

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(controller.game.moveCount, 0);
      expect(controller.game.currentPlayer, _blue);
      expect(controller.isBotThinking, isFalse);
    });

    test('a pending bot line is dropped when disposed', () async {
      final controller = DotsAndBoxesMatchController(
        mode: GameMode.bot,
        botThinkDuration: const Duration(milliseconds: 20),
      );

      controller.submitLocalEdge(const BoxEdge.horizontal(0, 0));
      controller.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(controller.game.moveCount, 1);
    });
  });
}
