import 'dart:math';

import 'package:app/games/air_hockey/logic/air_hockey_game.dart';
import 'package:app/games/air_hockey/models/air_hockey_models.dart';
import 'package:app/games/air_hockey/presentation/air_hockey_match_controller.dart';
import 'package:app/models/game_definition.dart';
import 'package:flutter_test/flutter_test.dart';

const _blue = AirHockeyPlayer.player1;
const _red = AirHockeyPlayer.player2;

void _run(AirHockeyMatchController controller, double seconds) {
  const frame = 1 / 60;
  var left = seconds;
  while (left > 0) {
    controller.advance(left < frame ? left : frame);
    left -= frame;
  }
}

void main() {
  test('both halves take a finger at the same time', () {
    final controller = AirHockeyMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    expect(controller.canControl(_blue), isTrue);
    expect(controller.canControl(_red), isTrue);

    controller.steer(_blue, 0.2, 1.6);
    controller.steer(_red, 0.8, 0.4);
    _run(controller, 1);

    expect(controller.game.malletFor(_blue).x, closeTo(0.2, 0.01));
    expect(controller.game.malletFor(_red).x, closeTo(0.8, 0.01));
  });

  test('releasing stops that mallet and leaves the other alone', () {
    final controller = AirHockeyMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    controller.steer(_blue, 0.2, 1.6);
    controller.steer(_red, 0.8, 0.4);
    _run(controller, 0.1);

    controller.release(_blue);
    _run(controller, 1);

    expect(controller.game.malletFor(_blue).isHeld, isFalse);
    expect(controller.game.malletFor(_red).isHeld, isTrue);
    expect(controller.game.malletFor(_red).x, closeTo(0.8, 0.01));
  });

  test('advance reports the frame the match is won, and only that one', () {
    final controller = AirHockeyMatchController(
      mode: GameMode.local,
      game: AirHockeyGame()
        ..debugConfigure(
          blueScore: 2,
          puckX: 0.5,
          puckY: 0.4,
          puckVy: -1.5,
          blueMalletX: 0.1,
          blueMalletY: 1.9,
          redMalletX: 0.1,
          redMalletY: 0.1,
        ),
    );
    addTearDown(controller.dispose);

    var wonFrames = 0;
    for (var i = 0; i < 90; i++) {
      if (controller.advance(1 / 60)) wonFrames++;
    }

    expect(wonFrames, 1);
    expect(controller.game.winner, _blue);
  });

  test('a finished match stops taking fingers', () {
    final controller = AirHockeyMatchController(
      mode: GameMode.local,
      game: AirHockeyGame()
        ..debugConfigure(
          redScore: 2,
          puckX: 0.5,
          puckY: 1.6,
          puckVy: 1.5,
          blueMalletX: 0.1,
          blueMalletY: 1.9,
          redMalletX: 0.1,
          redMalletY: 0.1,
        ),
    );
    addTearDown(controller.dispose);

    _run(controller, 1);
    expect(controller.game.isGameOver, isTrue);

    expect(controller.canAcceptLocalInput, isFalse);
    expect(controller.canControl(_blue), isFalse);
    expect(controller.canControl(_red), isFalse);
  });

  test('restart clears the score and puts the table back', () {
    final controller = AirHockeyMatchController(
      mode: GameMode.local,
      game: AirHockeyGame()..debugConfigure(blueScore: 2, redScore: 1),
    );
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.restart();

    expect(controller.game.blueScore, 0);
    expect(controller.game.redScore, 0);
    expect(controller.game.isGameOver, isFalse);
    expect(notifications, 1);
  });

  test('never offers Revert, and labels the Red winner', () {
    final controller = AirHockeyMatchController(mode: GameMode.local);
    addTearDown(controller.dispose);

    expect(controller.supportsRevert, isFalse);
    expect(controller.redWinnerLabel, 'RED PLAYER\nWINS!');
  });

  group('Bot mode', () {
    test('the far half belongs to the bot, not to a stray finger', () {
      final controller = AirHockeyMatchController(mode: GameMode.bot);
      addTearDown(controller.dispose);

      expect(controller.isBotMatch, isTrue);
      expect(controller.canControl(_blue), isTrue);
      expect(controller.canControl(_red), isFalse);

      // A finger on the bot's half is ignored, and the bot keeps its
      // own mallet.
      controller.steer(_red, 0.1, 0.1);
      _run(controller, 0.5);

      expect(controller.game.malletFor(_red).x, isNot(closeTo(0.1, 0.01)));
    });

    test('the bot plays its own half without being asked', () {
      final controller = AirHockeyMatchController(mode: GameMode.bot);
      addTearDown(controller.dispose);

      // How far forward it ever got, not where it ends up: it strikes
      // and then drops back to guard, and a snapshot can easily catch
      // it passing its own starting height on the way down.
      final start = controller.game.malletFor(_red).y;
      var furthest = start;
      for (var i = 0; i < 30; i++) {
        controller.advance(1 / 60);
        furthest = max(furthest, controller.game.malletFor(_red).y);
      }

      expect(furthest, greaterThan(start + 0.2),
          reason: 'it came forward on its own');
    });

    test('a local match leaves the far mallet entirely alone', () {
      final controller = AirHockeyMatchController(mode: GameMode.local);
      addTearDown(controller.dispose);

      final start = controller.game.malletFor(_red).y;
      _run(controller, 1.5);

      expect(controller.game.malletFor(_red).y, closeTo(start, 1e-9));
    });

    test('labels the Red winner as the bot', () {
      final controller = AirHockeyMatchController(mode: GameMode.bot);
      addTearDown(controller.dispose);

      expect(controller.redWinnerLabel, 'BOT\nWINS!');
      expect(controller.supportsRevert, isFalse);
    });
  });

  test('a disposed controller stops simulating and stops taking fingers', () {
    final controller = AirHockeyMatchController(mode: GameMode.local);
    controller.dispose();

    expect(controller.canAcceptLocalInput, isFalse);
    expect(controller.advance(1 / 60), isFalse);

    final restingX = controller.game.malletFor(_blue).x;
    controller.steer(_blue, 0.1, 1.9);
    expect(controller.game.malletFor(_blue).targetX, closeTo(restingX, 1e-9));
  });
}
