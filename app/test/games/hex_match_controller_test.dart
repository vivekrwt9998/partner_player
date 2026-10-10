import 'package:app/games/hex/logic/hex_game.dart';
import 'package:app/games/hex/models/hex_models.dart';
import 'package:app/games/hex/presentation/hex_match_controller.dart';
import 'package:app/models/game_definition.dart';
import 'package:flutter_test/flutter_test.dart';

const _blue = HexPlayer.player1;
const _red = HexPlayer.player2;

List<List<HexPlayer?>> _rowOfBlue(int row, {required int skip}) {
  final cells = List.generate(
    HexGame.size,
    (_) => List<HexPlayer?>.filled(HexGame.size, null),
  );
  for (var col = 0; col < HexGame.size; col++) {
    if (col != skip) cells[row][col] = _blue;
  }
  return cells;
}

void main() {
  test('both local players place stones, turn about', () {
    final controller = HexMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    expect(controller.submitLocalMove(0, 0), isTrue);
    expect(controller.game.currentPlayer, _red);

    expect(controller.submitLocalMove(1, 1), isTrue);
    expect(controller.game.currentPlayer, _blue);
    expect(controller.supportsRevert, isTrue);
  });

  test('a cell already taken is refused and costs no turn', () {
    final controller = HexMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    controller.submitLocalMove(3, 3);
    expect(controller.submitLocalMove(3, 3), isFalse);

    expect(controller.game.moveCount, 1);
    expect(controller.game.currentPlayer, _red);
  });

  test('lastMove carries what the screen has to animate', () {
    final controller = HexMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    controller.submitLocalMove(2, 7);

    final move = controller.lastMove;
    expect(move, isNotNull);
    expect(move!.player, _blue);
    expect(move.cell, const HexCell(2, 7));
    expect(move.winningPath, isEmpty);
    expect(move.isTerminal, isFalse);
  });

  test('a winning move brings its chain along', () {
    final controller = HexMatchController(
      mode: GameMode.local,
      game: HexGame()..debugConfigure(cells: _rowOfBlue(4, skip: 10)),
    );
    addTearDown(controller.dispose);

    expect(controller.submitLocalMove(4, 10), isTrue);

    expect(controller.lastMove!.isTerminal, isTrue);
    expect(controller.lastMove!.winningPath, hasLength(HexGame.size));
    expect(controller.game.winner, _blue);
  });

  test('the board is closed once the game is over', () {
    final controller = HexMatchController(
      mode: GameMode.local,
      game: HexGame()..debugConfigure(cells: _rowOfBlue(4, skip: 10)),
    );
    addTearDown(controller.dispose);

    controller.submitLocalMove(4, 10);

    expect(controller.canAcceptLocalInput, isFalse);
    expect(controller.submitLocalMove(0, 0), isFalse);
  });

  test('restart and revert clear lastMove so the board snaps', () {
    final controller = HexMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    controller.submitLocalMove(0, 0);
    expect(controller.lastMove, isNotNull);

    controller.revert();
    expect(controller.lastMove, isNull);
    expect(controller.game.moveCount, 0);
    expect(controller.game.stoneAt(0, 0), isNull);

    controller.submitLocalMove(0, 0);
    controller.restart();
    expect(controller.lastMove, isNull);
    expect(controller.game.moveCount, 0);
    expect(controller.game.currentPlayer, _blue);
  });

  test('Revert is offered only once there is something to take back', () {
    final controller = HexMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    expect(controller.supportsRevert, isTrue);
    expect(controller.canRevert, isFalse);

    controller.submitLocalMove(5, 5);
    expect(controller.canRevert, isTrue);
  });

  test('notifies its listener once per accepted stone', () {
    final controller = HexMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.submitLocalMove(0, 0);
    controller.submitLocalMove(0, 0); // refused
    controller.submitLocalMove(1, 0);

    expect(notifications, 2);
  });

  test('labels the Red winner for a local match', () {
    final controller = HexMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    expect(controller.redWinnerLabel, 'RED PLAYER\nWINS!');
  });

  test('a disposed controller stops accepting input', () {
    final controller = HexMatchController(mode: GameMode.local);
    controller.dispose();

    expect(controller.canAcceptLocalInput, isFalse);
    expect(controller.submitLocalMove(0, 0), isFalse);
  });

  group('Bot mode', () {
    test('answers a human stone on its own', () async {
      final controller = HexMatchController(
        mode: GameMode.bot,
        botThinkDuration: Duration.zero,
      );
      addTearDown(controller.dispose);

      expect(controller.submitLocalMove(5, 5), isTrue);
      expect(controller.isBotThinking, isTrue);
      expect(controller.submitLocalMove(5, 6), isFalse,
          reason: 'the board belongs to the bot while it thinks');

      await Future<void>.delayed(Duration.zero);

      expect(controller.game.moveCount, 2);
      expect(controller.game.currentPlayer, _blue);
      expect(controller.isBotThinking, isFalse);
    });

    test('waits for the stone to land before answering', () async {
      final controller = HexMatchController(
        mode: GameMode.bot,
        botThinkDuration: Duration.zero,
      );
      addTearDown(controller.dispose);

      // Stand in for the screen: it claims the board the moment a stone
      // lands and releases it once the stone has finished arriving.
      controller.addListener(() {
        if (controller.game.moveCount == 1) {
          controller.setPresentationBusy(true);
        }
      });

      controller.submitLocalMove(5, 5);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.game.moveCount, 1,
          reason: 'the bot must not play over the stone');

      controller.setPresentationBusy(false);
      await Future<void>.delayed(Duration.zero);

      expect(controller.game.moveCount, 2, reason: 'and then it answers');
    });

    test('never offers Revert, and labels Red as the bot', () {
      final controller = HexMatchController(mode: GameMode.bot);
      addTearDown(controller.dispose);

      expect(controller.supportsRevert, isFalse);
      expect(controller.canRevert, isFalse);
      expect(controller.redWinnerLabel, 'BOT\nWINS!');
    });

    test('a pending bot stone is dropped on restart', () async {
      final controller = HexMatchController(
        mode: GameMode.bot,
        botThinkDuration: const Duration(milliseconds: 20),
      );
      addTearDown(controller.dispose);

      controller.submitLocalMove(5, 5);
      controller.restart();

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(controller.game.moveCount, 0);
      expect(controller.game.currentPlayer, _blue);
      expect(controller.isBotThinking, isFalse);
    });

    test('a pending bot stone is dropped when disposed', () async {
      final controller = HexMatchController(
        mode: GameMode.bot,
        botThinkDuration: const Duration(milliseconds: 20),
      );

      controller.submitLocalMove(5, 5);
      controller.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(controller.game.moveCount, 1);
    });
  });
}
