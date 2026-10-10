import 'package:app/games/hex/bot/simple_hex_bot_strategy.dart';
import 'package:app/games/hex/logic/hex_game.dart';
import 'package:app/games/hex/models/hex_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _blue = HexPlayer.player1;
const _red = HexPlayer.player2;

List<List<HexPlayer?>> _board(List<(int, int, HexPlayer)> stones) {
  final cells = List.generate(
    HexGame.size,
    (_) => List<HexPlayer?>.filled(HexGame.size, null),
  );
  for (final (row, col, player) in stones) {
    cells[row][col] = player;
  }
  return cells;
}

/// A straight run along one row, which is the direction Blue joins.
List<(int, int, HexPlayer)> _across(int row, HexPlayer player, {int? skip}) => [
      for (var col = 0; col < HexGame.size; col++)
        if (col != skip) (row, col, player),
    ];

/// A straight run down one column, which is the direction Red joins.
List<(int, int, HexPlayer)> _down(int col, HexPlayer player, {int? skip}) => [
      for (var row = 0; row < HexGame.size; row++)
        if (row != skip) (row, col, player),
    ];

void main() {
  final bot = SimpleHexBotStrategy();

  test('always answers with a cell that can be played', () {
    final game = HexGame()..tryPlace(5, 5);

    final cell = bot.chooseCell(game);

    expect(cell, isNotNull);
    expect(game.canPlace(cell!.row, cell.col), isTrue);
  });

  test('opens near the middle, where a chain has the most ways on', () {
    final game = HexGame();

    final cell = bot.chooseCell(game)!;

    // Blue opens, and on an empty board every cell is equal on
    // distance, so the centre tie-break decides it.
    expect((cell.row - 5).abs(), lessThanOrEqualTo(1));
    expect((cell.col - 5).abs(), lessThanOrEqualTo(1));
  });

  test('takes the winning cell when it has one', () {
    final game = HexGame()
      ..debugConfigure(
        cells: _board(_down(5, _red, skip: 10)),
        currentPlayer: _red,
      );

    expect(bot.chooseCell(game), const HexCell(10, 5));
  });

  test('blocks the cell that would otherwise win it for the opponent', () {
    // Blue is one cell from joining its two sides, and it is Red to
    // play: the only move that matters is standing in the gap.
    final game = HexGame()
      ..debugConfigure(
        cells: _board(_across(4, _blue, skip: 7)),
        currentPlayer: _red,
      );

    expect(bot.chooseCell(game), const HexCell(4, 7));
  });

  test('leaves the board exactly as it found it', () {
    final game = HexGame()
      ..debugConfigure(
        cells: _board([(3, 3, _blue), (4, 4, _red)]),
        currentPlayer: _red,
      );

    bot.chooseCell(game);

    expect(game.moveCount, 0);
    expect(game.currentPlayer, _red);
    expect(game.stoneAt(3, 3), _blue);
    expect(game.stoneAt(4, 4), _red);
    expect(game.status, HexGameStatus.playing);
    expect(game.canRevert, isFalse);
  });

  test('has nothing to say once the game is over', () {
    final game = HexGame()
      ..debugConfigure(cells: _board(_across(5, _blue)), currentPlayer: _red);

    expect(game.isGameOver, isTrue);
    expect(bot.chooseCell(game), isNull);
  });

  test('a bot-versus-bot match ends in a win, never a stalemate', () {
    final game = HexGame();

    var moves = 0;
    while (!game.isGameOver && moves <= HexGame.size * HexGame.size) {
      final cell = bot.chooseCell(game);
      if (cell == null) break;
      expect(game.tryPlace(cell.row, cell.col), isNotNull);
      moves++;
    }

    expect(game.isGameOver, isTrue);
    expect(game.winner, isNotNull, reason: 'Hex cannot be drawn');
    expect(game.winningPath, isNotEmpty);
  });

  test('beats a bot that just fills the board in order', () {
    // A weak but legal opponent: it takes the first empty cell it finds.
    // The strategy should be comfortably better than that.
    final game = HexGame();

    while (!game.isGameOver) {
      if (game.currentPlayer == _red) {
        final cell = bot.chooseCell(game)!;
        game.tryPlace(cell.row, cell.col);
        continue;
      }
      outer:
      for (var row = 0; row < HexGame.size; row++) {
        for (var col = 0; col < HexGame.size; col++) {
          if (game.tryPlace(row, col) != null) break outer;
        }
      }
    }

    expect(game.winner, _red);
  });
}
