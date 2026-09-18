import 'package:app/games/four_in_a_row/bot/simple_four_in_a_row_bot_strategy.dart';
import 'package:app/games/four_in_a_row/logic/four_in_a_row_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final strategy = SimpleFourInARowBotStrategy();

  test('prefers the center column on an empty board', () {
    expect(strategy.chooseColumn(FourInARowGame()), 3);
  });

  test('takes an immediate winning move', () {
    final game = FourInARowGame();
    for (final column in [1, 0, 1, 0, 2, 0, 2]) {
      game.dropDisc(column);
    }

    expect(strategy.chooseColumn(game), 0);
  });

  test('blocks an immediate Blue winning move', () {
    final game = FourInARowGame();
    for (final column in [0, 1, 0, 1, 0]) {
      game.dropDisc(column);
    }

    expect(strategy.chooseColumn(game), 0);
  });

  test('never selects a full center column', () {
    final game = FourInARowGame();
    for (var move = 0; move < FourInARowGame.rows; move++) {
      game.dropDisc(3);
    }

    final column = strategy.chooseColumn(game);
    expect(column, isNotNull);
    expect(column, isNot(3));
    expect(game.canDrop(column!), isTrue);
  });

  test('returns null after a terminal game', () {
    final game = FourInARowGame();
    for (final column in [0, 1, 0, 1, 0, 1, 0]) {
      game.dropDisc(column);
    }

    expect(strategy.chooseColumn(game), isNull);
  });
}
