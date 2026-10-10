import 'dart:math' as math;

/// Stable player identities for Soccer Pool.
enum SoccerPoolPlayer {
  player1,
  player2;

  SoccerPoolPlayer get opponent =>
      this == SoccerPoolPlayer.player1 ? SoccerPoolPlayer.player2 : SoccerPoolPlayer.player1;
}

enum SoccerPoolGameStatus {
  playing,
  won,
}

/// Small immutable vector used by the pure Dart Soccer Pool engine.
class SoccerPoolVector {
  final double x;
  final double y;

  const SoccerPoolVector(this.x, this.y);

  static const zero = SoccerPoolVector(0, 0);

  double get length => math.sqrt((x * x) + (y * y));

  SoccerPoolVector operator +(SoccerPoolVector other) =>
      SoccerPoolVector(x + other.x, y + other.y);

  SoccerPoolVector operator -(SoccerPoolVector other) =>
      SoccerPoolVector(x - other.x, y - other.y);

  SoccerPoolVector scale(double factor) => SoccerPoolVector(x * factor, y * factor);

  SoccerPoolVector get normalized {
    final magnitude = length;
    return magnitude == 0 ? zero : scale(1 / magnitude);
  }

  SoccerPoolVector clampLength(double maximum) {
    final magnitude = length;
    return magnitude <= maximum || magnitude == 0
        ? this
        : scale(maximum / magnitude);
  }
}

/// A player token or the football, expressed in field units.
class SoccerPoolPiece {
  final int id;
  final SoccerPoolPlayer? owner;
  final bool isBall;
  SoccerPoolVector position;
  SoccerPoolVector velocity;

  SoccerPoolPiece({
    required this.id,
    required this.owner,
    required this.isBall,
    required this.position,
    this.velocity = SoccerPoolVector.zero,
  });
}
