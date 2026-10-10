import 'package:app/games/snakes_and_ladders/logic/snakes_and_ladders_game.dart';
import 'package:app/games/snakes_and_ladders/models/snakes_and_ladders_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _blue = SnakesAndLaddersPlayer.player1;
const _red = SnakesAndLaddersPlayer.player2;

void main() {
  group('Setup', () {
    test('both tokens start off the board, Blue to roll', () {
      final game = SnakesAndLaddersGame();

      expect(SnakesAndLaddersGame.lastSquare, 100);
      expect(game.positionOf(_blue), 0);
      expect(game.positionOf(_red), 0);
      expect(game.isOnBoard(_blue), isFalse);
      expect(game.currentPlayer, _blue);
      expect(game.status, SnakesAndLaddersGameStatus.playing);
      expect(game.lastMove, isNull);
      expect(game.moveCount, 0);
    });

    test('nothing starts below the square a token can first reach', () {
      // A token comes on at square six, so anything on 1-5 would never
      // be found.
      for (final from in SnakesAndLaddersGame.jumps.keys) {
        expect(from, greaterThanOrEqualTo(SnakesAndLaddersGame.entryRoll));
      }
    });

    test('no snake or ladder lands you on another one', () {
      // One jump per landing is only unambiguous if nothing chains.
      for (final to in SnakesAndLaddersGame.jumps.values) {
        expect(SnakesAndLaddersGame.jumps.containsKey(to), isFalse,
            reason: 'landing on $to would set off a second jump');
      }
    });
  });

  group('Coming onto the board', () {
    test('anything but a six leaves the token waiting', () {
      final game = SnakesAndLaddersGame();

      final move = game.applyRoll(3);

      expect(move!.blocked, isTrue);
      expect(move.entered, isFalse);
      expect(game.positionOf(_blue), 0);
      expect(game.currentPlayer, _red, reason: 'and the turn passes on');
    });

    test('a six brings the token on at square six, and rolls again', () {
      final game = SnakesAndLaddersGame();

      final move = game.applyRoll(6);

      expect(move!.entered, isTrue);
      expect(move.blocked, isFalse);
      expect(move.to, 6);
      expect(game.positionOf(_blue), 6);
      expect(move.rollsAgain, isTrue);
      expect(game.currentPlayer, _blue, reason: 'a six earns another roll');
    });
  });

  group('Moving', () {
    test('a roll walks the token that many squares', () {
      final game = SnakesAndLaddersGame()..debugConfigure(bluePosition: 12);

      final move = game.applyRoll(3);

      expect(move!.from, 12);
      expect(move.landedOn, 15);
      expect(move.to, 15);
      expect(move.steps, 3);
      expect(move.jump, isNull);
      expect(game.currentPlayer, _red);
    });

    test('a ladder carries the token up', () {
      final game = SnakesAndLaddersGame()..debugConfigure(bluePosition: 25);

      final move = game.applyRoll(3);

      expect(move!.landedOn, 28);
      expect(move.jump, const Jump(28, 84));
      expect(move.jump!.isLadder, isTrue);
      expect(move.to, 84);
      expect(game.positionOf(_blue), 84);
    });

    test('a snake drops the token back down', () {
      final game = SnakesAndLaddersGame()..debugConfigure(bluePosition: 60);

      final move = game.applyRoll(2);

      expect(move!.landedOn, 62);
      expect(move.jump, const Jump(62, 19));
      expect(move.jump!.isSnake, isTrue);
      expect(move.to, 19);
      expect(game.positionOf(_blue), 19);
    });

    test('a six rolls again, any other roll passes the turn', () {
      final game = SnakesAndLaddersGame()..debugConfigure(bluePosition: 12);

      game.applyRoll(6);
      expect(game.currentPlayer, _blue);

      game.applyRoll(2);
      expect(game.currentPlayer, _red);
    });

    test('the two tokens are tracked apart', () {
      final game = SnakesAndLaddersGame()
        ..debugConfigure(bluePosition: 12, redPosition: 30);

      game.applyRoll(2);

      expect(game.positionOf(_blue), 14);
      expect(game.positionOf(_red), 30);
    });
  });

  group('Finishing', () {
    test('the last square has to be hit exactly', () {
      final game = SnakesAndLaddersGame()..debugConfigure(bluePosition: 97);

      final move = game.applyRoll(5);

      expect(move!.blocked, isTrue);
      expect(move.to, 97, reason: 'it stays where it was');
      expect(game.positionOf(_blue), 97);
      expect(game.isGameOver, isFalse);
      expect(game.currentPlayer, _red);
    });

    test('an exact roll onto the last square wins it', () {
      final game = SnakesAndLaddersGame()..debugConfigure(bluePosition: 97);

      final move = game.applyRoll(3);

      expect(move!.to, 100);
      expect(move.isTerminal, isTrue);
      expect(game.status, SnakesAndLaddersGameStatus.won);
      expect(game.winner, _blue);
      expect(game.isGameOver, isTrue);
    });

    test('a ladder onto the last square wins it too', () {
      final game = SnakesAndLaddersGame()..debugConfigure(bluePosition: 78);

      final move = game.applyRoll(2);

      expect(move!.landedOn, 80);
      expect(move.to, 100);
      expect(game.winner, _blue);
    });

    test('a blocked roll of six still earns another roll', () {
      final game = SnakesAndLaddersGame()..debugConfigure(bluePosition: 97);

      final move = game.applyRoll(6);

      expect(move!.blocked, isTrue);
      expect(move.rollsAgain, isTrue);
      expect(game.currentPlayer, _blue);
    });

    test('a finished game takes no more rolls', () {
      final game = SnakesAndLaddersGame()..debugConfigure(bluePosition: 97);

      game.applyRoll(3);
      expect(game.isGameOver, isTrue);

      expect(game.applyRoll(4), isNull);
      expect(game.canRoll, isFalse);
    });
  });

  group('Rejections and reset', () {
    test('only a real die face is accepted', () {
      final game = SnakesAndLaddersGame();

      expect(game.applyRoll(0), isNull);
      expect(game.applyRoll(7), isNull);
      expect(game.applyRoll(-1), isNull);
      expect(game.moveCount, 0);
    });

    test('reset puts both tokens back off the board', () {
      final game = SnakesAndLaddersGame()
        ..debugConfigure(bluePosition: 40, redPosition: 70)
        ..applyRoll(2)
        ..reset();

      expect(game.positionOf(_blue), 0);
      expect(game.positionOf(_red), 0);
      expect(game.currentPlayer, _blue);
      expect(game.moveCount, 0);
      expect(game.lastMove, isNull);
    });
  });

  group('Where the squares sit', () {
    test('the numbering snakes up from the bottom left', () {
      expect(SnakesAndLaddersGame.gridFor(1), (9, 0));
      expect(SnakesAndLaddersGame.gridFor(10), (9, 9));
      expect(SnakesAndLaddersGame.gridFor(11), (8, 9),
          reason: 'the next row starts directly above, running back');
      expect(SnakesAndLaddersGame.gridFor(20), (8, 0));
      expect(SnakesAndLaddersGame.gridFor(21), (7, 0));
      // Ten rows means the top one runs right to left, so the last
      // square is the top *left* corner, not the top right.
      expect(SnakesAndLaddersGame.gridFor(91), (0, 9));
      expect(SnakesAndLaddersGame.gridFor(100), (0, 0));
    });

    test('every square has its own place on the grid', () {
      final seen = <(int, int)>{};
      for (var square = 1; square <= SnakesAndLaddersGame.lastSquare; square++) {
        final cell = SnakesAndLaddersGame.gridFor(square);
        expect(cell.$1, inInclusiveRange(0, SnakesAndLaddersGame.rows - 1));
        expect(cell.$2, inInclusiveRange(0, SnakesAndLaddersGame.columns - 1));
        expect(seen.add(cell), isTrue, reason: '$square reuses a cell');
      }
      expect(seen, hasLength(SnakesAndLaddersGame.lastSquare));
    });
  });
}
