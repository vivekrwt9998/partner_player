import 'package:app/games/color_war/logic/color_war_game.dart';
import 'package:app/games/color_war/models/color_war_models.dart';
import 'package:app/games/color_war/presentation/color_war_match_controller.dart';
import 'package:app/models/game_definition.dart';
import 'package:flutter_test/flutter_test.dart';

const _p1 = ColorWarPlayer.player1;
const _p2 = ColorWarPlayer.player2;

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

/// A controller over a board that is one orb away from a chain reaction.
ColorWarMatchController _primedController({
  GameMode mode = GameMode.local,
  Duration blastStep = Duration.zero,
  Duration botThink = Duration.zero,
}) {
  final game = ColorWarGame()
    ..debugConfigure(
      cells: _board([
        (0, 0, _p1, 1),
        (0, 1, _p1, 2),
        (4, 4, _p2, 1),
      ]),
      currentPlayer: _p1,
    );
  return ColorWarMatchController(
    mode: mode,
    game: game,
    blastStepDuration: blastStep,
    botThinkDuration: botThink,
  );
}

void main() {
  group('ColorWarMatchController - Local', () {
    test('both players place orbs, turn about', () {
      final controller = ColorWarMatchController(mode: GameMode.local);
      addTearDown(controller.dispose);

      expect(controller.submitLocalCell(2, 2), isTrue);
      expect(controller.game.cellAt(2, 2).owner, _p1);
      expect(controller.game.currentPlayer, _p2);

      expect(controller.submitLocalCell(0, 0), isTrue);
      expect(controller.game.cellAt(0, 0).owner, _p2);
      expect(controller.game.currentPlayer, _p1);
      expect(controller.supportsRevert, isTrue);
    });

    test('rejects a cell the opponent already holds', () {
      final controller = ColorWarMatchController(mode: GameMode.local);
      addTearDown(controller.dispose);

      expect(controller.submitLocalCell(2, 2), isTrue);
      expect(controller.submitLocalCell(2, 2), isFalse);
      expect(controller.game.moveCount, 1);
    });

    test('the board is locked while a reaction spreads, then reopens',
        () async {
      final controller = _primedController(
        blastStep: const Duration(milliseconds: 5),
      );
      addTearDown(controller.dispose);

      controller.submitLocalCell(0, 0);

      expect(controller.isReacting, isTrue);
      expect(controller.canAcceptLocalInput, isFalse);
      expect(controller.submitLocalCell(3, 3), isFalse);
      expect(controller.canRevert, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(controller.isReacting, isFalse);
      expect(controller.canAcceptLocalInput, isTrue);
      expect(controller.game.currentPlayer, _p2,
          reason: 'the turn passes only once the board settles');
    });

    test('a reaction is reported wave by wave, not as one jump', () async {
      final controller = _primedController(
        blastStep: const Duration(milliseconds: 5),
      );
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.submitLocalCell(0, 0);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(notifications, greaterThan(2),
          reason: 'the placement plus at least two waves');
    });

    test('restart cancels a reaction that is still in flight', () async {
      final controller = _primedController(
        blastStep: const Duration(milliseconds: 20),
      );
      addTearDown(controller.dispose);

      controller.submitLocalCell(0, 0);
      expect(controller.isReacting, isTrue);
      controller.restart();

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(controller.isReacting, isFalse);
      expect(controller.game.moveCount, 0);
      expect(controller.game.cellsOwnedBy(_p1), 0);
    });

    test('revert undoes a whole reaction', () async {
      final controller = _primedController(
        blastStep: const Duration(milliseconds: 5),
      );
      addTearDown(controller.dispose);

      controller.submitLocalCell(0, 0);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(controller.canRevert, isTrue);

      controller.revert();

      expect(controller.game.cellAt(0, 0), const ColorWarCell(owner: _p1, orbs: 1));
      expect(controller.game.cellAt(0, 1), const ColorWarCell(owner: _p1, orbs: 2));
      expect(controller.game.currentPlayer, _p1);
    });
  });

  group('ColorWarMatchController - Bot', () {
    test('accepts Blue input, then answers as Red', () async {
      final controller = ColorWarMatchController(
        mode: GameMode.bot,
        botThinkDuration: Duration.zero,
        blastStepDuration: Duration.zero,
      );
      addTearDown(controller.dispose);

      expect(controller.submitLocalCell(2, 2), isTrue);
      expect(controller.isBotThinking, isTrue);
      expect(controller.submitLocalCell(0, 0), isFalse);

      await Future<void>.delayed(Duration.zero);

      expect(controller.game.moveCount, 2);
      expect(controller.game.currentPlayer, _p1);
      expect(controller.supportsRevert, isFalse);
      expect(controller.redWinnerLabel, 'BOT\nWINS!');
    });

    test('the bot waits for the reaction to finish before replying',
        () async {
      final controller = _primedController(
        mode: GameMode.bot,
        blastStep: const Duration(milliseconds: 5),
      );
      addTearDown(controller.dispose);

      controller.submitLocalCell(0, 0);

      expect(controller.isReacting, isTrue);
      expect(controller.isBotThinking, isFalse,
          reason: 'it must not think on a board that is still moving');

      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(controller.isReacting, isFalse);
      expect(controller.game.moveCount, greaterThanOrEqualTo(2),
          reason: 'Blue placed, then the bot answered');
    });

    test('a pending bot move is dropped when the controller is disposed',
        () async {
      final controller = ColorWarMatchController(
        mode: GameMode.bot,
        botThinkDuration: const Duration(milliseconds: 10),
      );

      controller.submitLocalCell(2, 2);
      controller.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(controller.game.moveCount, 1);
      expect(controller.submitLocalCell(0, 0), isFalse);
    });
  });
}
