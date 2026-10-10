import 'dart:math';

import 'package:app/games/sling_puck/logic/game_tuning.dart';
import 'package:app/games/sling_puck/logic/sling_puck_game.dart';
import 'package:app/games/sling_puck/models/sling_puck_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Acceptance tests for the throw model and the band state machine.
///
/// Everything is in field widths (W) and W/s. Note the one deliberate
/// departure from the measured spec: a band is loaded **only** by a piece
/// a player is deliberately pressing into it. A loose piece that arrives
/// at a band bounces off instead, which is what stops a launch from being
/// self-sustaining between the two ends.

const _t = GameTuning();
const _dt = GameTuning.fixedDt;
const _p2 = SlingPuckPlayer.player2;

/// A board holding just the pieces a scenario cares about, with the win
/// check off so an empty half does not end the match mid-experiment.
SlingPuckGame _board(List<Piece> pieces) {
  final game = SlingPuckGame();
  game.debugConfigure(pieces: pieces, winCheck: false);
  return game;
}

/// A piece sitting against the front face of the top band, ready to press.
Piece _atTopBand({double x = 0.5}) => Piece(
      id: 0,
      owner: _p2,
      x: x,
      y: _t.topBandY + _t.pieceRadius,
    );

/// How far [player]'s band is currently drawn, measured at the apex.
double _depthOf(SlingPuckGame game, SlingPuckPlayer player) {
  final band = game.bandFor(player);
  final piece = game.heldPieceOf(player);
  if (piece == null) return 0;
  return ((piece.y + (band.pressNormalY * game.tuning.pieceRadius)) -
          band.restY) *
      band.pressNormalY;
}

/// Walks a held piece into its band at [pressSpeed], optionally sliding
/// sideways at [slideSpeed], one sub-step at a time -- a simulated finger
/// -- until the band is fully drawn, then lets go.
///
/// Letting go is what fires the shot, so [andRelease] can be turned off to
/// test holding at full stretch. Returns the simulated seconds it took to
/// draw the band, or NaN if it never got there.
double _pressIntoBand(
  SlingPuckGame game,
  SlingPuckPlayer player,
  int id, {
  required double pressSpeed,
  double slideSpeed = 0,
  double maxSeconds = 5,
  bool andRelease = true,
}) {
  final piece = game.getPiece(id)!;
  final n = game.bandFor(player).pressNormalY;
  var x = piece.x;
  var y = piece.y;
  var elapsed = 0.0;
  var drawn = false;

  while (elapsed < maxSeconds) {
    if (_depthOf(game, player) >= _t.maxStretch - 1e-6) {
      drawn = true;
      break;
    }
    x += slideSpeed * _dt;
    y += n * pressSpeed * _dt;
    game.moveHeld(player, x, y);
    game.stepOnce();
    elapsed += _dt;
  }

  if (andRelease) game.release(player);
  return drawn ? elapsed : double.nan;
}

double _runUntil(
  SlingPuckGame game,
  bool Function() done, {
  double maxSeconds = 5,
}) {
  var elapsed = 0.0;
  while (elapsed < maxSeconds) {
    game.stepOnce();
    elapsed += _dt;
    if (done()) return elapsed;
  }
  return double.nan;
}

/// Shortest distance from a piece's centre to a divider bar's surface.
double _clearanceToBar(Piece piece, double ax, double bx) {
  final dx = piece.x - piece.x.clamp(ax, bx);
  final dy = piece.y - _t.barCentreY;
  return sqrt((dx * dx) + (dy * dy)) - _t.barHalfThickness;
}

double _clearanceToBars(Piece piece) => min(
      _clearanceToBar(piece, 0, _t.gapLeft),
      _clearanceToBar(piece, _t.gapRight, GameTuning.fieldWidth),
    );

void main() {
  group('A - a slow, square press still earns a full launch', () {
    test('depth grows linearly and releases at about 1.6 s', () {
      final game = _board([_atTopBand()]);
      final piece = game.getPiece(0)!;
      expect(game.grab(0, _p2), isTrue);

      // Sample the depth on the way in: it must climb at the press speed.
      final samples = <double>[];
      var x = piece.x;
      var y = piece.y;
      var elapsed = 0.0;
      while (elapsed < 0.8) {
        y -= 0.1 * _dt;
        game.moveHeld(_p2, x, y);
        game.stepOnce();
        elapsed += _dt;
        if ((elapsed * 1000).round() % 200 == 0) samples.add(game.topBand.depth);
      }
      for (var i = 1; i < samples.length; i++) {
        expect(samples[i] - samples[i - 1], closeTo(0.1 * 0.2, 0.004),
            reason: 'depth grows at the press speed, i.e. linearly');
      }

      while (elapsed < 2.0 && _depthOf(game, _p2) < _t.maxStretch - 1e-6) {
        y -= 0.1 * _dt;
        game.moveHeld(_p2, x, y);
        game.stepOnce();
        elapsed += _dt;
      }

      expect(elapsed, closeTo(1.6, 0.16),
          reason: 'the band reaches its limit at the press speed');

      game.release(_p2);
      expect(piece.vy, closeTo(_t.launchSpeed, 1e-9));
      expect(piece.vx, 0);
      expect(piece.boostLeft, closeTo(_t.boostDuration, 1e-9));
    });

    test('a fully drawn band can be held as long as you like', () {
      final game = _board([_atTopBand()]);
      final piece = game.getPiece(0)!;
      game.grab(0, _p2);

      _pressIntoBand(game, _p2, 0, pressSpeed: 1.0, andRelease: false);
      expect(_depthOf(game, _p2), closeTo(_t.maxStretch, 1e-6));

      // Two more seconds of holding: it must not go off by itself.
      for (var i = 0; i < (2 / _dt).round(); i++) {
        game.stepOnce();
        expect(piece.isHeld, isTrue,
            reason: 'the shot fires when the player lets go, not before');
        expect(piece.isMoving, isFalse);
      }
      expect(game.topBand.phase, BandPhase.stretching);

      // And only then does letting go fire it.
      game.release(_p2);
      expect(piece.vy, closeTo(_t.launchSpeed, 1e-9));
    });
  });

  group('B - the launch never depends on how it was pressed', () {
    test('a hard, angled shove still fires exactly straight', () {
      final game = _board([_atTopBand(x: 0.3)]);
      final piece = game.getPiece(0)!;
      game.grab(0, _p2);

      final launchAt = _pressIntoBand(game, _p2, 0,
          pressSpeed: 4.0, slideSpeed: 2.0);

      expect(launchAt, isNot(isNaN));
      expect(piece.vy, closeTo(_t.launchSpeed, 1e-9));
      expect(piece.vx, 0, reason: 'the sideways component is discarded');
      expect(piece.x, greaterThan(0.3), reason: 'it really did slide sideways');
    });

    test('slow and fast presses leave at the very same speed', () {
      double launchSpeedFor(double pressSpeed) {
        final game = _board([_atTopBand()]);
        game.grab(0, _p2);
        _pressIntoBand(game, _p2, 0, pressSpeed: pressSpeed);
        return game.getPiece(0)!.vy;
      }

      expect(launchSpeedFor(0.2), closeTo(_t.launchSpeed, 1e-9));
      expect(launchSpeedFor(4.0), closeTo(_t.launchSpeed, 1e-9));
    });

    test('a piece can never be pressed past the band', () {
      final game = _board([_atTopBand()]);
      final piece = game.getPiece(0)!;
      game.grab(0, _p2);

      // Shove far past the limit in a single move.
      game.moveHeld(_p2, 0.5, -5);

      final depth = ((piece.y - _t.pieceRadius) - _t.topBandY) * -1;
      expect(depth, lessThanOrEqualTo(_t.maxStretch + 1e-9));
    });
  });

  group('C - a glancing press still fires, and still fires straight', () {
    test('sliding along the band with a weak press releases vertically', () {
      final game = _board([_atTopBand(x: 0.2)]);
      final piece = game.getPiece(0)!;
      game.grab(0, _p2);

      final launchAt = _pressIntoBand(game, _p2, 0,
          pressSpeed: 0.06, slideSpeed: _t.cruiseSpeed, maxSeconds: 3);

      expect(launchAt, isNot(isNaN), reason: 'a weak press must still fire');
      expect(launchAt, closeTo(_t.maxStretch / 0.06, 0.15));
      expect(piece.vy, closeTo(_t.launchSpeed, 1e-9));
      expect(piece.vx, 0);
    });

    test('the apex follows the piece across the band while it slides', () {
      final game = _board([_atTopBand(x: 0.2)]);
      final piece = game.getPiece(0)!;
      game.grab(0, _p2);

      var x = piece.x;
      var y = piece.y;
      for (var i = 0; i < 120; i++) {
        x += _t.cruiseSpeed * _dt;
        y -= 0.06 * _dt;
        game.moveHeld(_p2, x, y);
        game.stepOnce();
      }

      expect(game.topBand.phase, BandPhase.stretching);
      expect(game.topBand.apexX, closeTo(piece.x, 1e-9));
      expect(game.topBand.apexX, greaterThan(0.2));
    });
  });

  group('D - the band springs back on its own', () {
    test('crosses flat, overshoots into the field, then settles', () {
      final game = _board([_atTopBand()]);
      game.grab(0, _p2);
      _pressIntoBand(game, _p2, 0, pressSpeed: 1.0);

      expect(game.topBand.phase, BandPhase.releasing);
      expect(game.topBand.depth, closeTo(_t.maxStretch, 0.002));

      final crossedAt = _runUntil(game, () => game.topBand.depth <= 0);
      expect(crossedAt, closeTo(0.12, 0.04));

      var overshoot = 0.0;
      var elapsed = crossedAt;
      while (elapsed < 0.6) {
        game.stepOnce();
        elapsed += _dt;
        overshoot = min(overshoot, game.topBand.depth);
      }
      // The overshoot fraction of D_MAX is set by bandZeta's damping ratio,
      // not by D_MAX itself -- at zeta=0.35 that fraction works out to
      // ~31%, so it scales automatically if D_MAX changes again.
      expect(-overshoot, closeTo(0.049, 0.01),
          reason: 'about 31% of D_MAX, past flat toward the field');
      // Settling time (envelope decaying below bandSettleFraction) scales
      // with 1/(zeta*omega); at zeta=0.35 that's ~0.48 s from release, so
      // the window needs more room than the old zeta=0.45 needed.
      expect(game.topBand.phase, BandPhase.idle,
          reason: 'settled inside 0.6 s after release');
    });

    test('letting go of a barely-touched band is not a shot', () {
      final game = _board([_atTopBand()]);
      final piece = game.getPiece(0)!;
      game.grab(0, _p2);

      // Pressed in, but nowhere near far enough to count.
      game.moveHeld(
        _p2,
        0.5,
        _t.topBandY + _t.pieceRadius - (_t.minLaunchStretch / 2),
      );
      game.stepOnce();
      expect(game.topBand.phase, BandPhase.stretching);
      expect(game.topBand.depth, greaterThan(0));

      game.release(_p2);
      _runUntil(game, () => game.topBand.phase != BandPhase.stretching);

      expect(piece.isMoving, isFalse, reason: 'put down, not catapulted');
      expect(game.topBand.phase, isNot(BandPhase.stretching));
    });
  });

  group('E - frame rate cannot change the outcome', () {
    test('launch time agrees within a frame at 30, 60 and 120 Hz', () {
      double launchTimeAt(double frameDt) {
        final game = _board([_atTopBand()]);
        final piece = game.getPiece(0)!;
        game.grab(0, _p2);
        var y = piece.y;
        var elapsed = 0.0;
        while (elapsed < 3) {
          if (_depthOf(game, _p2) >= _t.maxStretch - 1e-6) {
            game.release(_p2);
            return elapsed;
          }
          y -= 0.5 * frameDt;
          game.moveHeld(_p2, piece.x, y);
          game.advance(frameDt);
          elapsed += frameDt;
        }
        return double.nan;
      }

      final at30 = launchTimeAt(1 / 30);
      final at60 = launchTimeAt(1 / 60);
      final at120 = launchTimeAt(1 / 120);

      expect(at30, isNot(isNaN));
      expect((at30 - at60).abs(), lessThanOrEqualTo(1 / 30));
      expect((at60 - at120).abs(), lessThanOrEqualTo(1 / 30));
    });

    test('a full-speed piece cannot tunnel through a bar at 30 Hz', () {
      final game = _board([Piece(id: 0, owner: _p2, x: 0.15, y: 0.5)]);
      final piece = game.getPiece(0)!;
      game.throwPiece(piece, 0, _t.launchSpeed);

      for (var i = 0; i < 90; i++) {
        game.advance(1 / 30);
        expect(piece.y, lessThan(_t.barCentreY),
            reason: 'it must never reach the far side of a solid bar');
      }
    });
  });

  group('F - the gap is genuinely wide enough', () {
    test('a centred launch from the bottom band clears both bars', () {
      final game = _board([
        Piece(id: 0, owner: SlingPuckPlayer.player1, x: 0.5, y: 1.5),
      ]);
      final piece = game.getPiece(0)!;
      game.grab(0, SlingPuckPlayer.player1);
      _pressIntoBand(game, SlingPuckPlayer.player1, 0, pressSpeed: 1.0);

      expect(piece.vy, closeTo(-_t.launchSpeed, 1e-9));

      var minClearance = double.infinity;
      var elapsed = 0.0;
      while (elapsed < 1.0 && piece.y > 0.4) {
        game.stepOnce();
        elapsed += _dt;
        minClearance = min(minClearance, _clearanceToBars(piece));
      }

      expect(piece.y, lessThan(_t.barCentreY), reason: 'it got through');
      expect(minClearance, greaterThan(_t.pieceRadius),
          reason: 'and never so much as brushed a bar on the way');
    });

    test('a launch off to the side is deflected by the rounded bar end', () {
      final game = _board([
        Piece(
          id: 0,
          owner: SlingPuckPlayer.player1,
          x: _t.gapLeft - (_t.pieceRadius * 0.5),
          y: 1.4,
        ),
      ]);
      final piece = game.getPiece(0)!;
      game.throwPiece(piece, 0, -_t.launchSpeed);

      for (var i = 0; i < 240; i++) {
        game.stepOnce();
      }

      expect(piece.y, greaterThan(_t.barCentreY),
          reason: 'the bar end turned it back');
    });
  });

  group('Only a deliberate press loads a band', () {
    test('a loose piece driven into a band bounces instead of launching', () {
      final game = _board([Piece(id: 0, owner: _p2, x: 0.5, y: 0.8)]);
      final piece = game.getPiece(0)!;
      game.throwPiece(piece, 0, -_t.launchSpeed);

      _runUntil(game, () => piece.vy > 0);

      expect(piece.vy, greaterThan(0), reason: 'it did come back');
      expect(piece.vy, lessThan(_t.launchSpeed * 0.9),
          reason: 'bounced off slack elastic, not catapulted at full power');
      expect(game.topBand.phase, BandPhase.idle,
          reason: 'the band was never loaded at all');
    });

    test('a loose piece can never get behind a band', () {
      final game = _board([Piece(id: 0, owner: _p2, x: 0.5, y: 0.8)]);
      final piece = game.getPiece(0)!;
      game.throwPiece(piece, 0, -_t.launchSpeed);

      for (var i = 0; i < 240 * 3; i++) {
        game.stepOnce();
        expect(piece.y - _t.pieceRadius, greaterThan(_t.topBandY - 1e-6));
      }
    });

    test('a launched piece is not caught and fired back by the far band', () {
      // The whole reason only deliberate presses count: a full launch
      // out-ranges the gap between the bands, so auto-loading would make
      // a single piece bounce between them forever.
      final game = _board([
        Piece(id: 0, owner: SlingPuckPlayer.player1, x: 0.5, y: 1.5),
      ]);
      game.grab(0, SlingPuckPlayer.player1);
      _pressIntoBand(game, SlingPuckPlayer.player1, 0, pressSpeed: 1.0);

      var elapsed = 0.0;
      while (elapsed < 10 && !game.isSettled) {
        game.stepOnce();
        elapsed += _dt;
      }

      expect(game.isSettled, isTrue,
          reason: 'it has to come to rest rather than ping-pong forever');
      expect(game.topBand.phase, BandPhase.idle);
    });
  });

  group('throwPiece is the single launch path', () {
    test('caps at the launch speed and scales the boost with it', () {
      final game = _board([_atTopBand()]);
      final piece = game.getPiece(0)!;

      game.throwPiece(piece, 0, -100);
      expect(piece.speed, closeTo(_t.launchSpeed, 1e-9));
      expect(piece.boostLeft, closeTo(_t.boostDuration, 1e-9));

      game.throwPiece(piece, 0, -_t.launchSpeed / 2);
      expect(piece.speed, closeTo(_t.launchSpeed / 2, 1e-9));
      expect(piece.boostLeft, closeTo(_t.boostDuration / 2, 1e-9));
    });

    test('a boosting piece holds its speed, then eases to cruise', () {
      final game = _board([Piece(id: 0, owner: _p2, x: 0.5, y: 0.25)]);
      final piece = game.getPiece(0)!;
      game.throwPiece(piece, 0, _t.launchSpeed);

      for (var i = 0; i < (0.2 / _dt).round(); i++) {
        game.stepOnce();
      }
      expect(piece.speed, closeTo(_t.launchSpeed, 0.01),
          reason: 'no drag at all while the boost lasts');

      for (var i = 0; i < (0.25 / _dt).round(); i++) {
        game.stepOnce();
      }
      expect(piece.speed, closeTo(_t.cruiseSpeed, 0.12),
          reason: 'and it eases down to cruise once the boost ends');
    });
  });
}
