import 'package:app/games/dots_and_boxes/bot/simple_dots_and_boxes_bot_strategy.dart';
import 'package:app/games/dots_and_boxes/logic/dots_and_boxes_game.dart';
import 'package:app/games/dots_and_boxes/models/dots_and_boxes_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _red = DotsAndBoxesPlayer.player2;

/// The three sides of box (row, col) other than its top.
List<BoxEdge> _threeSidesOf(int row, int col) => [
      BoxEdge.vertical(row, col),
      BoxEdge.vertical(row, col + 1),
      BoxEdge.horizontal(row + 1, col),
    ];

void main() {
  final bot = SimpleDotsAndBoxesBotStrategy();

  test('always answers with a line that can be drawn', () {
    final game = DotsAndBoxesGame()
      ..tryDrawEdge(const BoxEdge.horizontal(0, 0));

    final edge = bot.chooseEdge(game);

    expect(edge, isNotNull);
    expect(game.canDraw(edge!), isTrue);
  });

  test('takes a box that is already on three sides', () {
    final game = DotsAndBoxesGame()
      ..debugPlay(_threeSidesOf(0, 0), startingPlayer: _red);
    // debugPlay left the fourth side open and the turn with Blue; hand
    // it to Red by playing a quiet line somewhere else.
    game.tryDrawEdge(const BoxEdge.horizontal(7, 4));

    expect(game.currentPlayer, _red);
    expect(bot.chooseEdge(game), const BoxEdge.horizontal(0, 0));
  });

  test('keeps taking while there are free boxes', () {
    final game = DotsAndBoxesGame()
      ..debugPlay([
        ..._threeSidesOf(0, 0),
        ..._threeSidesOf(0, 2),
      ], startingPlayer: _red);
    // Six quiet lines alternate the turn straight back to Red.
    expect(game.currentPlayer, _red);

    final first = bot.chooseEdge(game)!;
    final firstMove = game.tryDrawEdge(first);
    expect(firstMove!.claimedBoxes, isNotEmpty);
    expect(firstMove.playsAgain, isTrue);

    final second = bot.chooseEdge(game)!;
    final secondMove = game.tryDrawEdge(second);
    expect(secondMove!.claimedBoxes, isNotEmpty,
        reason: 'the other free box goes too');
    expect(game.boxesOwnedBy(_red), 2);
  });

  test('will not hand the opponent a box when it has a safe line', () {
    // Box (0,0) sits on two sides; drawing a third would give it away.
    final game = DotsAndBoxesGame()
      ..debugPlay([
        const BoxEdge.horizontal(0, 0),
        const BoxEdge.vertical(0, 0),
      ], startingPlayer: _red);
    // Blue's line above left the turn with Red.
    expect(game.currentPlayer, _red);

    final edge = bot.chooseEdge(game)!;
    final move = game.tryDrawEdge(edge)!;

    expect(move.claimedBoxes, isEmpty);
    var gifts = 0;
    for (var row = 0; row < DotsAndBoxesGame.boxRows; row++) {
      for (var col = 0; col < DotsAndBoxesGame.boxColumns; col++) {
        if (game.boxOwner(row, col) == null && game.sidesDrawn(row, col) == 3) {
          gifts++;
        }
      }
    }
    expect(gifts, 0, reason: 'an early board always has a safe line');
  });

  test('leaves the board exactly as it found it', () {
    final game = DotsAndBoxesGame()
      ..debugPlay(_threeSidesOf(2, 2), startingPlayer: _red);
    final moveCount = game.moveCount;
    final player = game.currentPlayer;
    final blue = game.blueScore;

    bot.chooseEdge(game);

    expect(game.moveCount, moveCount);
    expect(game.currentPlayer, player);
    expect(game.blueScore, blue);
    expect(game.isDrawn(const BoxEdge.horizontal(2, 2)), isFalse);
  });

  test('has nothing to say once the game is over', () {
    final game = DotsAndBoxesGame();
    for (var row = 0; row < DotsAndBoxesGame.dotRows; row++) {
      for (var col = 0; col < DotsAndBoxesGame.boxColumns; col++) {
        game.tryDrawEdge(BoxEdge.horizontal(row, col));
      }
    }
    for (var row = 0; row < DotsAndBoxesGame.boxRows; row++) {
      for (var col = 0; col < DotsAndBoxesGame.dotColumns; col++) {
        game.tryDrawEdge(BoxEdge.vertical(row, col));
      }
    }

    expect(game.isGameOver, isTrue);
    expect(bot.chooseEdge(game), isNull);
  });

  test('a bot-versus-bot match fills the board and ends', () {
    final game = DotsAndBoxesGame();

    var moves = 0;
    while (!game.isGameOver && moves < DotsAndBoxesGame.totalEdges + 5) {
      final edge = bot.chooseEdge(game);
      if (edge == null) break;
      expect(game.tryDrawEdge(edge), isNotNull);
      moves++;
    }

    expect(game.isGameOver, isTrue);
    expect(moves, DotsAndBoxesGame.totalEdges);
    expect(game.blueScore + game.redScore,
        DotsAndBoxesGame.boxRows * DotsAndBoxesGame.boxColumns);
  });
}
