import 'dart:math';

import 'package:app/games/sling_puck/bot/simple_sling_puck_bot_strategy.dart';
import 'package:app/games/sling_puck/logic/game_tuning.dart';
import 'package:app/games/sling_puck/logic/sling_puck_game.dart';
import 'package:app/games/sling_puck/models/sling_puck_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _p1 = SlingPuckPlayer.player1;
const _p2 = SlingPuckPlayer.player2;
const _t = GameTuning();
const _frame = 1 / 60;

SimpleSlingPuckBotStrategy _bot({BotTuning? tuning, int seed = 7}) =>
    SimpleSlingPuckBotStrategy(
      player: _p2,
      tuning: tuning ?? const BotTuning(),
      random: Random(seed),
    )..reset();

/// Runs the bot and the simulation together for [seconds], as the
/// controller does each frame.
void _play(SlingPuckGame game, SimpleSlingPuckBotStrategy bot, double seconds) {
  var elapsed = 0.0;
  while (elapsed < seconds) {
    bot.update(game, _frame);
    game.advance(_frame);
    elapsed += _frame;
  }
}

void main() {
  group('It plays its own half, by the ordinary rules', () {
    test('it launches pieces across within a few seconds', () {
      final game = SlingPuckGame();
      final bot = _bot();

      expect(game.piecesOnSide(_p2), SlingPuckGame.piecesPerPlayer);
      _play(game, bot, 8);

      expect(
        game.piecesOnSide(_p2),
        lessThan(SlingPuckGame.piecesPerPlayer),
        reason: 'it has to actually get pieces off its own half',
      );
    });

    test('it never touches a piece on the human\'s half', () {
      final game = SlingPuckGame();
      final bot = _bot();

      var elapsed = 0.0;
      while (elapsed < 8) {
        bot.update(game, _frame);
        game.advance(_frame);
        elapsed += _frame;

        expect(game.heldPieceOf(_p1), isNull,
            reason: 'the near half is not the bot\'s to hold');
        final held = game.heldPieceOf(_p2);
        if (held != null) {
          expect(game.sideOf(held), _p2);
        }
      }
    });

    test('it only ever holds one piece at a time', () {
      final game = SlingPuckGame();
      final bot = _bot();

      var elapsed = 0.0;
      while (elapsed < 8) {
        bot.update(game, _frame);
        game.advance(_frame);
        elapsed += _frame;
        expect(game.pieces.where((p) => p.isHeld).length, lessThanOrEqualTo(1));
      }
    });

    test('its launches are the same straight, fixed-speed shot as anyone\'s', () {
      final game = SlingPuckGame();
      final bot = _bot();

      var sawLaunch = false;
      var elapsed = 0.0;
      while (elapsed < 8 && !sawLaunch) {
        final before = {
          for (final p in game.pieces) p.id: p.speed,
        };
        bot.update(game, _frame);
        game.advance(_frame);
        elapsed += _frame;

        for (final piece in game.pieces) {
          if (before[piece.id] != 0) continue;
          if ((piece.speed - _t.launchSpeed).abs() > 0.01) continue;
          // Freshly launched this frame: it must be going straight down
          // the field, away from the bot's band.
          expect(piece.vy, greaterThan(0));
          expect(piece.vx.abs(), lessThan(0.01));
          sawLaunch = true;
          break;
        }
      }

      expect(sawLaunch, isTrue, reason: 'the bot should have fired by now');
    });
  });

  group('It behaves like a hand, not an oracle', () {
    test('it waits before its first move rather than snapping to a piece', () {
      final game = SlingPuckGame();
      final bot = _bot();

      bot.update(game, 0.1);
      expect(bot.phase, BotPhase.waiting);
      expect(game.heldPieceOf(_p2), isNull);
    });

    test('a slower hand gets less done in the same time', () {
      int cleared(BotTuning tuning) {
        final game = SlingPuckGame();
        final bot = _bot(tuning: tuning);
        _play(game, bot, 6);
        return SlingPuckGame.piecesPerPlayer - game.piecesOnSide(_p2);
      }

      final quick = cleared(const BotTuning());
      final sluggish = cleared(
        const BotTuning(handSpeed: 0.3, pressSpeed: 0.25, reactionDelay: 1.2),
      );

      expect(sluggish, lessThan(quick));
    });

    test('it misses sometimes -- the aim is not perfect', () {
      // Over many shots with aim error in play, at least one launch must
      // come off centre enough to clip a bar rather than sail through.
      final offsets = <double>{};
      for (var seed = 0; seed < 12; seed++) {
        final game = SlingPuckGame();
        final bot = _bot(seed: seed);
        _play(game, bot, 4);
        for (final piece in game.pieces) {
          if (piece.owner != _p2) continue;
          offsets.add((piece.x - 0.5).abs());
        }
      }

      expect(offsets.any((o) => o > 0.01), isTrue,
          reason: 'shots must not all land on exactly the same line');
    });

    test('the same seed gives the same game', () {
      List<double> run() {
        final game = SlingPuckGame();
        final bot = _bot();
        _play(game, bot, 4);
        return [for (final p in game.pieces) p.x, for (final p in game.pieces) p.y];
      }

      expect(run(), run());
    });
  });

  group('It copes with the board changing under it', () {
    test('it gives up on a target that crossed the divider', () {
      final game = SlingPuckGame();
      final bot = _bot();

      // Let it commit to a piece.
      _play(game, bot, 1.0);
      final target = bot.targetId;
      expect(target, isNotNull);

      // Yank that piece over to the other half mid-plan.
      final piece = game.getPiece(target!)!;
      if (!piece.isHeld) {
        piece.y = 1.5;
        _play(game, bot, 1.0);
        expect(bot.targetId, isNot(target));
      }
    });

    test('it stops once the match is over', () {
      final game = SlingPuckGame();
      final bot = _bot();
      game.debugConfigure(pieces: [
        Piece(id: 0, owner: _p2, x: 0.5, y: 0.5),
        Piece(id: 1, owner: _p1, x: 0.3, y: 1.5),
      ]);

      game.throwPieceById(0, 0, 1.5);
      var elapsed = 0.0;
      while (elapsed < 6) {
        bot.update(game, _frame);
        game.advance(_frame);
        elapsed += _frame;
      }

      expect(game.isGameOver, isTrue);
      expect(game.heldPieceOf(_p2), isNull,
          reason: 'it must not keep fiddling after the whistle');
    });

    test('reset clears whatever it was in the middle of', () {
      final game = SlingPuckGame();
      final bot = _bot();
      _play(game, bot, 2);

      bot.reset();

      expect(bot.phase, BotPhase.waiting);
      expect(bot.targetId, isNull);
    });
  });
}
