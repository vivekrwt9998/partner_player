import 'dart:math';

import '../logic/air_hockey_game.dart';
import '../models/air_hockey_models.dart';

/// How the bot's hand behaves. Separated out so it can be tuned -- or
/// turned into difficulty levels -- without touching the strategy.
class AirHockeyBotTuning {
  const AirHockeyBotTuning({
    this.reactionSeconds = 0.12,
    this.restingY = 0.3,
    this.trackingShare = 0.55,
    this.followThrough = 0.4,
    this.swingWide = 0.26,
    this.swingBack = 1.2,
  });

  /// How far behind the truth the bot's picture of the puck runs.
  ///
  /// This is the whole of its handicap, and it is deliberately a lag
  /// rather than a pause between decisions. Deciding in steps makes the
  /// hand flick, because the aim stands still and then jumps; chasing a
  /// position that is merely out of date keeps the aim moving every
  /// frame, so the hand sweeps -- and it still cannot read the puck
  /// perfectly, which is what stops it being a wall nothing gets past.
  final double reactionSeconds;

  /// Where it waits when the puck is nowhere near, in table units from
  /// its own goal line. Far enough out to meet an attack, near enough to
  /// get back.
  final double restingY;

  /// How much of the puck's sideways position it mirrors while waiting.
  /// Below 1 it hangs towards the middle rather than being dragged to a
  /// post and leaving the rest of the mouth open.
  final double trackingShare;

  /// How far past the puck it aims when attacking, in table widths.
  ///
  /// A mallet slows as it arrives at its target, so aiming at the puck
  /// itself means arriving with nothing left and nudging it a few
  /// inches. Aiming through it is what a person does, and it is the
  /// difference between a tap and a shot.
  final double followThrough;

  /// How wide it goes round a puck it has ended up in front of, in
  /// table widths. Has to clear both radii or it shoulders the puck
  /// towards its own goal on the way past.
  final double swingWide;

  /// How far behind the puck that detour sits, as a share of the two
  /// radii.
  final double swingBack;
}

/// Plays the far half of an Air Hockey table.
///
/// The bot is not given moves -- it is given a hand. Every frame it
/// decides where it wants its mallet and calls the very same
/// [AirHockeyGame.steerMallet] a finger does, so it is bound by the same
/// speed limit, the same half of the table and the same physics. That
/// also means it can be beaten by being outpaced, which is the whole
/// game.
///
/// It only ever does two things, and which one depends on where the puck
/// is (AGENTS.md §27):
///
/// - **Attack.** With the puck in its own half it goes to the point
///   directly behind the puck on the line to the opponent's goal, so
///   that closing on it drives the puck down the table rather than
///   anywhere else.
/// - **Guard.** Otherwise it falls back and sits between the puck and
///   the middle of its own goal, partly mirroring the puck across the
///   table.
class SimpleAirHockeyBotStrategy {
  SimpleAirHockeyBotStrategy({
    this.player = AirHockeyPlayer.player2,
    this.tuning = const AirHockeyBotTuning(),
  });

  /// The half the bot plays. Red by default, which is the far side.
  final AirHockeyPlayer player;

  final AirHockeyBotTuning tuning;

  /// Where the bot believes the puck is: the real position, chased with
  /// a lag. Never jumps, so neither does the aim taken from it.
  double _seenX = AirHockeyGame.tableWidth / 2;
  double _seenY = AirHockeyGame.tableHeight / 2;
  var _hasLooked = false;

  /// Whether the hand is working its way round a puck it got in front
  /// of, and which side it committed to going round.
  var _goingRound = false;
  var _roundSide = 1.0;


  /// Where the hand is being sent.
  double _wantX = AirHockeyGame.tableWidth / 2;
  double _wantY = 0;

  void reset() {
    _hasLooked = false;
    _goingRound = false;
    _seenX = AirHockeyGame.tableWidth / 2;
    _seenY = AirHockeyGame.tableHeight / 2;
    _wantX = AirHockeyGame.tableWidth / 2;
    _wantY = _ownGoalY + (_attackSign * tuning.restingY);
  }

  /// Runs the bot's hand for [dt] seconds.
  void update(AirHockeyGame game, double dt) {
    if (game.isGameOver) return;

    // While the table is held after a goal there is nothing to chase,
    // and steering now would only drag the mallet off the spot it was
    // just put back on.
    if (game.isPaused) {
      _hasLooked = false;
      _goingRound = false;
      return;
    }

    _look(game, dt);
    _chooseAim(game);
    game.steerMallet(player, _wantX, _wantY);
  }

  /// Updates the bot's picture of the puck.
  void _look(AirHockeyGame game, double dt) {
    final puck = game.puck;

    // First frame of a point: see it where it actually is, rather than
    // spending the lag catching up to a puck that has not moved.
    if (!_hasLooked) {
      _hasLooked = true;
      _seenX = puck.x;
      _seenY = puck.y;
      return;
    }

    final catchUp = 1 - exp(-dt / tuning.reactionSeconds);
    _seenX += (puck.x - _seenX) * catchUp;
    _seenY += (puck.y - _seenY) * catchUp;
  }

  /// Which way this player attacks: +1 down the table, -1 up it.
  double get _attackSign => player == AirHockeyPlayer.player1 ? -1 : 1;

  /// The goal this player defends.
  double get _ownGoalY =>
      player == AirHockeyPlayer.player1 ? AirHockeyGame.tableHeight : 0;

  /// The goal this player is shooting at.
  double get _targetGoalY =>
      player == AirHockeyPlayer.player1 ? 0 : AirHockeyGame.tableHeight;

  void _chooseAim(AirHockeyGame game) {
    final (minY, maxY) = game.malletRangeY(player);

    // A puck is in reach if the mallet could touch it from as far over
    // as it is allowed to go -- so the margin is both radii, not just
    // the puck's. Getting that wrong leaves the bot standing still at
    // every face-off, because the puck is put back exactly on the centre
    // line and the mallet stops one radius short of it.
    final touching = AirHockeyGame.malletRadius + AirHockeyGame.puckRadius;
    final inReach = _attackSign > 0
        ? _seenY < maxY + touching
        : _seenY > minY - touching;

    if (inReach) {
      _aimAtStrikePoint(game, _openSideOfGoal(game));
    } else {
      _goingRound = false;
      _aimAtGuardPost();
    }

    _wantX = _wantX.clamp(
      AirHockeyGame.malletRadius,
      AirHockeyGame.tableWidth - AirHockeyGame.malletRadius,
    );
    _wantY = _wantY.clamp(minY, maxY);
  }

  /// Which part of the mouth to shoot at: the side the other striker is
  /// not standing in front of.
  ///
  /// Without this the bot shoots down the middle every time, and anyone
  /// who simply parks their striker on the centre spot can never be
  /// scored against -- including somebody who has put the phone down.
  double _openSideOfGoal(AirHockeyGame game) {
    final centre = AirHockeyGame.tableWidth / 2;
    final keeper = game.malletFor(player.opponent);
    final offset = AirHockeyGame.goalHalfWidth * 0.55;
    return keeper.x > centre ? centre - offset : centre + offset;
  }

  /// Stand on the far side of the puck from where it is being sent, so
  /// that moving onto it drives the puck that way.
  /// Aim at a point past the puck, on the line to where the shot is
  /// meant to go.
  ///
  /// One target, every frame, rather than lining up and then swinging.
  /// Two phases need a rule for switching between them, and any such
  /// rule makes the hand judder: the moment it arrives behind the puck
  /// the aim leaps forward, which puts it out of position again, and it
  /// spends the point snapping between the two.
  ///
  /// Aiming through the puck gets the same thing for nothing. A mallet
  /// slows as it arrives at its target, so a target *on* the puck is a
  /// tap; a target beyond it means the hand is still travelling when it
  /// makes contact, and it keeps driving the puck on afterwards rather
  /// than stopping dead on top of it.
  void _aimAtStrikePoint(AirHockeyGame game, double targetX) {
    final toGoalX = targetX - _seenX;
    final toGoalY = _targetGoalY - _seenY;
    final length = sqrt((toGoalX * toGoalX) + (toGoalY * toGoalY));

    if (length < 1e-6) {
      // Sitting on the goal mouth: just come at it straight.
      _wantX = _seenX;
      _wantY = _seenY + (_attackSign * tuning.followThrough);
      return;
    }

    final towardsGoalX = toGoalX / length;
    final towardsGoalY = toGoalY / length;

    final mallet = game.malletFor(player);
    final touching = AirHockeyGame.malletRadius + AirHockeyGame.puckRadius;

    // Where the hand stands relative to the puck, measured along the
    // line the shot has to travel. Positive means it has got in front
    // of the puck, on the goal side -- the wrong side to hit from,
    // because aiming through the puck from there points at where the
    // hand already is, so it parks and the point dies with the puck
    // sitting on the table.
    final alongShot = ((mallet.x - _seenX) * towardsGoalX) +
        ((mallet.y - _seenY) * towardsGoalY);

    // Switching on one threshold would make the hand judder: the aim
    // leaps the moment the hand crosses the line, which moves it back
    // across the line, and the point is spent snapping to and fro.
    // Two thresholds a puck's width apart mean a switch costs real
    // travel, so it happens when the hand has genuinely changed sides
    // and not otherwise. The side it goes round is latched at the same
    // moment, so it cannot change its mind halfway round either.
    if (_goingRound) {
      if (alongShot < -touching * 0.5) _goingRound = false;
    } else if (alongShot > touching * 0.5) {
      _goingRound = true;
      _roundSide = mallet.x >= _seenX ? 1.0 : -1.0;
    }

    if (_goingRound) {
      _wantX = _seenX + (_roundSide * tuning.swingWide);
      _wantY = _seenY - (towardsGoalY * touching * tuning.swingBack);
      return;
    }

    // Behind it: drive through.
    _wantX = _seenX + (towardsGoalX * tuning.followThrough);
    _wantY = _seenY + (towardsGoalY * tuning.followThrough);
  }

  /// Fall back between the puck and the middle of its own goal.
  void _aimAtGuardPost() {
    final centre = AirHockeyGame.tableWidth / 2;
    _wantX = centre + ((_seenX - centre) * tuning.trackingShare);
    _wantY = _ownGoalY + (_attackSign * tuning.restingY);
  }
}
