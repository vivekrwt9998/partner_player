import 'dart:math';

import 'package:app/games/sling_puck/bot/simple_sling_puck_bot_strategy.dart';
import 'package:app/games/sling_puck/logic/game_tuning.dart';
import 'package:app/games/sling_puck/logic/sling_puck_game.dart';
import 'package:app/games/sling_puck/models/sling_puck_models.dart';
import 'package:app/games/sling_puck/presentation/sling_puck_match_controller.dart';
import 'package:app/models/game_definition.dart';
import 'package:flutter_test/flutter_test.dart';

const _p1 = SlingPuckPlayer.player1;
const _p2 = SlingPuckPlayer.player2;
const _t = GameTuning();

SlingPuckMatchController _controller() =>
    SlingPuckMatchController(mode: GameMode.local);

void _settle(SlingPuckMatchController controller, {double maxSeconds = 12}) {
  var elapsed = 0.0;
  while (elapsed < maxSeconds && !controller.game.isSettled) {
    controller.advance(1 / 60);
    elapsed += 1 / 60;
  }
}

int _firstPieceOn(SlingPuckMatchController controller, SlingPuckPlayer player) =>
    controller.game.pieces
        .firstWhere((p) => controller.game.sideOf(p) == player)
        .id;

void main() {
  group('SlingPuckMatchController - Local', () {
    test('both players can hold and flick at the same time, with no turns', () {
      final controller = _controller();
      addTearDown(controller.dispose);

      final blue = _firstPieceOn(controller, _p1);
      final red = _firstPieceOn(controller, _p2);

      expect(controller.grab(blue, _p1), isTrue);
      expect(controller.grab(red, _p2), isTrue,
          reason: 'nobody has to wait for a turn');

      controller.release(_p1, vy: -2.0);
      controller.release(_p2, vy: 2.0);

      expect(controller.game.getPiece(blue)!.isMoving, isTrue);
      expect(controller.game.getPiece(red)!.isMoving, isTrue);
    });

    test('a piece goes exactly where it is carried and stays when put down', () {
      final controller = _controller();
      addTearDown(controller.dispose);

      final id = _firstPieceOn(controller, _p1);
      controller.grab(id, _p1);
      controller.moveHeld(_p1, 0.35, 1.45);

      expect(controller.game.getPiece(id)!.x, closeTo(0.35, 1e-9));
      expect(controller.game.getPiece(id)!.y, closeTo(1.45, 1e-9));

      controller.release(_p1);
      expect(controller.game.getPiece(id)!.isMoving, isFalse);
      expect(controller.game.getPiece(id)!.x, closeTo(0.35, 1e-9));
    });

    test('a piece on the opponent\'s half cannot be picked up', () {
      final controller = _controller();
      addTearDown(controller.dispose);

      expect(controller.grab(_firstPieceOn(controller, _p2), _p1), isFalse);
    });

    test('advancing drives the simulation and it eventually settles', () {
      final controller = _controller();
      addTearDown(controller.dispose);

      final id = _firstPieceOn(controller, _p1);
      controller.grab(id, _p1);
      controller.release(_p1, vx: 1.5, vy: 0);

      controller.advance(1 / 60);
      expect(controller.game.isSettled, isFalse);

      _settle(controller);
      expect(controller.game.isSettled, isTrue);
    });

    test('restart puts every piece back and lets go of anything held', () {
      final controller = _controller();
      addTearDown(controller.dispose);

      controller.grab(_firstPieceOn(controller, _p1), _p1);
      controller.restart();

      expect(controller.game.piecesOnSide(_p1), SlingPuckGame.piecesPerPlayer);
      expect(controller.game.piecesOnSide(_p2), SlingPuckGame.piecesPerPlayer);
      expect(controller.game.heldPieceOf(_p1), isNull);
      expect(controller.game.isSettled, isTrue);
    });

    test('tuning can be swapped in live', () {
      final controller = _controller();
      addTearDown(controller.dispose);

      controller.applyTuning(_t.copyWith(launchSpeed: 6.0));
      expect(controller.game.tuning.launchSpeed, 6.0);

      final id = _firstPieceOn(controller, _p1);
      controller.grab(id, _p1);
      controller.release(_p1, vy: -99);
      expect(controller.game.getPiece(id)!.speed, closeTo(6.0, 1e-9));
    });

    test('rejects further input once the match is won, and notifies', () {
      final controller = _controller();
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.game.debugConfigure(pieces: [
        Piece(id: 0, owner: _p1, x: 0.5, y: 1.5),
        Piece(id: 1, owner: _p2, x: 0.3, y: 0.5),
      ]);
      controller.game.throwPieceById(0, 0, -1.5);
      _settle(controller);

      expect(controller.game.isGameOver, isTrue);
      expect(controller.game.winner, _p1);
      expect(controller.canAcceptLocalInput, isFalse);
      expect(controller.grab(1, _p2), isFalse);
      expect(notifications, greaterThan(0));
    });
  });

  group('SlingPuckMatchController - Bot', () {
    SlingPuckMatchController botController() => SlingPuckMatchController(
          mode: GameMode.bot,
          botStrategy: SimpleSlingPuckBotStrategy(
            player: SlingPuckMatchController.botPlayer,
            random: Random(3),
          ),
        );

    test('the human gets the near half and the bot the far one', () {
      final controller = botController();
      addTearDown(controller.dispose);

      expect(controller.isBotMatch, isTrue);
      expect(controller.canControl(SlingPuckMatchController.humanPlayer), isTrue);
      expect(controller.canControl(SlingPuckMatchController.botPlayer), isFalse);
    });

    test('a touch on the bot\'s half is ignored', () {
      final controller = botController();
      addTearDown(controller.dispose);

      final farPiece = _firstPieceOn(controller, _p2);
      expect(controller.grab(farPiece, _p2), isFalse);

      // ...while the human's own half still works normally.
      expect(controller.grab(_firstPieceOn(controller, _p1), _p1), isTrue);
    });

    test('advancing drives the bot without any extra plumbing', () {
      final controller = botController();
      addTearDown(controller.dispose);

      var elapsed = 0.0;
      while (elapsed < 8) {
        controller.advance(1 / 60);
        elapsed += 1 / 60;
      }

      expect(
        controller.game.piecesOnSide(_p2),
        lessThan(SlingPuckGame.piecesPerPlayer),
        reason: 'the bot should have slung something across by now',
      );
    });

    test('restart puts the bot back to the start too', () {
      final controller = botController();
      addTearDown(controller.dispose);

      var elapsed = 0.0;
      while (elapsed < 2) {
        controller.advance(1 / 60);
        elapsed += 1 / 60;
      }

      controller.restart();

      expect(controller.botStrategy!.phase, BotPhase.waiting);
      expect(controller.botStrategy!.targetId, isNull);
      expect(controller.game.piecesOnSide(_p2), SlingPuckGame.piecesPerPlayer);
    });

    test('a local match has no bot at all', () {
      final controller = _controller();
      addTearDown(controller.dispose);

      expect(controller.isBotMatch, isFalse);
      expect(controller.botStrategy, isNull);
      expect(controller.canControl(_p2), isTrue);
    });
  });
}
