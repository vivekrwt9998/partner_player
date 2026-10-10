import 'dart:math';

import 'package:meta/meta.dart';

import '../models/air_hockey_models.dart';

/// Pure Dart engine for Air Hockey.
///
/// ## Units and time
///
/// Everything is in table widths (`W`): the table is `1.0` wide and
/// `2.0` tall, and speeds are `W/s`. The renderer scales the whole thing
/// by the width it is given, so the game behaves identically on every
/// screen. Same convention as Sling Puck.
///
/// `y` runs from 0 at the top (Red's goal) to 2.0 at the bottom (Blue's
/// goal), so Blue defends the near end and attacks the far one, which is
/// the seating AGENTS.md §10.1.2 describes.
///
/// The solver runs on a **fixed 1/240 s step** driven from an
/// accumulator, so a shot behaves the same at 30, 60 or 120 fps.
///
/// ## Why a mallet has a speed limit
///
/// A finger can cross the screen in one frame; a mallet that followed it
/// exactly would jump straight past the puck without ever touching it.
/// Instead the mallet travels toward the finger at up to
/// [maxMalletSpeed], and the puck is struck with the speed the mallet
/// genuinely had. A flick of the finger is therefore a firm shove rather
/// than a teleport, and nothing can tunnel.
///
/// ## Scoring
///
/// There is no turn to take: both players push at once, and the first to
/// [goalsToWin] goals takes the match. After each goal the table is set
/// up again and play is held for [goalPauseSeconds] so the goal can be
/// read before the puck is live again.
class AirHockeyGame {
  AirHockeyGame() {
    _puck = PuckBody(x: tableWidth / 2, y: tableHeight / 2);
    _blueMallet = MalletBody(
      owner: AirHockeyPlayer.player1,
      x: tableWidth / 2,
      y: _blueHomeY,
    );
    _redMallet = MalletBody(
      owner: AirHockeyPlayer.player2,
      x: tableWidth / 2,
      y: _redHomeY,
    );
    reset();
  }

  /// The table is 1 wide and 2 tall, the proportions of a real one stood
  /// on its end.
  static const double tableWidth = 1;
  static const double tableHeight = 2;

  static const int goalsToWin = 3;

  static const double puckRadius = 0.06;
  static const double malletRadius = 0.092;

  /// Half the width of a goal mouth, measured from the centre line of
  /// the table.
  static const double goalHalfWidth = 0.19;

  /// Ceiling on how fast a mallet may travel toward the finger.
  static const double maxMalletSpeed = 4;

  /// Ceiling on puck speed. Also what keeps a step short enough that
  /// nothing can pass through a wall between steps.
  static const double maxPuckSpeed = 3.4;

  /// How far a puck launched at [maxPuckSpeed] travels, in table widths,
  /// before it comes to rest.
  ///
  /// Stated as a distance rather than as a decay rate because this is
  /// the thing anyone tuning the game actually has an opinion about: the
  /// table is 2 widths long, so a shot that runs 2.6 crosses it and
  /// settles rather than rattling from end to end.
  static const double slideDistance = 2.6;

  /// How long the table is held still after a goal.
  static const double goalPauseSeconds = 1.1;

  static const double _step = 1 / 240;

  /// Fraction of its speed the puck keeps per second, derived from
  /// [slideDistance].
  ///
  /// Speed decays as `v0 * keep^t`, so the distance left in a puck is
  /// `v0 / -ln(keep)`. Turning that round gives the keep that produces
  /// the slide we actually want, which means changing the top speed no
  /// longer silently changes how far a shot runs.
  static final double _speedKeptPerSecond = exp(-maxPuckSpeed / slideDistance);

  /// Below this the puck is simply stopped, so it does not creep.
  static const double _restSpeed = 0.012;

  /// How much of its speed the puck keeps off a wall and off a mallet.
  static const double _wallRestitution = 0.88;
  static const double _malletRestitution = 0.92;

  static const double _blueHomeY = tableHeight * 0.78;
  static const double _redHomeY = tableHeight * 0.22;

  late final PuckBody _puck;
  late final MalletBody _blueMallet;
  late final MalletBody _redMallet;

  late AirHockeyGameStatus _status;
  AirHockeyPlayer? _winner;
  AirHockeyPlayer? _lastScorer;

  final Map<AirHockeyPlayer, int> _scores = {};

  double _accumulator = 0;
  double _pauseRemaining = 0;
  int _goalCount = 0;

  PuckBody get puck => _puck;

  AirHockeyGameStatus get status => _status;

  AirHockeyPlayer? get winner => _winner;

  bool get isGameOver => _status != AirHockeyGameStatus.playing;

  /// Who put the last goal away, for the screen's celebration. Stays set
  /// after the pause ends so the result screen can use it too.
  AirHockeyPlayer? get lastScorer => _lastScorer;

  /// Seconds left of the hold after a goal. While this is above zero
  /// nothing on the table moves.
  double get pauseRemaining => _pauseRemaining;

  bool get isPaused => _pauseRemaining > 0;

  /// How many goals have been scored in this match, by either player.
  /// The screen uses it to tell a fresh goal from a redraw.
  int get goalCount => _goalCount;

  int get blueScore => scoreOf(AirHockeyPlayer.player1);

  int get redScore => scoreOf(AirHockeyPlayer.player2);

  int scoreOf(AirHockeyPlayer player) => _scores[player] ?? 0;

  MalletBody malletFor(AirHockeyPlayer player) =>
      player == AirHockeyPlayer.player1 ? _blueMallet : _redMallet;

  /// The y range a player's mallet is allowed to live in. Neither player
  /// may reach across the centre line.
  (double, double) malletRangeY(AirHockeyPlayer player) =>
      player == AirHockeyPlayer.player1
          ? ((tableHeight / 2) + malletRadius, tableHeight - malletRadius)
          : (malletRadius, (tableHeight / 2) - malletRadius);

  /// Points a player's mallet at [x]/[y], which is wherever their finger
  /// is. Clamped into their own half and inside the walls; the mallet
  /// then travels there over the following steps.
  void steerMallet(AirHockeyPlayer player, double x, double y) {
    if (isGameOver) return;

    final mallet = malletFor(player);
    final (minY, maxY) = malletRangeY(player);
    mallet
      ..isHeld = true
      ..targetX = x.clamp(malletRadius, tableWidth - malletRadius)
      ..targetY = y.clamp(minY, maxY);
  }

  /// The finger has come off: the mallet stops where it is rather than
  /// drifting on.
  void releaseMallet(AirHockeyPlayer player) {
    final mallet = malletFor(player);
    mallet
      ..isHeld = false
      ..targetX = mallet.x
      ..targetY = mallet.y
      ..vx = 0
      ..vy = 0;
  }

  /// Advances the simulation by [dt] real seconds.
  void advance(double dt) {
    if (isGameOver || dt <= 0) return;

    // A long stall -- a backgrounded app, a slow first frame -- must not
    // be replayed as hundreds of catch-up steps.
    _accumulator += min(dt, 0.1);

    while (_accumulator >= _step) {
      _accumulator -= _step;
      _advanceOneStep(_step);
    }
  }

  void reset() {
    _status = AirHockeyGameStatus.playing;
    _winner = null;
    _lastScorer = null;
    _scores.clear();
    _accumulator = 0;
    _pauseRemaining = 0;
    _goalCount = 0;
    _setUpTable();
  }

  /// Drops a whole position in, for tests.
  ///
  /// Reaching an interesting air hockey position by steering mallets for
  /// several simulated seconds is neither readable nor reliable, so the
  /// engine takes the same debug seam the other games have.
  @visibleForTesting
  void debugConfigure({
    double? puckX,
    double? puckY,
    double? puckVx,
    double? puckVy,
    double? blueMalletX,
    double? blueMalletY,
    double? redMalletX,
    double? redMalletY,
    int blueScore = 0,
    int redScore = 0,
  }) {
    _status = AirHockeyGameStatus.playing;
    _winner = null;
    _lastScorer = null;
    _accumulator = 0;
    _pauseRemaining = 0;
    _goalCount = blueScore + redScore;
    _scores[AirHockeyPlayer.player1] = blueScore;
    _scores[AirHockeyPlayer.player2] = redScore;

    _puck
      ..x = puckX ?? tableWidth / 2
      ..y = puckY ?? tableHeight / 2
      ..vx = puckVx ?? 0
      ..vy = puckVy ?? 0;

    // Mallets park where they are told, so a test can move them out of
    // the way of a shot it wants to watch. Blocking one is the whole
    // point of a mallet, so a test about walls or goals has to say where
    // they are rather than hope.
    _place(_blueMallet, blueMalletX, blueMalletY, _blueHomeY);
    _place(_redMallet, redMalletX, redMalletY, _redHomeY);
  }

  void _place(MalletBody mallet, double? x, double? y, double homeY) {
    mallet
      ..x = x ?? tableWidth / 2
      ..y = y ?? homeY
      ..targetX = mallet.x
      ..targetY = mallet.y
      ..vx = 0
      ..vy = 0
      ..isHeld = false;
  }

  // ── The solver ────────────────────────────────────────────────────────

  void _advanceOneStep(double dt) {
    if (_pauseRemaining > 0) {
      _pauseRemaining = max(0, _pauseRemaining - dt);
      return;
    }

    _moveMallets(dt);
    _movePuck(dt);
    _bounceOffWalls();
    _bounceOffMallet(_blueMallet);
    _bounceOffMallet(_redMallet);
    _applyFriction(dt);
    _checkForGoal();
  }

  void _moveMallets(double dt) {
    for (final mallet in [_blueMallet, _redMallet]) {
      final dx = mallet.targetX - mallet.x;
      final dy = mallet.targetY - mallet.y;
      final distance = sqrt((dx * dx) + (dy * dy));

      if (distance < 1e-9) {
        mallet
          ..vx = 0
          ..vy = 0;
        continue;
      }

      final reach = min(distance, maxMalletSpeed * dt);
      final nx = dx / distance;
      final ny = dy / distance;

      mallet
        ..x += nx * reach
        ..y += ny * reach
        ..vx = (nx * reach) / dt
        ..vy = (ny * reach) / dt;
    }
  }

  void _movePuck(double dt) {
    _puck
      ..x += _puck.vx * dt
      ..y += _puck.vy * dt;
  }

  void _bounceOffWalls() {
    // Side walls run the full length, so these are unconditional.
    if (_puck.x < puckRadius) {
      _puck
        ..x = puckRadius
        ..vx = -_puck.vx * _wallRestitution;
    } else if (_puck.x > tableWidth - puckRadius) {
      _puck
        ..x = tableWidth - puckRadius
        ..vx = -_puck.vx * _wallRestitution;
    }

    // The ends have a hole in them, so a puck lined up with the mouth
    // carries straight on into the goal.
    final inMouth = _isInGoalMouth;

    if (_puck.y < puckRadius && !inMouth) {
      _puck
        ..y = puckRadius
        ..vy = -_puck.vy * _wallRestitution;
    } else if (_puck.y > tableHeight - puckRadius && !inMouth) {
      _puck
        ..y = tableHeight - puckRadius
        ..vy = -_puck.vy * _wallRestitution;
    }

    _bounceOffPosts();
  }

  /// The four goal posts, as small circles the puck can rattle off.
  ///
  /// Without these a puck clipping the edge of a mouth would slice
  /// through the end wall, because whether it passes is decided by its
  /// centre alone.
  void _bounceOffPosts() {
    for (final postY in [0.0, tableHeight]) {
      for (final side in [-1, 1]) {
        final postX = (tableWidth / 2) + (side * goalHalfWidth);
        final dx = _puck.x - postX;
        final dy = _puck.y - postY;
        final distance = sqrt((dx * dx) + (dy * dy));
        if (distance >= puckRadius || distance < 1e-9) continue;

        final nx = dx / distance;
        final ny = dy / distance;
        _puck
          ..x = postX + (nx * puckRadius)
          ..y = postY + (ny * puckRadius);

        final along = (_puck.vx * nx) + (_puck.vy * ny);
        if (along >= 0) continue;
        _puck
          ..vx -= (1 + _wallRestitution) * along * nx
          ..vy -= (1 + _wallRestitution) * along * ny;
      }
    }
  }

  void _bounceOffMallet(MalletBody mallet) {
    final dx = _puck.x - mallet.x;
    final dy = _puck.y - mallet.y;
    final touching = puckRadius + malletRadius;
    var distance = sqrt((dx * dx) + (dy * dy));
    if (distance >= touching) return;

    // Dead centre: shove it along the table rather than divide by zero.
    final nx = distance < 1e-9 ? 0.0 : dx / distance;
    final ny = distance < 1e-9 ? 1.0 : dy / distance;
    if (distance < 1e-9) distance = 0;

    // Lift the puck clear first, so it cannot sit inside the mallet and
    // be re-hit every step.
    _puck
      ..x = mallet.x + (nx * touching)
      ..y = mallet.y + (ny * touching);
    _keepPuckOnTable();

    // The mallet is a hand, not a free body: all of the impulse lands on
    // the puck and none of it comes back.
    final rvx = _puck.vx - mallet.vx;
    final rvy = _puck.vy - mallet.vy;
    final along = (rvx * nx) + (rvy * ny);
    if (along >= 0) return;

    final impulse = -(1 + _malletRestitution) * along;
    _puck
      ..vx += impulse * nx
      ..vy += impulse * ny;
    _capPuckSpeed();
  }

  void _applyFriction(double dt) {
    if (!_puck.isMoving) return;

    final keep = pow(_speedKeptPerSecond, dt).toDouble();
    _puck
      ..vx *= keep
      ..vy *= keep;

    if (_puck.speed < _restSpeed) {
      _puck
        ..vx = 0
        ..vy = 0;
    }
    _capPuckSpeed();
  }

  void _capPuckSpeed() {
    final speed = _puck.speed;
    if (speed <= maxPuckSpeed || speed == 0) return;

    final scale = maxPuckSpeed / speed;
    _puck
      ..vx *= scale
      ..vy *= scale;
  }

  /// A goal is the puck's centre crossing a goal line. By then it is
  /// half inside the mouth, which is the moment it reads as scored.
  void _checkForGoal() {
    if (_puck.y > 0 && _puck.y < tableHeight) return;

    // Crossing the line is not enough -- it has to be through the
    // mouth. A puck pinched into a corner by a striker gets shoved past
    // the end wall where there is no hole at all, and counting that as
    // a goal is a goal nobody scored.
    if (!_isInGoalMouth) {
      _puck
        ..y = _puck.y <= 0 ? puckRadius : tableHeight - puckRadius
        ..vy = -_puck.vy * _wallRestitution;
      return;
    }

    // Blue attacks the far end, so the puck going out of the top is
    // Blue's goal.
    final scorer =
        _puck.y <= 0 ? AirHockeyPlayer.player1 : AirHockeyPlayer.player2;
    _award(scorer);
  }

  bool get _isInGoalMouth =>
      (_puck.x - (tableWidth / 2)).abs() <= goalHalfWidth;

  /// Puts the puck back inside the walls after something moved it there
  /// directly rather than by travelling.
  ///
  /// The only way off the table is through a mouth, so the ends are
  /// left alone when the puck is lined up with one -- a striker really
  /// can shove the puck into the goal.
  void _keepPuckOnTable() {
    _puck.x = _puck.x.clamp(puckRadius, tableWidth - puckRadius);
    if (_isInGoalMouth) return;
    _puck.y = _puck.y.clamp(puckRadius, tableHeight - puckRadius);
  }

  void _award(AirHockeyPlayer scorer) {
    _scores[scorer] = scoreOf(scorer) + 1;
    _lastScorer = scorer;
    _goalCount++;

    if (scoreOf(scorer) >= goalsToWin) {
      _status = AirHockeyGameStatus.won;
      _winner = scorer;
      _setUpTable();
      return;
    }

    _pauseRemaining = goalPauseSeconds;
    _setUpTable();
  }

  /// Puts the puck back on the centre spot and both mallets back home.
  void _setUpTable() {
    _puck
      ..x = tableWidth / 2
      ..y = tableHeight / 2
      ..vx = 0
      ..vy = 0;

    _blueMallet
      ..x = tableWidth / 2
      ..y = _blueHomeY
      ..targetX = tableWidth / 2
      ..targetY = _blueHomeY
      ..vx = 0
      ..vy = 0
      ..isHeld = false;

    _redMallet
      ..x = tableWidth / 2
      ..y = _redHomeY
      ..targetX = tableWidth / 2
      ..targetY = _redHomeY
      ..vx = 0
      ..vy = 0
      ..isHeld = false;
  }
}
