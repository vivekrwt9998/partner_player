import 'dart:math';

import 'package:app/games/air_hockey/bot/simple_air_hockey_bot_strategy.dart';
import 'package:app/games/air_hockey/logic/air_hockey_game.dart';
import 'package:app/games/air_hockey/models/air_hockey_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _blue = AirHockeyPlayer.player1;
const _red = AirHockeyPlayer.player2;

/// Runs the bot's hand and the solver together, the way the controller
/// does, in frame-sized slices.
void _run(
  AirHockeyGame game,
  SimpleAirHockeyBotStrategy bot,
  double seconds, {
  double frame = 1 / 60,
}) {
  var left = seconds;
  while (left > 0) {
    final dt = left < frame ? left : frame;
    bot.update(game, dt);
    game.advance(dt);
    left -= frame;
  }
}

void main() {
  test('it never reaches into the half that is not its own', () {
    final game = AirHockeyGame()..debugConfigure(puckX: 0.5, puckY: 1.7);
    final bot = SimpleAirHockeyBotStrategy()..reset();

    _run(game, bot, 3);

    final (minY, maxY) = game.malletRangeY(_red);
    expect(game.malletFor(_red).y, greaterThanOrEqualTo(minY - 1e-6));
    expect(game.malletFor(_red).y, lessThanOrEqualTo(maxY + 1e-6));
  });

  test('it falls back towards its own goal when the puck is far away', () {
    final game = AirHockeyGame()
      ..debugConfigure(puckX: 0.5, puckY: 1.8, redMalletX: 0.5, redMalletY: 0.9);
    final bot = SimpleAirHockeyBotStrategy()..reset();

    _run(game, bot, 3);

    expect(game.malletFor(_red).y, lessThan(0.6),
        reason: 'it came home rather than loitering at the centre line');
  });

  test('it leaves its own half alone -- the human still steers Blue', () {
    final game = AirHockeyGame()..debugConfigure(puckX: 0.5, puckY: 1.0);
    final bot = SimpleAirHockeyBotStrategy()..reset();

    final blueStart = game.malletFor(_blue).y;
    _run(game, bot, 2);

    expect(game.malletFor(_blue).y, closeTo(blueStart, 1e-9));
  });

  test('it drives a puck in its own half back down the table', () {
    final game = AirHockeyGame()
      ..debugConfigure(
        puckX: 0.5,
        puckY: 0.55,
        redMalletX: 0.5,
        redMalletY: 0.2,
      );
    final bot = SimpleAirHockeyBotStrategy()..reset();

    _run(game, bot, 1.5);

    expect(game.puck.y, greaterThan(0.55),
        reason: 'the puck was pushed away from the goal the bot defends');
    expect(game.blueScore, 0, reason: 'and it did not score on itself');
  });

  test('it defends its goal against a straight shot', () {
    // Blue hits the puck right at the middle of the bot's mouth.
    final game = AirHockeyGame()
      ..debugConfigure(
        puckX: 0.5,
        puckY: 1.2,
        puckVy: -1.6,
        blueMalletX: 0.1,
        blueMalletY: 1.9,
        redMalletX: 0.5,
        redMalletY: 0.3,
      );
    final bot = SimpleAirHockeyBotStrategy()..reset();

    _run(game, bot, 2.5);

    expect(game.blueScore, 0, reason: 'the bot got in the way');
  });

  test('it holds its ground while the table is being set up again', () {
    final game = AirHockeyGame()
      ..debugConfigure(
        puckX: 0.5,
        puckY: 1.8,
        puckVy: 1.6,
        blueMalletX: 0.1,
        blueMalletY: 1.9,
        redMalletX: 0.1,
        redMalletY: 0.1,
      );
    final bot = SimpleAirHockeyBotStrategy()..reset();

    // Let Red score, which starts the hold.
    _run(game, bot, 0.6);
    expect(game.isPaused, isTrue);

    final parked = game.malletFor(_red);
    final x = parked.x;
    final y = parked.y;
    _run(game, bot, 0.4);

    expect(parked.x, closeTo(x, 1e-9));
    expect(parked.y, closeTo(y, 1e-9));
  });

  test('it stops playing once the match is over', () {
    final game = AirHockeyGame()
      ..debugConfigure(
        redScore: 2,
        puckX: 0.5,
        puckY: 1.8,
        puckVy: 1.6,
        blueMalletX: 0.1,
        blueMalletY: 1.9,
        redMalletX: 0.1,
        redMalletY: 0.1,
      );
    final bot = SimpleAirHockeyBotStrategy()..reset();

    _run(game, bot, 0.6);
    expect(game.isGameOver, isTrue);

    final resting = game.malletFor(_red).x;
    _run(game, bot, 1);

    expect(game.malletFor(_red).x, closeTo(resting, 1e-9));
  });

  test('it goes for a puck sitting on the centre line', () {
    // Every face-off puts the puck exactly on the line, which is a
    // whole mallet radius further than the bot can stand. If reaching
    // is judged on the puck alone it waits there forever.
    final game = AirHockeyGame()
      ..debugConfigure(
        puckX: 0.5,
        puckY: AirHockeyGame.tableHeight / 2,
        redMalletX: 0.5,
        redMalletY: 0.3,
      );
    final bot = SimpleAirHockeyBotStrategy()..reset();

    // How far forward it ever got, rather than where it happens to be
    // at the end: once it has played the puck it drops back to guard,
    // and that retreat is correct.
    var furthest = 0.0;
    const frame = 1 / 60;
    for (var i = 0; i < 30; i++) {
      bot.update(game, frame);
      game.advance(frame);
      furthest = max(furthest, game.malletFor(_red).y);
    }

    expect(furthest, greaterThan(0.7),
        reason: 'it came forward to the puck instead of waiting at home');
  });

  test('it works its way round a puck that got behind its striker', () {
    // The puck has slipped between the bot's striker and the goal it
    // is defending. Aiming through the puck from there points at where
    // the striker already is, so it used to stop dead and the point
    // died with the puck sitting on the table.
    final game = AirHockeyGame()
      ..debugConfigure(
        puckX: 0.5,
        puckY: 0.38,
        redMalletX: 0.5,
        redMalletY: 0.62,
        blueMalletX: 0.5,
        blueMalletY: 1.56,
      );
    final bot = SimpleAirHockeyBotStrategy()..reset();

    _run(game, bot, 4);

    expect(game.puck.y, greaterThan(1.0),
        reason: 'it got behind the puck and sent it back down the table');
    expect(game.blueScore, 0,
        reason: 'and it did not shoulder the puck into its own goal');
  });

  test('its hand sweeps rather than flicking about', () {
    // Counts how often the striker reverses direction over four
    // seconds of chasing. One aim, recomputed every frame from a puck
    // position that itself moves smoothly, gives a hand that turns
    // rather than one that doubles back; anything that switches
    // between two targets shows up here immediately as a dozen or more
    // reversals.
    final game = AirHockeyGame()
      ..debugConfigure(puckX: 0.42, puckY: 0.7, puckVx: 0.4, puckVy: 0.3);
    final bot = SimpleAirHockeyBotStrategy()..reset();

    const frame = 1 / 60;
    var reversals = 0;
    double? lastVx;
    double? lastVy;
    for (var i = 0; i < 240; i++) {
      bot.update(game, frame);
      game.advance(frame);
      final mallet = game.malletFor(_red);
      if (mallet.speed <= 0.05) continue;
      if (lastVx != null && (mallet.vx * lastVx) + (mallet.vy * lastVy!) < 0) {
        reversals++;
      }
      lastVx = mallet.vx;
      lastVy = mallet.vy;
    }

    expect(reversals, lessThanOrEqualTo(3));
  });

  test('it scores against an opponent who never touches their striker', () {
    // One goal, unaided, is the bar here rather than a whole match. A
    // puck that comes to rest in the other half is out of the bot's
    // reach by the rules of the game -- its striker cannot cross the
    // centre line -- so against somebody who has genuinely put the
    // phone down, play stops there, exactly as it would on a real
    // table.
    final game = AirHockeyGame()..debugConfigure(puckX: 0.5, puckY: 0.9);
    final bot = SimpleAirHockeyBotStrategy()..reset();

    _run(game, bot, 30);

    expect(game.redScore, greaterThanOrEqualTo(1));
  });
}
