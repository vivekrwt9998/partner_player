import 'package:app/games/reversi/bot/simple_reversi_bot_strategy.dart';
import 'package:app/games/reversi/logic/reversi_game.dart';
import 'package:app/games/reversi/models/reversi_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _blue = ReversiPlayer.player1;
const _red = ReversiPlayer.player2;

List<List<ReversiPlayer?>> _board(List<(int, int, ReversiPlayer)> discs) {
  final grid = List.generate(
    ReversiGame.size,
    (_) => List<ReversiPlayer?>.filled(ReversiGame.size, null),
  );
  for (final (row, col, player) in discs) {
    grid[row][col] = player;
  }
  return grid;
}

void main() {
  final bot = SimpleReversiBotStrategy();

  test('always answers with a legal square', () {
    final game = ReversiGame()..tryPlace(2, 3);

    final cell = bot.chooseCell(game);

    expect(cell, isNotNull);
    expect(game.canPlace(cell!.$1, cell.$2), isTrue);
  });

  test('takes a corner when one is on offer', () {
    // Red can play the top-left corner, flipping the diagonal, or settle
    // for a square in the middle.
    final game = ReversiGame()
      ..debugConfigure(
        cells: _board([
          (1, 1, _blue),
          (2, 2, _red),
          (4, 4, _blue),
          (4, 5, _red),
        ]),
        currentPlayer: _red,
      );

    expect(game.canPlace(0, 0), isTrue, reason: 'the corner really is legal');
    expect(bot.chooseCell(game), (0, 0));
  });

  test('avoids the square that hands a corner over', () {
    // (1,1) would be legal for Red but gives Blue the corner behind it;
    // there is a quiet alternative on the other side of the board.
    final game = ReversiGame()
      ..debugConfigure(
        cells: _board([
          (2, 2, _blue),
          (3, 3, _red),
          (5, 5, _blue),
          (5, 6, _red),
        ]),
        currentPlayer: _red,
      );

    expect(game.canPlace(1, 1), isTrue);
    expect(bot.chooseCell(game), isNot((1, 1)));
  });

  test('takes the move that wins the game outright', () {
    // Red's placement fills the last gap and leaves Blue with nothing.
    final game = ReversiGame()
      ..debugConfigure(
        cells: _board([
          for (var col = 0; col < ReversiGame.size; col++) (0, col, _red),
          for (var col = 0; col < ReversiGame.size; col++) (1, col, _red),
          (2, 0, _red),
          for (var col = 1; col < ReversiGame.size - 1; col++) (2, col, _blue),
        ]),
        currentPlayer: _red,
      );

    final cell = bot.chooseCell(game);
    expect(cell, (2, 7));

    game.tryPlace(cell!.$1, cell.$2);
    expect(game.winner, _red);
  });

  test('leaves the board exactly as it found it', () {
    final game = ReversiGame()..tryPlace(2, 3);
    final before = [
      for (var row = 0; row < ReversiGame.size; row++)
        [
          for (var col = 0; col < ReversiGame.size; col++)
            game.discAt(row, col),
        ],
    ];
    final moveCount = game.moveCount;

    bot.chooseCell(game);

    for (var row = 0; row < ReversiGame.size; row++) {
      for (var col = 0; col < ReversiGame.size; col++) {
        expect(game.discAt(row, col), before[row][col],
            reason: 'square $row,$col');
      }
    }
    expect(game.moveCount, moveCount);
    expect(game.currentPlayer, _red);
  });

  test('has nothing to say once the game is over', () {
    final game = ReversiGame()
      ..debugConfigure(
        cells: _board([
          (0, 0, _blue),
          (0, 7, _blue),
          (7, 0, _red),
          (7, 7, _red),
        ]),
        currentPlayer: _blue,
      );

    expect(game.isGameOver, isTrue);
    expect(bot.chooseCell(game), isNull);
  });

  test('a bot-versus-bot match plays itself out to a finish', () {
    final game = ReversiGame();

    var moves = 0;
    while (!game.isGameOver && moves < 80) {
      final cell = bot.chooseCell(game);
      if (cell == null) break;
      expect(game.tryPlace(cell.$1, cell.$2), isNotNull);
      moves++;
    }

    expect(game.isGameOver, isTrue, reason: 'two bots should not stall');
    expect(game.blueScore + game.redScore, greaterThan(4));
  });
}
