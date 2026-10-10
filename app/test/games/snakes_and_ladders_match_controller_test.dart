import 'dart:math';

import 'package:app/games/snakes_and_ladders/logic/snakes_and_ladders_game.dart';
import 'package:app/games/snakes_and_ladders/models/snakes_and_ladders_models.dart';
import 'package:app/games/snakes_and_ladders/presentation/snakes_and_ladders_match_controller.dart';
import 'package:app/models/game_definition.dart';
import 'package:flutter_test/flutter_test.dart';

const _blue = SnakesAndLaddersPlayer.player1;

/// A die that hands out a fixed sequence, so a test can say exactly
/// what comes up.
class _LoadedDie implements Random {
  _LoadedDie(this.rolls);

  final List<int> rolls;
  var _next = 0;

  @override
  int nextInt(int max) {
    final roll = rolls[_next % rolls.length];
    _next++;
    return roll - 1;
  }

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

void main() {
  test('a roll reaches the board and comes back as a move', () {
    final controller = SnakesAndLaddersMatchController(
      mode: GameMode.local,
      random: _LoadedDie([6]),
    );
    addTearDown(controller.dispose);

    final move = controller.rollDice();

    expect(move, isNotNull);
    expect(move!.roll, 6);
    expect(move.entered, isTrue);
    expect(controller.game.positionOf(_blue), 6);
    expect(controller.lastMove, move);
  });

  test('notifies its listener once per roll', () {
    final controller = SnakesAndLaddersMatchController(
      mode: GameMode.local,
      random: _LoadedDie([3]),
    );
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.rollDice();
    controller.rollDice();

    expect(notifications, 2);
  });

  test('a finished match takes no more rolls', () {
    final controller = SnakesAndLaddersMatchController(
      mode: GameMode.local,
      game: SnakesAndLaddersGame()..debugConfigure(bluePosition: 97),
      random: _LoadedDie([3]),
    );
    addTearDown(controller.dispose);

    controller.rollDice();
    expect(controller.game.isGameOver, isTrue);

    expect(controller.canAcceptLocalInput, isFalse);
    expect(controller.rollDice(), isNull);
  });

  test('restart puts both tokens back and clears the last roll', () {
    final controller = SnakesAndLaddersMatchController(
      mode: GameMode.local,
      game: SnakesAndLaddersGame()
        ..debugConfigure(bluePosition: 40, redPosition: 70),
      random: _LoadedDie([2]),
    );
    addTearDown(controller.dispose);

    controller.rollDice();
    controller.restart();

    expect(controller.game.positionOf(_blue), 0);
    expect(controller.lastMove, isNull);
    expect(controller.game.moveCount, 0);
  });

  test('never offers Revert, and labels the Red winner', () {
    final controller = SnakesAndLaddersMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    expect(controller.supportsRevert, isFalse);
    expect(controller.redWinnerLabel, 'RED PLAYER\nWINS!');
  });

  test('a disposed controller stops rolling', () {
    final controller = SnakesAndLaddersMatchController(mode: GameMode.local);
    controller.dispose();

    expect(controller.canAcceptLocalInput, isFalse);
    expect(controller.rollDice(), isNull);
  });

  test('the die only ever shows a real face', () {
    final controller = SnakesAndLaddersMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    for (var i = 0; i < 200; i++) {
      final move = controller.rollDice();
      if (move == null) break;
      expect(move.roll, inInclusiveRange(1, 6));
    }
  });
}
