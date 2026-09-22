import 'package:app/games/color_war/bot/simple_color_war_bot_strategy.dart';
import 'package:app/games/color_war/logic/color_war_game.dart';
import 'package:app/games/color_war/models/color_war_models.dart';
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

void main() {
  final bot = SimpleColorWarBotStrategy();

  test('always returns a legal cell on an open board', () {
    final game = ColorWarGame()..tryPlaceOrb(2, 2);

    final cell = bot.chooseCell(game);

    expect(cell, isNotNull);
    expect(game.canPlace(cell!.$1, cell.$2), isTrue);
  });

  test('never plays into a cell the opponent holds', () {
    final game = ColorWarGame()
      ..debugConfigure(
        cells: _board([
          for (var col = 0; col < 5; col++) (0, col, _p1, 1),
          (4, 4, _p2, 1),
        ]),
        currentPlayer: _p2,
      );

    final cell = bot.chooseCell(game)!;

    expect(game.cellAt(cell.$1, cell.$2).owner, isNot(_p1));
  });

  test('takes the winning chain when one is there', () {
    // Red's corner is one orb from bursting, and the burst takes Blue's
    // only cell with it.
    final game = ColorWarGame()
      ..debugConfigure(
        cells: _board([
          (0, 0, _p2, 1),
          (0, 1, _p1, 1),
        ]),
        currentPlayer: _p2,
      );

    final cell = bot.chooseCell(game);

    expect(cell, (0, 0));

    game.tryPlaceOrb(cell!.$1, cell.$2);
    game.settle();
    expect(game.winner, _p2);
  });

  test('does not hand a cell to an opponent who is about to burst', () {
    // (2,2) is next to a Blue cell one orb short of bursting; (4,4) is a
    // quiet corner far away.
    final game = ColorWarGame()
      ..debugConfigure(
        cells: _board([
          (2, 1, _p1, 3),
          (0, 0, _p1, 1),
          (4, 4, _p2, 1),
        ]),
        currentPlayer: _p2,
      );

    final cell = bot.chooseCell(game)!;

    expect(cell, isNot((2, 2)),
        reason: 'that cell would be captured straight back');
  });

  test('has nothing to say once the game is over or mid-reaction', () {
    final finished = ColorWarGame()
      ..debugConfigure(
        cells: _board([(0, 0, _p1, 1), (0, 1, _p2, 1)]),
        currentPlayer: _p1,
      );
    finished.tryPlaceOrb(0, 0);
    finished.settle();
    expect(bot.chooseCell(finished), isNull);

    final reacting = ColorWarGame()
      ..debugConfigure(
        cells: _board([(0, 0, _p1, 1), (4, 4, _p2, 1)]),
        currentPlayer: _p1,
      );
    reacting.tryPlaceOrb(0, 0);
    expect(reacting.hasPendingBlasts, isTrue);
    expect(bot.chooseCell(reacting), isNull);
  });

  test('leaves the real board untouched while it thinks', () {
    final game = ColorWarGame()..tryPlaceOrb(2, 2);
    final before = [
      for (var row = 0; row < game.rows; row++)
        [for (var col = 0; col < game.cols; col++) game.cellAt(row, col)],
    ];

    bot.chooseCell(game);

    for (var row = 0; row < game.rows; row++) {
      for (var col = 0; col < game.cols; col++) {
        expect(game.cellAt(row, col), before[row][col]);
      }
    }
    expect(game.currentPlayer, _p2);
  });

  test('a bot-versus-bot match finishes with a winner', () {
    final game = ColorWarGame();

    var moves = 0;
    while (!game.isGameOver && moves < 400) {
      final cell = bot.chooseCell(game);
      if (cell == null) break;
      game.tryPlaceOrb(cell.$1, cell.$2);
      game.settle();
      moves++;
    }

    expect(game.isGameOver, isTrue,
        reason: 'two greedy bots should not stalemate');
    expect(game.winner, isNotNull);
  });
}
