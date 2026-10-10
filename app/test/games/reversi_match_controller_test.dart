import 'package:app/games/reversi/models/reversi_models.dart';
import 'package:app/games/reversi/presentation/reversi_match_controller.dart';
import 'package:app/models/game_definition.dart';
import 'package:flutter_test/flutter_test.dart';

const _blue = ReversiPlayer.player1;
const _red = ReversiPlayer.player2;

void main() {
  test('both local players place discs, turn about', () {
    final controller = ReversiMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    expect(controller.submitLocalMove(2, 3), isTrue);
    expect(controller.game.discAt(2, 3), _blue);
    expect(controller.game.currentPlayer, _red);

    expect(controller.submitLocalMove(2, 2), isTrue);
    expect(controller.game.discAt(2, 2), _red);
    expect(controller.game.currentPlayer, _blue);
    expect(controller.supportsRevert, isTrue);
  });

  test('a square that captures nothing is refused and costs no turn', () {
    final controller = ReversiMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    expect(controller.submitLocalMove(0, 0), isFalse);
    expect(controller.game.moveCount, 0);
    expect(controller.game.currentPlayer, _blue);
  });

  test('lastMove carries what the screen has to animate', () {
    final controller = ReversiMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    controller.submitLocalMove(2, 3);

    final move = controller.lastMove;
    expect(move, isNotNull);
    expect(move!.player, _blue);
    expect(move.position, const ReversiPosition(2, 3));
    expect(move.flipped, [const ReversiPosition(3, 3)]);
  });

  test('restart and revert clear lastMove so the board snaps', () {
    final controller = ReversiMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    controller.submitLocalMove(2, 3);
    expect(controller.lastMove, isNotNull);

    controller.revert();
    expect(controller.lastMove, isNull);
    expect(controller.game.moveCount, 0);
    expect(controller.game.discAt(3, 3), _red, reason: 'the flip came back');

    controller.submitLocalMove(2, 3);
    controller.restart();
    expect(controller.lastMove, isNull);
    expect(controller.game.moveCount, 0);
  });

  test('notifies its listener on every accepted move', () {
    final controller = ReversiMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.submitLocalMove(2, 3);
    controller.submitLocalMove(0, 0); // refused
    controller.submitLocalMove(2, 2);

    expect(notifications, 2);
  });

  test('a disposed controller stops accepting input', () {
    final controller = ReversiMatchController(mode: GameMode.local);
    controller.dispose();

    expect(controller.canAcceptLocalInput, isFalse);
    expect(controller.submitLocalMove(2, 3), isFalse);
  });

  group('Bot mode', () {
    test('answers a human move on its own', () async {
      final controller = ReversiMatchController(
        mode: GameMode.bot,
        botThinkDuration: Duration.zero,
      );
      addTearDown(controller.dispose);

      expect(controller.submitLocalMove(2, 3), isTrue);
      expect(controller.isBotThinking, isTrue);
      expect(controller.submitLocalMove(2, 2), isFalse,
          reason: 'the board belongs to the bot while it thinks');

      await Future<void>.delayed(Duration.zero);

      expect(controller.game.moveCount, 2);
      expect(controller.game.currentPlayer, _blue);
      expect(controller.isBotThinking, isFalse);
    });

    test('waits for the board to settle before answering', () async {
      final controller = ReversiMatchController(
        mode: GameMode.bot,
        botThinkDuration: Duration.zero,
      );
      addTearDown(controller.dispose);

      // Stand in for the screen: it claims the board the moment a move
      // lands and releases it when the flip has played out.
      controller.addListener(() {
        if (controller.game.moveCount == 1) {
          controller.setPresentationBusy(true);
        }
      });

      controller.submitLocalMove(2, 3);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.game.moveCount, 1,
          reason: 'the bot must not play over the flip');
      expect(controller.isBotThinking, isFalse);

      controller.setPresentationBusy(false);
      await Future<void>.delayed(Duration.zero);

      expect(controller.game.moveCount, 2, reason: 'and then it answers');
    });

    test('never offers Revert, and labels Red as the bot', () {
      final controller = ReversiMatchController(mode: GameMode.bot);
      addTearDown(controller.dispose);

      expect(controller.supportsRevert, isFalse);
      expect(controller.canRevert, isFalse);
      expect(controller.redWinnerLabel, 'BOT\nWINS!');
    });

    test('a pending bot move is dropped on restart', () async {
      final controller = ReversiMatchController(
        mode: GameMode.bot,
        botThinkDuration: const Duration(milliseconds: 20),
      );
      addTearDown(controller.dispose);

      controller.submitLocalMove(2, 3);
      controller.restart();

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(controller.game.moveCount, 0);
      expect(controller.game.currentPlayer, _blue);
      expect(controller.isBotThinking, isFalse);
    });

    test('a pending bot move is dropped when disposed', () async {
      final controller = ReversiMatchController(
        mode: GameMode.bot,
        botThinkDuration: const Duration(milliseconds: 20),
      );

      controller.submitLocalMove(2, 3);
      controller.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(controller.game.moveCount, 1);
    });
  });

  test('the red winner label is the plain two-player wording', () {
    final controller = ReversiMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    expect(controller.redWinnerLabel, 'RED PLAYER\nWINS!');
  });
}
