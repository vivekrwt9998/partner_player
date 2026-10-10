import 'dart:math';

import 'package:app/games/sling_puck/logic/game_tuning.dart';
import 'package:app/games/sling_puck/logic/sling_puck_game.dart';
import 'package:app/games/sling_puck/models/sling_puck_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rules-level tests: who may pick up what, where a piece may be carried,
/// and how the match ends. The throw model and the band state machine have
/// their own acceptance tests in `sling_puck_physics_test.dart`.

const _p1 = SlingPuckPlayer.player1;
const _p2 = SlingPuckPlayer.player2;
const _t = GameTuning();

void _settle(SlingPuckGame game, {double maxSeconds = 12}) {
  var elapsed = 0.0;
  while (elapsed < maxSeconds && !game.isSettled) {
    game.stepOnce();
    elapsed += GameTuning.fixedDt;
  }
}

int _firstPieceOn(SlingPuckGame game, SlingPuckPlayer player) =>
    game.pieces.firstWhere((p) => game.sideOf(p) == player).id;

/// How far past [player]'s band a piece is sitting, in field units.
double _pastBand(SlingPuckGame game, Piece piece, SlingPuckPlayer player) {
  final band = game.bandFor(player);
  final restFace = band.restY - (band.pressNormalY * _t.pieceRadius);
  return (piece.y - restFace) * band.pressNormalY;
}

void main() {
  group('Setup', () {
    test('four pieces a side, at rest, in front of their own band', () {
      final game = SlingPuckGame();

      expect(game.pieces.length, SlingPuckGame.totalPieces);
      expect(game.piecesOnSide(_p1), SlingPuckGame.piecesPerPlayer);
      expect(game.piecesOnSide(_p2), SlingPuckGame.piecesPerPlayer);
      expect(game.status, SlingPuckGameStatus.playing);
      expect(game.isGateClosed, isFalse);
      expect(game.isSettled, isTrue);

      for (final piece in game.pieces) {
        expect(_pastBand(game, piece, game.sideOf(piece)), lessThan(0));
      }
    });

    test('the field really is 1 by 2, and everything starts inside it', () {
      final game = SlingPuckGame();

      expect(GameTuning.fieldHeight / GameTuning.fieldWidth, 2.0);
      for (final piece in game.pieces) {
        expect(piece.x, inInclusiveRange(_t.pieceRadius, 1 - _t.pieceRadius));
        expect(piece.y, inInclusiveRange(_t.pieceRadius, 2 - _t.pieceRadius));
      }
    });

    test('the gap is wide enough to pass a piece with room to spare', () {
      // Widened from the measured 0.046 W: the original gap was a tight
      // squeeze to shoot through.
      final clearance = ((_t.gapWidth / 2) - _t.pieceRadius);
      expect(clearance, closeTo(0.066, 0.005));
    });

    test('no two pieces start on top of each other', () {
      final game = SlingPuckGame();
      final pieces = game.pieces;

      for (var i = 0; i < pieces.length; i++) {
        for (var j = i + 1; j < pieces.length; j++) {
          final dx = pieces[i].x - pieces[j].x;
          final dy = pieces[i].y - pieces[j].y;
          expect(sqrt((dx * dx) + (dy * dy)),
              greaterThanOrEqualTo(_t.pieceRadius * 2));
        }
      }
    });
  });

  group('Picking a piece up and carrying it', () {
    test('a piece goes exactly where it is carried', () {
      final game = SlingPuckGame();
      final id = _firstPieceOn(game, _p1);

      expect(game.grab(id, _p1), isTrue);
      game.moveHeld(_p1, 0.3, 1.4);

      expect(game.getPiece(id)!.x, closeTo(0.3, 1e-9));
      expect(game.getPiece(id)!.y, closeTo(1.4, 1e-9));
    });

    test('both players can hold a piece at the same time', () {
      final game = SlingPuckGame();

      expect(game.grab(_firstPieceOn(game, _p1), _p1), isTrue);
      expect(game.grab(_firstPieceOn(game, _p2), _p2), isTrue);
      expect(game.heldPieceOf(_p1), isNotNull);
      expect(game.heldPieceOf(_p2), isNotNull);
    });

    test('a player can only hold one piece at a time', () {
      final game = SlingPuckGame();
      final own = game.pieces.where((p) => game.sideOf(p) == _p1).toList();

      expect(game.grab(own[0].id, _p1), isTrue);
      expect(game.grab(own[1].id, _p1), isFalse);
    });

    test('a piece on the opponent\'s half cannot be picked up', () {
      final game = SlingPuckGame();
      expect(game.grab(_firstPieceOn(game, _p2), _p1), isFalse);
    });

    test('carrying presses into the band but never past its limit', () {
      final game = SlingPuckGame();
      final id = _firstPieceOn(game, _p1);
      game.grab(id, _p1);

      // Shoved as hard as a finger can toward the band and the side wall.
      game.moveHeld(_p1, 9, 9);
      final piece = game.getPiece(id)!;

      expect(_pastBand(game, piece, _p1), greaterThan(0),
          reason: 'pressing into the band is the whole point of carrying');
      // Measured at the centre, a fully drawn band puts the piece exactly
      // D_MAX past the point where its leading edge first touched.
      expect(
        _pastBand(game, piece, _p1),
        lessThanOrEqualTo(_t.maxStretch + 1e-9),
        reason: 'the elastic will not stretch past D_MAX',
      );
      expect(piece.x, lessThanOrEqualTo(1 - _t.pieceRadius + 1e-9));

      game.moveHeld(_p1, -9, -9);
      expect(game.sideOf(game.getPiece(id)!), _p1,
          reason: 'it cannot be carried onto the other half');
    });

    test('whatever lands on your half becomes yours to handle', () {
      final game = SlingPuckGame();
      game.debugConfigure(pieces: [
        Piece(id: 0, owner: _p1, x: 0.5, y: 1.5),
        Piece(id: 1, owner: _p1, x: 0.2, y: 1.5),
        Piece(id: 2, owner: _p2, x: 0.8, y: 0.5),
      ]);

      game.throwPieceById(0, 0, -1.5);
      _settle(game);

      final crossed = game.getPiece(0)!;
      expect(game.sideOf(crossed), _p2);
      expect(game.grab(0, _p1), isFalse);
      expect(game.grab(0, _p2), isTrue, reason: 'colour is irrelevant');
    });
  });

  group('Letting go', () {
    test('a flick throws the piece, capped at the launch speed', () {
      final game = SlingPuckGame();
      final id = _firstPieceOn(game, _p1);
      game.grab(id, _p1);

      game.release(_p1, vx: 0, vy: -99);

      final piece = game.getPiece(id)!;
      expect(piece.isHeld, isFalse);
      expect(piece.speed, closeTo(_t.launchSpeed, 1e-9));
      expect(piece.boostLeft, closeTo(_t.boostDuration, 1e-9));
    });

    test('letting go without a flick simply puts it down', () {
      final game = SlingPuckGame();
      final id = _firstPieceOn(game, _p1);
      game.grab(id, _p1);
      game.moveHeld(_p1, 0.4, 1.5);

      game.release(_p1);

      final piece = game.getPiece(id)!;
      expect(piece.isMoving, isFalse);
      expect(piece.x, closeTo(0.4, 1e-9));
      expect(piece.y, closeTo(1.5, 1e-9));
    });
  });

  group('Collisions', () {
    test('pieces bounce off each other instead of passing through', () {
      final game = SlingPuckGame();
      game.debugConfigure(
        pieces: [
          Piece(id: 0, owner: _p1, x: 0.5, y: 1.6),
          Piece(id: 1, owner: _p1, x: 0.5, y: 1.2),
        ],
        winCheck: false,
      );
      final target = game.getPiece(1)!;

      game.throwPieceById(0, 0, -3.0);
      _settle(game);

      expect(target.y, lessThan(1.2), reason: 'it was struck and shoved away');

      final a = game.getPiece(0)!;
      final dx = a.x - target.x;
      final dy = a.y - target.y;
      expect(sqrt((dx * dx) + (dy * dy)),
          greaterThan(_t.pieceRadius * 2 * 0.95));
    });

    test('a hit passes on less than it carried, and a chain less again', () {
      // Three in a line: the shot hits the first, which hits the second.
      // Each handover has to bleed energy, or one good shot sends a whole
      // cluster flying at full speed.
      final game = SlingPuckGame();
      game.debugConfigure(
        pieces: [
          Piece(id: 0, owner: _p1, x: 0.5, y: 1.70),
          Piece(id: 1, owner: _p1, x: 0.5, y: 1.50),
          Piece(id: 2, owner: _p1, x: 0.5, y: 1.30),
        ],
        winCheck: false,
      );

      game.throwPieceById(0, 0, -_t.launchSpeed);

      var firstStruck = 0.0;
      var secondStruck = 0.0;
      for (var i = 0; i < 240; i++) {
        game.stepOnce();
        firstStruck = max(firstStruck, game.getPiece(1)!.speed);
        secondStruck = max(secondStruck, game.getPiece(2)!.speed);
      }

      expect(firstStruck, greaterThan(0), reason: 'it was definitely hit');
      expect(
        firstStruck,
        lessThan(_t.launchSpeed * 0.85),
        reason: 'a hit hands on noticeably less than the shot carried',
      );
      expect(
        secondStruck,
        lessThan(firstStruck),
        reason: 'and the next one down the chain gets less again',
      );
    });

    test('a struck piece picks up a boost of its own', () {
      // reboostFactor lowered just for this scenario: at the app's current
      // tuning, V_CRUISE * reboostFactor lands exactly at V_LAUNCH, and a
      // struck piece's post-collision speed can never exceed the striker's
      // (itself capped at V_LAUNCH), so no ordinary hit can clear that bar.
      // This test exercises the _reboost mechanism itself, independent of
      // where the live default happens to sit.
      final game = SlingPuckGame(tuning: _t.copyWith(reboostFactor: 1.1));
      game.debugConfigure(
        pieces: [
          Piece(id: 0, owner: _p1, x: 0.5, y: 1.6),
          Piece(id: 1, owner: _p1, x: 0.5, y: 1.3),
        ],
        winCheck: false,
      );

      game.throwPieceById(0, 0, -game.tuning.launchSpeed);
      for (var i = 0; i < 40; i++) {
        game.stepOnce();
      }

      expect(game.getPiece(1)!.boostLeft, greaterThan(0));
    });

    test('a carried piece shoves loose ones aside rather than being pushed', () {
      final game = SlingPuckGame();
      final own = game.pieces.where((p) => game.sideOf(p) == _p1).toList();
      final carried = own[0];
      final neighbour = own[1];
      // Pieces are mutable, so snapshot before anything moves.
      final targetX = neighbour.x;
      final targetY = neighbour.y;

      game.grab(carried.id, _p1);
      game.moveHeld(_p1, targetX, targetY);
      game.stepOnce();

      expect(game.getPiece(carried.id)!.x, closeTo(targetX, 1e-9),
          reason: 'the hand does not get pushed');
      expect(game.getPiece(carried.id)!.y, closeTo(targetY, 1e-9));
      final shoved = game.getPiece(neighbour.id)!;
      expect((shoved.x - targetX).abs() + (shoved.y - targetY).abs(),
          greaterThan(0));
    });
  });

  group('Winning slams the gate', () {
    test('clearing your own half wins and shuts the gate', () {
      final game = SlingPuckGame();
      game.debugConfigure(pieces: [
        Piece(id: 0, owner: _p1, x: 0.5, y: 1.5),
        Piece(id: 1, owner: _p2, x: 0.3, y: 0.5),
        Piece(id: 2, owner: _p2, x: 0.7, y: 0.5),
      ]);

      game.throwPieceById(0, 0, -1.5);
      _settle(game);

      expect(game.piecesOnSide(_p1), 0);
      expect(game.isGameOver, isTrue);
      expect(game.winner, _p1);
      expect(game.isGateClosed, isTrue);
    });

    test('a piece straddling the gap still counts as on your half', () {
      final game = SlingPuckGame();
      // Centre just past the divider, so a centre-based test would call this
      // half clear -- but part of the puck is still hanging over the line.
      game.debugConfigure(pieces: [
        Piece(id: 0, owner: _p1, x: 0.5, y: _t.barCentreY - (_t.pieceRadius / 2)),
        Piece(id: 1, owner: _p2, x: 0.3, y: 0.5),
      ]);
      game.stepOnce();

      expect(game.sideOf(game.pieces.first), _p2,
          reason: 'its centre is across, so player 2 may pick it up');
      expect(game.piecesOnSide(_p1), 1,
          reason: 'but part of it is still on player 1\'s half');
      expect(game.isGameOver, isFalse);
      expect(game.isGateClosed, isFalse);
    });

    test('the half is clear only once the puck is entirely across', () {
      final game = SlingPuckGame();
      game.debugConfigure(pieces: [
        Piece(
            id: 0,
            owner: _p1,
            x: 0.5,
            y: _t.barCentreY - _t.pieceRadius - 0.001),
        Piece(id: 1, owner: _p2, x: 0.3, y: 0.5),
      ]);
      game.stepOnce();

      expect(game.piecesOnSide(_p1), 0);
      expect(game.isGameOver, isTrue);
      expect(game.winner, _p1);
      expect(game.isGateClosed, isTrue);
    });

    test('the win lands while the piece is still sliding', () {
      final game = SlingPuckGame();
      game.debugConfigure(pieces: [
        Piece(id: 0, owner: _p1, x: 0.5, y: 1.5),
        Piece(id: 1, owner: _p2, x: 0.3, y: 0.5),
      ]);

      game.throwPieceById(0, 0, -1.5);
      var elapsed = 0.0;
      while (elapsed < 3 && !game.isGameOver) {
        game.stepOnce();
        elapsed += GameTuning.fixedDt;
      }

      expect(game.isGameOver, isTrue);
      expect(game.isSettled, isFalse,
          reason: 'decided the moment it crossed, not once things stopped');
    });

    test('a shut gate turns a piece back', () {
      final game = SlingPuckGame();
      game.debugConfigure(pieces: [
        Piece(id: 0, owner: _p1, x: 0.5, y: 1.5),
        Piece(id: 1, owner: _p2, x: 0.3, y: 0.5),
      ]);

      game.throwPieceById(0, 0, -1.5);
      _settle(game);
      expect(game.isGateClosed, isTrue);

      // Everything is on the top half now. Fire one straight at the gap.
      final piece = game.getPiece(1)!;
      piece.x = 0.5;
      piece.y = 0.6;
      game.throwPiece(piece, 0, _t.launchSpeed);
      _settle(game);

      expect(piece.y, lessThan(_t.barCentreY),
          reason: 'the gate held: it never reached the far half');
      expect(game.piecesOnSide(_p1), 0);
    });

    test('a finished game ignores further input', () {
      final game = SlingPuckGame();
      game.debugConfigure(pieces: [
        Piece(id: 0, owner: _p1, x: 0.5, y: 1.5),
        Piece(id: 1, owner: _p2, x: 0.3, y: 0.5),
      ]);

      game.throwPieceById(0, 0, -1.5);
      _settle(game);
      expect(game.isGameOver, isTrue);

      expect(game.grab(1, _p2), isFalse);
    });
  });

  group('Reset', () {
    test('restores the board, reopens the gate and drops anything held', () {
      final game = SlingPuckGame();
      game.grab(_firstPieceOn(game, _p1), _p1);

      game.reset();

      expect(game.piecesOnSide(_p1), SlingPuckGame.piecesPerPlayer);
      expect(game.piecesOnSide(_p2), SlingPuckGame.piecesPerPlayer);
      expect(game.heldPieceOf(_p1), isNull);
      expect(game.isGateClosed, isFalse);
      expect(game.isSettled, isTrue);
      expect(game.topBand.phase, BandPhase.idle);
      expect(game.bottomBand.phase, BandPhase.idle);
    });
  });
}
