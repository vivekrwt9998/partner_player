import 'dart:math';

import '../logic/game_tuning.dart';
import '../logic/sling_puck_game.dart';
import '../models/sling_puck_models.dart';

/// How the bot's hand behaves. Separated out so it can be tuned -- or
/// turned into difficulty levels -- without touching the strategy itself.
class BotTuning {
  const BotTuning({
    this.handSpeed = 1.15,
    this.pressSpeed = 0.9,
    this.reactionDelay = 0.45,
    this.regripDelay = 0.30,
    this.aimError = 0.05,
    this.grabRadius = 0.02,
    this.alignTolerance = 0.012,
    this.pressTimeout = 2.0,
    this.holdDuration = 0.12,
  });

  /// How fast the bot's "finger" slides across the field, in W/s. Kept in
  /// the same range a thumb manages so it cannot simply out-drag a human.
  final double handSpeed;

  /// How fast it pushes a piece into its band once lined up, in W/s.
  final double pressSpeed;

  /// Pause before it starts on a new piece, in seconds.
  final double reactionDelay;

  /// Extra pause after a launch, before reaching for the next one.
  final double regripDelay;

  /// Worst-case sideways aiming error, in W. Comfortably wider than the
  /// gap's clearance, so the bot genuinely misses sometimes.
  final double aimError;

  /// How close the hand must get to a piece before it takes hold.
  final double grabRadius;

  /// How closely it lines a piece up on its aim point before pressing.
  final double alignTolerance;

  /// Gives up on a press that somehow never fires, in seconds.
  final double pressTimeout;

  /// How long it steadies at full stretch before letting go, in seconds.
  final double holdDuration;
}

/// What the bot's hand is doing right now.
enum BotPhase {
  /// Waiting out a reaction delay before choosing a piece.
  waiting,

  /// Moving an empty hand toward the piece it picked.
  reaching,

  /// Holding a piece and lining it up in front of its band.
  lining,

  /// Pushing the lined-up piece into the band until it fires.
  pressing,
}

/// A casual Sling Puck opponent.
///
/// Sling Puck is real time and simultaneous, so unlike the platform's
/// turn-based bots this one does not "choose a move". It drives a virtual
/// finger through [SlingPuckGame]'s ordinary [SlingPuckGame.grab],
/// [SlingPuckGame.moveHeld] and [SlingPuckGame.release] -- **exactly** the
/// API a human touch goes through. It has no special powers: it cannot
/// reach across the divider, cannot move faster than a thumb, and its
/// pieces are launched by the same band rule as anyone's.
///
/// Its whole plan is: pick the nearest piece on its own half, walk it to
/// the middle so the launch will line up with the goal gap, then press.
/// Because a band always fires straight along the wall normal, where a
/// piece sits across the field at the moment of launch is the entire aim
/// -- so [BotTuning.aimError] is all that stands between it and a perfect
/// shot every time.
class SimpleSlingPuckBotStrategy {
  SimpleSlingPuckBotStrategy({
    this.player = SlingPuckPlayer.player2,
    this.tuning = const BotTuning(),
    Random? random,
  }) : _random = random ?? Random();

  /// Which side the bot plays. The far/top half by default.
  final SlingPuckPlayer player;

  /// How this bot's hand behaves.
  final BotTuning tuning;
  final Random _random;

  BotPhase _phase = BotPhase.waiting;
  double _timer = 0;
  double _pressElapsed = 0;
  double _holdElapsed = 0;
  int? _targetId;
  double _aimX = 0.5;

  /// Where the bot's finger currently is, in field units. Starts parked
  /// just in front of its own band, mid-field.
  double _handX = 0.5;
  double _handY = 0;
  var _handPlaced = false;

  BotPhase get phase => _phase;

  /// The piece the bot is currently working on, if any.
  int? get targetId => _targetId;

  double get handX => _handX;
  double get handY => _handY;

  /// Forgets everything. Call on restart.
  void reset() {
    _phase = BotPhase.waiting;
    _timer = tuning.reactionDelay;
    _pressElapsed = 0;
    _holdElapsed = 0;
    _targetId = null;
    _handPlaced = false;
  }

  /// Advances the bot by [dt] seconds. Safe to call every frame.
  void update(SlingPuckGame game, double rawDt) {
    if (game.isGameOver || rawDt <= 0) return;

    // Clamped the same way the solver clamps its own frame time, so a
    // stalled frame slides the hand a long way rather than teleporting it
    // somewhere the physics never saw.
    final dt =
        rawDt < GameTuning.maxFrameTime ? rawDt : GameTuning.maxFrameTime;

    if (!_handPlaced) {
      final band = game.bandFor(player);
      _handX = 0.5;
      _handY = band.restY - (band.pressNormalY * game.tuning.pieceRadius * 2);
      _handPlaced = true;
    }

    switch (_phase) {
      case BotPhase.waiting:
        _tickWaiting(game, dt);
      case BotPhase.reaching:
        _tickReaching(game, dt);
      case BotPhase.lining:
        _tickLining(game, dt);
      case BotPhase.pressing:
        _tickPressing(game, dt);
    }
  }

  void _tickWaiting(SlingPuckGame game, double dt) {
    _timer -= dt;
    if (_timer > 0) return;

    final target = _nearestOwnPiece(game);
    if (target == null) {
      // Nothing to work with; look again shortly.
      _timer = tuning.reactionDelay;
      return;
    }

    _targetId = target.id;
    _aimX = _chooseAim(game);
    _phase = BotPhase.reaching;
  }

  void _tickReaching(SlingPuckGame game, double dt) {
    final target = _liveTarget(game);
    if (target == null) return _giveUp();

    _moveHandToward(target.x, target.y, tuning.handSpeed, dt);

    final dx = _handX - target.x;
    final dy = _handY - target.y;
    if ((dx * dx) + (dy * dy) > tuning.grabRadius * tuning.grabRadius) {
      return;
    }

    if (!game.grab(target.id, player)) return _giveUp();
    _phase = BotPhase.lining;
  }

  /// Walks the held piece across to the aim point, staying in front of the
  /// band so it does not fire before it is lined up.
  void _tickLining(SlingPuckGame game, double dt) {
    final piece = game.heldPieceOf(player);
    if (piece == null) return _finishShot(game);

    final band = game.bandFor(player);
    final restFace = band.restY - (band.pressNormalY * game.tuning.pieceRadius);

    _moveHandToward(_aimX, restFace, tuning.handSpeed, dt);
    game.moveHeld(player, _handX, _handY);

    if ((_handX - _aimX).abs() > tuning.alignTolerance) return;
    if ((_handY - restFace).abs() > tuning.alignTolerance) return;

    _pressElapsed = 0;
    _holdElapsed = 0;
    _phase = BotPhase.pressing;
  }

  /// Pushes straight back into the band, steadies at full stretch for a
  /// beat, then lets go -- which is what actually fires the shot.
  void _tickPressing(SlingPuckGame game, double dt) {
    final piece = game.heldPieceOf(player);
    if (piece == null) return _finishShot(game);

    _pressElapsed += dt;
    if (_pressElapsed > tuning.pressTimeout) {
      game.release(player);
      return _finishShot(game);
    }

    final band = game.bandFor(player);
    final n = band.pressNormalY;
    final field = game.tuning;
    final depth = ((piece.y + (n * field.pieceRadius)) - band.restY) * n;

    if (depth >= field.maxStretch - 1e-6) {
      // Fully drawn. A short steadying pause before letting go reads far
      // more like a hand than firing on the same frame it bottoms out.
      _holdElapsed += dt;
      if (_holdElapsed >= tuning.holdDuration) {
        game.release(player);
        _finishShot(game);
      }
      return;
    }

    _handY += n * tuning.pressSpeed * dt;
    game.moveHeld(player, _aimX, _handY);
  }

  void _finishShot(SlingPuckGame game) {
    _targetId = null;
    _pressElapsed = 0;
    _holdElapsed = 0;
    _timer = tuning.regripDelay;
    _phase = BotPhase.waiting;
  }

  void _giveUp() {
    _targetId = null;
    _timer = tuning.reactionDelay;
    _phase = BotPhase.waiting;
  }

  /// The chosen piece, but only while it is still on the bot's own half
  /// and free -- it may have been knocked across or grabbed meanwhile.
  Piece? _liveTarget(SlingPuckGame game) {
    final id = _targetId;
    if (id == null) return null;
    final piece = game.getPiece(id);
    if (piece == null) return null;
    if (piece.isHeld && piece.heldBy != player) return null;
    if (game.sideOf(piece) != player) return null;
    return piece;
  }

  /// The nearest piece on the bot's half that has stopped moving.
  ///
  /// Ignoring pieces still in flight keeps it from chasing something it
  /// could never catch, and reads as the bot waiting for things to settle.
  Piece? _nearestOwnPiece(SlingPuckGame game) {
    Piece? best;
    var bestDistance = double.infinity;

    for (final piece in game.pieces) {
      if (piece.isHeld || piece.isMoving) continue;
      if (game.sideOf(piece) != player) continue;

      final dx = piece.x - _handX;
      final dy = piece.y - _handY;
      final distance = (dx * dx) + (dy * dy);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = piece;
      }
    }
    return best;
  }

  /// Aim for the middle of the goal gap, off by a little.
  ///
  /// A band fires straight along the wall normal, so where the piece sits
  /// across the field at the moment of launch *is* the aim.
  double _chooseAim(SlingPuckGame game) {
    final field = game.tuning;
    final error = (_random.nextDouble() * 2 - 1) * tuning.aimError;
    return (0.5 + error).clamp(
      field.pieceRadius,
      GameTuning.fieldWidth - field.pieceRadius,
    );
  }

  void _moveHandToward(double x, double y, double speed, double dt) {
    final dx = x - _handX;
    final dy = y - _handY;
    final distance = sqrt((dx * dx) + (dy * dy));
    final step = speed * dt;

    if (distance <= step || distance == 0) {
      _handX = x;
      _handY = y;
      return;
    }
    _handX += dx / distance * step;
    _handY += dy / distance * step;
  }
}
