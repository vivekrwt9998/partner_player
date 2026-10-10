import 'dart:math' as math;

import '../models/soccer_pool_models.dart';

/// Pure Dart rules and lightweight puck physics for Soccer Pool.
///
/// Players take turns slinging one of their five tokens. Pieces and the ball
/// bounce inside the pitch; sending the ball through the opponent's goal
/// scores. First to [winningScore] wins.
class SoccerPoolGame {
  static const double fieldWidth = 1;
  static const double fieldHeight = 1.58;
  static const double tokenRadius = 0.052;
  static const double ballRadius = 0.032;
  /// The goal mouth, as a fraction of the pitch width. Narrow enough that
  /// scoring takes aim rather than a shove in roughly the right direction.
  static const double goalWidth = 0.25;
  static const int winningScore = 3;

  /// The fastest a shot can leave a token, in field units per second.
  static const double maxShotSpeed = 2.4;

  /// How much of its speed a piece keeps after one second. Higher means it
  /// runs further; a full-power shot crosses the pitch and still has
  /// enough left to come off a wall.
  static const double _speedKeptPerSecond = 0.35;

  /// Below this a piece is treated as stopped.
  static const double _restSpeed = 0.02;

  final List<SoccerPoolPiece> _pieces = [];

  late SoccerPoolPlayer _currentPlayer;
  late SoccerPoolGameStatus _status;
  SoccerPoolPlayer? _winner;
  var _blueScore = 0;
  var _redScore = 0;
  var _hasShotInProgress = false;

  SoccerPoolGame() {
    reset();
  }

  List<SoccerPoolPiece> get pieces => List.unmodifiable(_pieces);
  SoccerPoolPlayer get currentPlayer => _currentPlayer;
  SoccerPoolGameStatus get status => _status;
  SoccerPoolPlayer? get winner => _winner;
  int get blueScore => _blueScore;
  int get redScore => _redScore;
  bool get isGameOver => _status == SoccerPoolGameStatus.won;
  bool get isMoving => _hasShotInProgress;
  bool get canShoot => !isGameOver && !_hasShotInProgress;

  SoccerPoolPiece get ball => _pieces.firstWhere((piece) => piece.isBall);

  /// Starts a turn by launching [pieceId] in [velocity]'s direction.
  bool tryShoot(int pieceId, SoccerPoolVector velocity) {
    if (!canShoot || velocity.length < 0.08) return false;

    final piece = _pieceForId(pieceId);
    if (piece == null || piece.owner != _currentPlayer) return false;

    piece.velocity = velocity.clampLength(maxShotSpeed);
    _hasShotInProgress = true;
    return true;
  }

  /// Advances the in-progress shot. The screen supplies elapsed wall time;
  /// this engine owns all collision, scoring, and turn rules.
  bool advance(double elapsedSeconds) {
    if (!_hasShotInProgress || isGameOver) return false;

    final boundedElapsed = elapsedSeconds.clamp(0.0, 0.035).toDouble();
    if (boundedElapsed == 0) return false;

    final steps = math.max(1, (boundedElapsed / 0.008).ceil());
    final stepDuration = boundedElapsed / steps;
    for (var step = 0; step < steps; step++) {
      _integrate(stepDuration);
      _resolveCollisions();
      if (_resolveGoal()) return true;
      _applyFriction(stepDuration);
    }

    if (_pieces.every((piece) => piece.velocity.length < _restSpeed)) {
      for (final piece in _pieces) {
        piece.velocity = SoccerPoolVector.zero;
      }
      _hasShotInProgress = false;
      _currentPlayer = _currentPlayer.opponent;
    }

    return true;
  }

  void reset() {
    _blueScore = 0;
    _redScore = 0;
    _currentPlayer = SoccerPoolPlayer.player1;
    _status = SoccerPoolGameStatus.playing;
    _winner = null;
    _resetPieces();
  }

  SoccerPoolPiece? _pieceForId(int id) {
    for (final piece in _pieces) {
      if (piece.id == id) return piece;
    }
    return null;
  }

  void _resetPieces() {
    _pieces
      ..clear()
      ..addAll([
        // Red protects the top goal; Blue protects the bottom goal.
        SoccerPoolPiece(id: 1, owner: SoccerPoolPlayer.player2, isBall: false, position: const SoccerPoolVector(0.50, 0.18)),
        SoccerPoolPiece(id: 2, owner: SoccerPoolPlayer.player2, isBall: false, position: const SoccerPoolVector(0.28, 0.39)),
        SoccerPoolPiece(id: 3, owner: SoccerPoolPlayer.player2, isBall: false, position: const SoccerPoolVector(0.72, 0.39)),
        SoccerPoolPiece(id: 4, owner: SoccerPoolPlayer.player2, isBall: false, position: const SoccerPoolVector(0.50, 0.55)),
        SoccerPoolPiece(id: 5, owner: SoccerPoolPlayer.player2, isBall: false, position: const SoccerPoolVector(0.50, 0.69)),
        SoccerPoolPiece(id: 6, owner: SoccerPoolPlayer.player1, isBall: false, position: const SoccerPoolVector(0.50, 1.40)),
        SoccerPoolPiece(id: 7, owner: SoccerPoolPlayer.player1, isBall: false, position: const SoccerPoolVector(0.28, 1.19)),
        SoccerPoolPiece(id: 8, owner: SoccerPoolPlayer.player1, isBall: false, position: const SoccerPoolVector(0.72, 1.19)),
        SoccerPoolPiece(id: 9, owner: SoccerPoolPlayer.player1, isBall: false, position: const SoccerPoolVector(0.50, 1.03)),
        SoccerPoolPiece(id: 10, owner: SoccerPoolPlayer.player1, isBall: false, position: const SoccerPoolVector(0.50, 0.89)),
        SoccerPoolPiece(id: 0, owner: null, isBall: true, position: const SoccerPoolVector(0.50, fieldHeight / 2)),
      ]);
    _hasShotInProgress = false;
  }

  void _integrate(double duration) {
    for (final piece in _pieces) {
      piece.position = piece.position + piece.velocity.scale(duration);
      _resolveWallCollision(piece);
    }
  }

  void _resolveWallCollision(SoccerPoolPiece piece) {
    final radius = piece.isBall ? ballRadius : tokenRadius;
    var x = piece.position.x;
    var y = piece.position.y;
    var velocity = piece.velocity;

    if (x < radius) {
      x = radius;
      velocity = SoccerPoolVector(-velocity.x * 0.72, velocity.y);
    } else if (x > fieldWidth - radius) {
      x = fieldWidth - radius;
      velocity = SoccerPoolVector(-velocity.x * 0.72, velocity.y);
    }

    final insideGoal = piece.isBall &&
        x > ((fieldWidth - goalWidth) / 2) &&
        x < ((fieldWidth + goalWidth) / 2);
    if (!insideGoal && y < radius) {
      y = radius;
      velocity = SoccerPoolVector(velocity.x, -velocity.y * 0.72);
    } else if (!insideGoal && y > fieldHeight - radius) {
      y = fieldHeight - radius;
      velocity = SoccerPoolVector(velocity.x, -velocity.y * 0.72);
    }

    piece
      ..position = SoccerPoolVector(x, y)
      ..velocity = velocity;
  }

  void _resolveCollisions() {
    for (var firstIndex = 0; firstIndex < _pieces.length; firstIndex++) {
      for (var secondIndex = firstIndex + 1;
          secondIndex < _pieces.length;
          secondIndex++) {
        _resolvePairCollision(_pieces[firstIndex], _pieces[secondIndex]);
      }
    }
  }

  void _resolvePairCollision(SoccerPoolPiece first, SoccerPoolPiece second) {
    final delta = second.position - first.position;
    final minimumDistance = (first.isBall ? ballRadius : tokenRadius) +
        (second.isBall ? ballRadius : tokenRadius);
    final distance = delta.length;
    if (distance == 0 || distance >= minimumDistance) return;

    final normal = delta.scale(1 / distance);
    final overlap = minimumDistance - distance;
    first.position = first.position - normal.scale(overlap / 2);
    second.position = second.position + normal.scale(overlap / 2);

    final relativeVelocity = second.velocity - first.velocity;
    final speedTowardsEachOther = (relativeVelocity.x * normal.x) +
        (relativeVelocity.y * normal.y);
    if (speedTowardsEachOther >= 0) return;

    const restitution = 0.82;
    final impulse = -(1 + restitution) * speedTowardsEachOther / 2;
    first.velocity = first.velocity - normal.scale(impulse);
    second.velocity = second.velocity + normal.scale(impulse);
  }

  bool _resolveGoal() {
    final football = ball;
    final goalMinX = (fieldWidth - goalWidth) / 2;
    final goalMaxX = (fieldWidth + goalWidth) / 2;
    if (football.position.x < goalMinX || football.position.x > goalMaxX) {
      return false;
    }

    if (football.position.y < -ballRadius) {
      _registerGoal(SoccerPoolPlayer.player1);
      return true;
    }
    if (football.position.y > fieldHeight + ballRadius) {
      _registerGoal(SoccerPoolPlayer.player2);
      return true;
    }
    return false;
  }

  void _registerGoal(SoccerPoolPlayer scorer) {
    if (scorer == SoccerPoolPlayer.player1) {
      _blueScore++;
    } else {
      _redScore++;
    }

    if (_blueScore >= winningScore || _redScore >= winningScore) {
      _status = SoccerPoolGameStatus.won;
      _winner = scorer;
      _hasShotInProgress = false;
      return;
    }

    _currentPlayer = _currentPlayer.opponent;
    _resetPieces();
  }

  void _applyFriction(double duration) {
    final friction = math.pow(_speedKeptPerSecond, duration).toDouble();
    for (final piece in _pieces) {
      piece.velocity = piece.velocity.scale(friction);
    }
  }
}
