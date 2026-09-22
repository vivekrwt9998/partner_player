import 'dart:math';

import 'package:meta/meta.dart';

import '../models/sling_puck_models.dart';
import 'game_tuning.dart';

/// Pure Dart engine for Sling Puck.
///
/// ## Units and time
///
/// Everything is in field widths (`W`): the field is `1.0` wide and `2.0`
/// tall, and speeds are `W/s`. The renderer scales the whole thing by the
/// width it is given, so behaviour is identical on every screen.
///
/// The solver runs on a **fixed 1/240 s step** driven from an accumulator,
/// and moves pieces with **swept** circle-vs-capsule collision, so a piece
/// at full launch speed cannot tunnel through a bar at 30, 60 or 120 fps.
///
/// ## How a piece moves
///
/// A launch does not "push" a piece and then let drag eat it. It gets a
/// speed and a short window of `boostLeft` during which there is no drag at
/// all; once that runs out, anything above [GameTuning.cruiseSpeed] eases
/// down to cruise quickly, and cruise itself bleeds away gently. That is
/// what makes a hard shot read as *fast* rather than merely *long*.
///
/// ## How a band works
///
/// A band is **not** a wall and **not** a spring that pushes back. It is a
/// catapult a player loads by hand: press a piece into it, the band deforms
/// to follow and can be held drawn for as long as you like, and **letting
/// go** fires it straight along the wall normal at exactly
/// [GameTuning.launchSpeed] -- never along the slanted V, and never scaled
/// by how hard it was drawn. The band then springs back on its own as pure
/// animation, with the piece long gone.
class SlingPuckGame {
  SlingPuckGame({this.tuning = const GameTuning()}) {
    topBand = Band(isTop: true, restY: tuning.topBandY);
    bottomBand = Band(isTop: false, restY: tuning.bottomBandY);
    reset();
  }

  static const int piecesPerPlayer = 4;
  static const int totalPieces = piecesPerPlayer * 2;

  /// Live tuning values. Only the debug overlay replaces these; the band
  /// rest lines are fixed at construction so they stay consistent with the
  /// bands already on the board.
  GameTuning tuning;

  final List<Piece> _pieces = <Piece>[];

  late final Band topBand;
  late final Band bottomBand;

  double _accumulator = 0;
  bool _winCheckEnabled = true;

  late SlingPuckGameStatus _status;
  SlingPuckPlayer? _winner;
  late bool _gateClosed;

  final Map<SlingPuckPlayer, int> _held = {};

  List<Piece> get pieces => List.unmodifiable(_pieces);

  SlingPuckGameStatus get status => _status;

  SlingPuckPlayer? get winner => _winner;

  bool get isGameOver => _status != SlingPuckGameStatus.playing;

  /// Whether the goal gap has slammed shut -- the moment someone clears
  /// their half, so their win cannot be undone by a piece coming back.
  bool get isGateClosed => _gateClosed;

  bool get isSettled => _held.isEmpty && !_pieces.any((p) => p.isMoving);

  // -- Geometry ---------------------------------------------------------

  /// Which half a piece counts as being on, for picking it up.
  ///
  /// Centre-based, so a piece straddling the gap always belongs to exactly
  /// one player rather than to neither. Whether a half is *clear* is a
  /// different, stricter question -- see [piecesOnSide].
  SlingPuckPlayer sideOf(Piece piece) => piece.y > tuning.barCentreY
      ? SlingPuckPlayer.player1
      : SlingPuckPlayer.player2;

  /// How many pieces still have **any part** of them on [player]'s half.
  ///
  /// Overlap rather than centre, deliberately: a piece stopped in the goal
  /// gap with half of it still hanging back over the line has not left,
  /// and a half is only clear once every piece is *entirely* off it. Using
  /// the centre here would hand someone the match while a piece was still
  /// sitting in the gateway.
  ///
  /// A plain loop rather than `.where().length`: this runs twice per
  /// sub-step, and the iterable and closure that comprehension allocates
  /// would be hundreds of short-lived objects a second.
  int piecesOnSide(SlingPuckPlayer player) {
    final radius = tuning.pieceRadius;
    final divider = tuning.barCentreY;
    var count = 0;

    for (var i = 0; i < _pieces.length; i++) {
      final piece = _pieces[i];
      final overlaps = player == SlingPuckPlayer.player1
          ? piece.y + radius > divider
          : piece.y - radius < divider;
      if (overlaps) count++;
    }
    return count;
  }

  Piece? getPiece(int id) {
    for (final piece in _pieces) {
      if (piece.id == id) return piece;
    }
    return null;
  }

  Piece? heldPieceOf(SlingPuckPlayer player) {
    final id = _held[player];
    return id == null ? null : getPiece(id);
  }

  Band bandFor(SlingPuckPlayer player) =>
      player == SlingPuckPlayer.player1 ? bottomBand : topBand;

  // -- The one way a piece is ever launched ------------------------------

  /// Sets [piece] moving at ([vx], [vy]), capped at [GameTuning.launchSpeed],
  /// and gives it a boost window in proportion to how fast it left.
  ///
  /// Both a player's flick and a band release come through here, so the two
  /// can never drift apart.
  void throwPiece(Piece piece, double vx, double vy) {
    final speed = sqrt((vx * vx) + (vy * vy));
    if (speed <= 0) {
      piece.vx = 0;
      piece.vy = 0;
      piece.boostLeft = 0;
      return;
    }

    final capped = speed > tuning.launchSpeed ? tuning.launchSpeed : speed;
    final scale = capped / speed;
    piece.vx = vx * scale;
    piece.vy = vy * scale;
    piece.boostLeft = tuning.boostDuration * capped / tuning.launchSpeed;
  }

  /// [throwPiece] by id, for callers that only hold an id.
  void throwPieceById(int id, double vx, double vy) {
    final piece = getPiece(id);
    if (piece != null) throwPiece(piece, vx, vy);
  }

  // -- Picking up, carrying, letting go ----------------------------------

  /// Takes hold of [pieceId] for [player], if it is on their half and free.
  bool grab(int pieceId, SlingPuckPlayer player) {
    if (isGameOver || _held.containsKey(player)) return false;

    final piece = getPiece(pieceId);
    if (piece == null || piece.isHeld || sideOf(piece) != player) return false;

    piece.vx = 0;
    piece.vy = 0;
    piece.boostLeft = 0;
    piece.heldBy = player;
    _held[player] = pieceId;
    return true;
  }

  /// Carries [player]'s held piece to ([x], [y]).
  ///
  /// It goes exactly where it is put, clamped by the field, the centre wall
  /// and how far their own band will stretch. Pressing into the band is
  /// the whole point of carrying, so the back limit is the band drawn fully
  /// to [GameTuning.maxStretch] -- never past it.
  void moveHeld(SlingPuckPlayer player, double x, double y) {
    final piece = heldPieceOf(player);
    if (piece == null) return;

    final r = tuning.pieceRadius;
    final band = bandFor(player);
    final n = band.pressNormalY;

    // Furthest back: the band drawn to its limit, measured at the piece's
    // leading edge, so the elastic always stays behind the piece.
    final backLimit = band.restY + (n * (tuning.maxStretch - r));
    // Furthest forward: just short of the divider, on their own side.
    final frontLimit =
        tuning.barCentreY + (n * (r + tuning.barHalfThickness + 0.002));

    piece.x = x.clamp(r, GameTuning.fieldWidth - r).toDouble();
    piece.y = player == SlingPuckPlayer.player1
        ? y.clamp(frontLimit, backLimit).toDouble()
        : y.clamp(backLimit, frontLimit).toDouble();
  }

  /// Lets go of [player]'s piece.
  ///
  /// **Letting go is what fires a shot.** If the band is drawn back past
  /// [GameTuning.minLaunchStretch] the piece is catapulted straight along
  /// the wall normal at exactly [GameTuning.launchSpeed], and the flick is
  /// ignored -- the band decides, not the gesture. Otherwise the piece is
  /// simply thrown with whatever speed the gesture had, or put down.
  ///
  /// Firing on release rather than the moment the band hits its limit is
  /// what lets a player draw it fully back and *hold* there, picking their
  /// moment, instead of the shot going off under their finger.
  void release(SlingPuckPlayer player, {double vx = 0, double vy = 0}) {
    final id = _held.remove(player);
    if (id == null) return;
    final piece = getPiece(id);
    if (piece == null) return;

    piece.heldBy = null;

    final band = bandFor(player);
    final n = band.pressNormalY;
    final depth = ((piece.y + (n * tuning.pieceRadius)) - band.restY) * n;

    if (depth >= tuning.minLaunchStretch) {
      band.phase = BandPhase.releasing;
      band.depth = depth;
      band.apexX = piece.x;
      band.springVelocity = 0;
      throwPiece(piece, 0, -n * tuning.launchSpeed);
      return;
    }

    // Barely touching the elastic: nudge it clear and let the flick carry.
    if (depth > 0) piece.y = band.restY - (n * tuning.pieceRadius);
    throwPiece(piece, vx, vy);
  }

  // -- Simulation --------------------------------------------------------

  /// Feeds [dt] real seconds into the fixed-step solver.
  void advance(double dt) {
    if (dt <= 0) return;

    _accumulator += dt < GameTuning.maxFrameTime ? dt : GameTuning.maxFrameTime;
    while (_accumulator >= GameTuning.fixedDt) {
      _step(GameTuning.fixedDt);
      _accumulator -= GameTuning.fixedDt;
    }
  }

  /// Runs exactly one fixed sub-step. Exposed for tests that want to drive
  /// the solver without the accumulator in the way.
  void stepOnce() => _step(GameTuning.fixedDt);

  void _step(double h) {
    _applyDrag(h);
    _moveAndCollideWorld(h);
    _resolvePieceCollisions();
    _updateBand(topBand, h);
    _updateBand(bottomBand, h);
    _updateStatus();
  }

  /// Boost first, then the ease down to cruise, then the gentle decay.
  void _applyDrag(double h) {
    final cruise = tuning.cruiseSpeed;

    for (var i = 0; i < _pieces.length; i++) {
      final piece = _pieces[i];
      if (piece.isHeld) continue;

      if (piece.boostLeft > 0) {
        // A boosting piece holds its speed exactly -- no drag at all.
        piece.boostLeft -= h;
        continue;
      }

      final speed = piece.speed;
      if (speed <= 0) continue;

      final double target;
      if (speed > cruise) {
        target = cruise + ((speed - cruise) * exp(-tuning.boostEaseRate * h));
      } else {
        target = speed * exp(-tuning.slowRate * h);
      }

      if (target < tuning.restSpeed) {
        piece.vx = 0;
        piece.vy = 0;
        continue;
      }

      final scale = target / speed;
      piece.vx *= scale;
      piece.vy *= scale;
    }
  }

  // Scratch values for the swept tests, so the loop allocates nothing.
  double _hitTime = 0;
  double _hitNx = 0;
  double _hitNy = 0;
  double _hitRestitution = 0;

  /// Moves every loose piece, resolving world collisions continuously.
  void _moveAndCollideWorld(double h) {
    for (var i = 0; i < _pieces.length; i++) {
      final piece = _pieces[i];
      if (piece.isHeld || !piece.isMoving) continue;

      var remaining = h;
      // Four impacts in one sub-step is already a corner case; beyond that
      // just consume the rest of the step.
      for (var pass = 0; pass < 4 && remaining > 1e-9; pass++) {
        if (!_earliestWorldHit(piece, remaining)) break;

        final t = _hitTime;
        piece.x += piece.vx * t;
        piece.y += piece.vy * t;
        remaining -= t;

        final normalSpeed = (piece.vx * _hitNx) + (piece.vy * _hitNy);
        if (normalSpeed < 0) {
          final j = (1 + _hitRestitution) * normalSpeed;
          piece.vx -= j * _hitNx;
          piece.vy -= j * _hitNy;
        }
        // Lift off the surface so the next pass does not re-detect it.
        piece.x += _hitNx * 1e-6;
        piece.y += _hitNy * 1e-6;
      }

      piece.x += piece.vx * remaining;
      piece.y += piece.vy * remaining;
    }

    _depenetrate();
  }

  /// Finds the earliest world impact within [limit] seconds, writing it into
  /// [_hitTime]/[_hitNx]/[_hitNy]. Returns whether anything was hit.
  bool _earliestWorldHit(Piece piece, double limit) {
    final r = tuning.pieceRadius;
    var best = double.infinity;
    var bnx = 0.0;
    var bny = 0.0;
    var bounce = tuning.restitutionWall;

    // Side and end walls.
    if (piece.vx < 0) {
      final t = (r - piece.x) / piece.vx;
      if (t >= 0 && t < best && t <= limit) {
        best = t;
        bnx = 1;
        bny = 0;
      }
    } else if (piece.vx > 0) {
      final t = (GameTuning.fieldWidth - r - piece.x) / piece.vx;
      if (t >= 0 && t < best && t <= limit) {
        best = t;
        bnx = -1;
        bny = 0;
      }
    }
    if (piece.vy < 0) {
      final t = (r - piece.y) / piece.vy;
      if (t >= 0 && t < best && t <= limit) {
        best = t;
        bnx = 0;
        bny = 1;
      }
    } else if (piece.vy > 0) {
      final t = (GameTuning.fieldHeight - r - piece.y) / piece.vy;
      if (t >= 0 && t < best && t <= limit) {
        best = t;
        bnx = 0;
        bny = -1;
      }
    }

    // Divider bars.
    final rc = r + tuning.barHalfThickness;
    if (_sweepBar(piece, 0, tuning.gapLeft, rc, limit) && _hitTime < best) {
      best = _hitTime;
      bnx = _hitNx;
      bny = _hitNy;
    }
    if (_sweepBar(piece, tuning.gapRight, GameTuning.fieldWidth, rc, limit) &&
        _hitTime < best) {
      best = _hitTime;
      bnx = _hitNx;
      bny = _hitNy;
    }
    if (_gateClosed &&
        _sweepBar(
          piece,
          tuning.gapLeft,
          tuning.gapRight,
          r + tuning.gateHalfThickness,
          limit,
        ) &&
        _hitTime < best) {
      best = _hitTime;
      bnx = _hitNx;
      bny = _hitNy;
    }

    // The bands. A loose piece is turned back by the elastic instead of
    // getting behind it; only a piece a player is deliberately pressing
    // loads a band, and held pieces never reach this code.
    if (piece.vy < 0) {
      final t = ((topBand.restY + r) - piece.y) / piece.vy;
      if (t >= 0 && t < best && t <= limit) {
        best = t;
        bnx = 0;
        bny = 1;
        bounce = tuning.restitutionBand;
      }
    } else if (piece.vy > 0) {
      final t = ((bottomBand.restY - r) - piece.y) / piece.vy;
      if (t >= 0 && t < best && t <= limit) {
        best = t;
        bnx = 0;
        bny = -1;
        bounce = tuning.restitutionBand;
      }
    }

    if (best == double.infinity) return false;
    _hitTime = best;
    _hitNx = bnx;
    _hitNy = bny;
    _hitRestitution = bounce;
    return true;
  }

  /// Swept test against one horizontal bar, treated as a capsule of radius
  /// [rc] running from [ax] to [bx] along the divider line.
  ///
  /// Tests the flat faces and both rounded ends, so a piece that just
  /// scrapes the edge of the goal gap glances off the end cap instead of
  /// sliding through it.
  bool _sweepBar(Piece piece, double ax, double bx, double rc, double limit) {
    final cy = tuning.barCentreY;
    var best = double.infinity;
    var bnx = 0.0;
    var bny = 0.0;

    // Flat faces, only where the bar actually spans.
    if (piece.vy > 0) {
      final t = (cy - rc - piece.y) / piece.vy;
      if (t >= 0 && t <= limit) {
        final hx = piece.x + (piece.vx * t);
        if (hx >= ax && hx <= bx && t < best) {
          best = t;
          bnx = 0;
          bny = -1;
        }
      }
    } else if (piece.vy < 0) {
      final t = (cy + rc - piece.y) / piece.vy;
      if (t >= 0 && t <= limit) {
        final hx = piece.x + (piece.vx * t);
        if (hx >= ax && hx <= bx && t < best) {
          best = t;
          bnx = 0;
          bny = 1;
        }
      }
    }

    // Rounded ends.
    if (_sweepPointCircle(piece, ax, cy, rc, limit) && _hitTime < best) {
      best = _hitTime;
      bnx = _hitNx;
      bny = _hitNy;
    }
    if (_sweepPointCircle(piece, bx, cy, rc, limit) && _hitTime < best) {
      best = _hitTime;
      bnx = _hitNx;
      bny = _hitNy;
    }

    if (best == double.infinity) return false;
    _hitTime = best;
    _hitNx = bnx;
    _hitNy = bny;
    return true;
  }

  /// Swept moving-point against a static circle of radius [rc].
  bool _sweepPointCircle(
    Piece piece,
    double cx,
    double cy,
    double rc,
    double limit,
  ) {
    final dx = piece.x - cx;
    final dy = piece.y - cy;
    final a = (piece.vx * piece.vx) + (piece.vy * piece.vy);
    if (a <= 0) return false;

    final b = 2 * ((dx * piece.vx) + (dy * piece.vy));
    final c = (dx * dx) + (dy * dy) - (rc * rc);
    if (c <= 0) return false; // already overlapping; depenetration handles it

    final disc = (b * b) - (4 * a * c);
    if (disc < 0) return false;

    final t = (-b - sqrt(disc)) / (2 * a);
    if (t < 0 || t > limit) return false;

    final hx = dx + (piece.vx * t);
    final hy = dy + (piece.vy * t);
    final len = sqrt((hx * hx) + (hy * hy));
    if (len <= 0) return false;

    _hitTime = t;
    _hitNx = hx / len;
    _hitNy = hy / len;
    return true;
  }

  /// Last-resort push-out, for numerical drift and for the gate appearing
  /// underneath a piece when it slams shut.
  void _depenetrate() {
    final r = tuning.pieceRadius;
    final rc = r + tuning.barHalfThickness;
    final cy = tuning.barCentreY;

    for (var i = 0; i < _pieces.length; i++) {
      final piece = _pieces[i];
      if (piece.isHeld) continue;

      piece.x = piece.x.clamp(r, GameTuning.fieldWidth - r).toDouble();
      piece.y = piece.y.clamp(r, GameTuning.fieldHeight - r).toDouble();

      final inGap = piece.x > tuning.gapLeft && piece.x < tuning.gapRight;
      if (inGap && !_gateClosed) continue;

      // The gate is slimmer than the bars it sits between.
      final clearance = inGap ? r + tuning.gateHalfThickness : rc;
      if ((piece.y - cy).abs() >= clearance) continue;
      final push = piece.y >= cy ? 1.0 : -1.0;
      piece.y = cy + (push * clearance);
    }
  }

  /// Equal-mass circle collisions. A held piece is immovable and shoves
  /// loose ones aside instead of being pushed itself.
  void _resolvePieceCollisions() {
    final minDistance = tuning.pieceRadius * 2;

    for (var i = 0; i < _pieces.length; i++) {
      for (var j = i + 1; j < _pieces.length; j++) {
        final a = _pieces[i];
        final b = _pieces[j];
        if (a.isHeld && b.isHeld) continue;

        final dx = b.x - a.x;
        final dy = b.y - a.y;
        var distance = sqrt((dx * dx) + (dy * dy));
        if (distance >= minDistance) continue;

        double nx;
        double ny;
        if (distance < 1e-9) {
          nx = 1;
          ny = 0;
          distance = 1e-9;
        } else {
          nx = dx / distance;
          ny = dy / distance;
        }
        final overlap = minDistance - distance;

        if (a.isHeld || b.isHeld) {
          final heldIsA = a.isHeld;
          final loose = heldIsA ? b : a;
          final pushX = heldIsA ? nx : -nx;
          final pushY = heldIsA ? ny : -ny;
          final shove = overlap * 14;

          loose.x += pushX * overlap;
          loose.y += pushY * overlap;
          loose.vx += pushX * shove;
          loose.vy += pushY * shove;
          _reboost(loose);
          continue;
        }

        final half = overlap / 2;
        a.x -= nx * half;
        a.y -= ny * half;
        b.x += nx * half;
        b.y += ny * half;

        final approach = ((b.vx - a.vx) * nx) + ((b.vy - a.vy) * ny);
        if (approach >= 0) continue;

        final impulse = -(1 + tuning.restitutionPiece) * approach / 2;
        a.vx -= impulse * nx;
        a.vy -= impulse * ny;
        b.vx += impulse * nx;
        b.vy += impulse * ny;

        _reboost(a);
        _reboost(b);
      }
    }
  }

  /// A piece knocked hard enough carries its own short boost, so a struck
  /// piece travels like a shot rather than immediately bogging down.
  void _reboost(Piece piece) {
    final speed = piece.speed;
    if (speed <= tuning.reboostSpeed) return;

    final capped = speed > tuning.launchSpeed ? tuning.launchSpeed : speed;
    final boost = tuning.boostDuration * capped / tuning.launchSpeed;
    if (boost > piece.boostLeft) piece.boostLeft = boost;
  }

  // -- Bands -------------------------------------------------------------

  /// Runs one band's IDLE -> STRETCHING -> RELEASING cycle for this step.
  ///
  /// **Only a piece a player is deliberately pressing into the band can
  /// load it.** A loose piece that happens to arrive at a band simply
  /// bounces off the elastic (see the band planes in [_earliestWorldHit]).
  /// Without that rule a launch is self-sustaining: a full-power shot
  /// out-ranges the gap between the two bands, so every piece that crossed
  /// would be caught and fired straight back, forever.
  void _updateBand(Band band, double h) {
    final n = band.pressNormalY;
    final r = tuning.pieceRadius;
    final maxStretch = tuning.maxStretch;

    var deepest = -1.0;
    var deepestX = band.apexX;

    for (final player in SlingPuckPlayer.values) {
      // A player can only ever reach the band at their own end.
      if (bandFor(player) != band) continue;
      final piece = heldPieceOf(player);
      if (piece == null) continue;

      // Leading edge: the part of the piece that meets the band first.
      // [moveHeld] already caps this at the limit, so a fully drawn band
      // can be held here indefinitely -- letting go is what fires it.
      final depth = ((piece.y + (n * r)) - band.restY) * n;
      if (depth <= 0) continue;

      if (depth > deepest) {
        deepest = depth > maxStretch ? maxStretch : depth;
        deepestX = piece.x;
      }
    }

    if (deepest >= 0) {
      // Still being pressed: the V follows the piece across the band.
      band.phase = BandPhase.stretching;
      band.depth = deepest;
      band.apexX = deepestX;
      band.springVelocity = 0;
    } else if (band.phase == BandPhase.stretching) {
      // Nothing pressing any more. [release] has already set the spring up
      // when it fired a shot; this catches the piece simply being let go
      // or knocked away, which springs the band back with no launch.
      band.phase = BandPhase.releasing;
      band.springVelocity = 0;
    }

    if (band.phase == BandPhase.releasing) _integrateBandSpring(band, h);
  }

  /// `d'' = -omega^2 d - 2 zeta omega d'`, semi-implicit so it stays stable.
  void _integrateBandSpring(Band band, double h) {
    final omega = tuning.bandOmega;
    final zeta = tuning.bandZeta;

    final acceleration =
        (-omega * omega * band.depth) - (2 * zeta * omega * band.springVelocity);
    band.springVelocity += acceleration * h;
    band.depth += band.springVelocity * h;

    final settle = tuning.bandSettleDepth;
    if (band.depth.abs() <= settle && band.springVelocity.abs() <= settle * omega) {
      band.depth = 0;
      band.springVelocity = 0;
      band.phase = BandPhase.idle;
    }
  }

  // -- Status ------------------------------------------------------------

  /// Ends the match the instant a half falls empty, and slams the gate.
  void _updateStatus() {
    if (isGameOver || !_winCheckEnabled) return;

    for (final player in SlingPuckPlayer.values) {
      if (piecesOnSide(player) == 0) {
        _status = SlingPuckGameStatus.won;
        _winner = player;
        _gateClosed = true;
        _held.clear();
        return;
      }
    }
  }

  // -- Setup -------------------------------------------------------------

  /// Resets the field: every piece back to its starting spot, at rest, both
  /// bands flat and the gate open.
  void reset() {
    _held.clear();
    _accumulator = 0;
    _pieces
      ..clear()
      ..addAll([
        for (var i = 0; i < piecesPerPlayer; i++)
          Piece(
            id: i,
            owner: SlingPuckPlayer.player1,
            x: _startX(i),
            y: GameTuning.fieldHeight - _startInset(i),
          ),
        for (var i = 0; i < piecesPerPlayer; i++)
          Piece(
            id: piecesPerPlayer + i,
            owner: SlingPuckPlayer.player2,
            x: _startX(i),
            y: _startInset(i),
          ),
      ]);

    topBand.reset();
    bottomBand.reset();
    _status = SlingPuckGameStatus.playing;
    _winner = null;
    _gateClosed = false;
  }

  /// Puts an exact board on the table for a physics test.
  ///
  /// Lets a scenario isolate one piece instead of working around the other
  /// nine, and optionally suspends the win check -- otherwise a board with
  /// nothing on one half would instantly declare that half cleared and slam
  /// the gate mid-experiment. Piece ids must stay below [totalPieces].
  @visibleForTesting
  void debugConfigure({required List<Piece> pieces, bool winCheck = true}) {
    assert(pieces.every((p) => p.id >= 0 && p.id < totalPieces));

    _held.clear();
    _accumulator = 0;
    _winCheckEnabled = winCheck;
    _pieces
      ..clear()
      ..addAll(pieces);

    topBand.reset();
    bottomBand.reset();
    _status = SlingPuckGameStatus.playing;
    _winner = null;
    _gateClosed = false;
  }

  /// Two staggered rows of two, like the real toy's loose starting pile.
  static double _startX(int indexInPlayer) {
    const front = [0.30, 0.70];
    const back = [0.40, 0.60];
    return indexInPlayer < 2 ? front[indexInPlayer] : back[indexInPlayer - 2];
  }

  /// Both rows sit between the band and the divider, so a piece always has
  /// to travel to a band to be catapulted.
  static double _startInset(int indexInPlayer) =>
      indexInPlayer < 2 ? 0.46 : 0.66;
}
