import 'dart:math';

/// Player representation for Sling Puck.
enum SlingPuckPlayer {
  player1,
  player2;

  /// Returns the opponent player.
  SlingPuckPlayer get opponent =>
      this == SlingPuckPlayer.player1 ? SlingPuckPlayer.player2 : SlingPuckPlayer.player1;

  /// Display name for the player.
  String get displayName => this == SlingPuckPlayer.player1 ? 'Player 1' : 'Player 2';
}

/// Overall status of the game.
///
/// There is no `draw`: the race ends the moment one player's half is clear.
enum SlingPuckGameStatus {
  playing,
  won,
}

/// Where a band is in its stretch-and-release cycle.
enum BandPhase {
  /// Flat, nothing touching it.
  idle,

  /// At least one piece is pressing it out of shape.
  stretching,

  /// Springing back after a launch (or after a cancelled press).
  releasing,
}

/// A single piece in the live simulation.
///
/// Deliberately **mutable**. The solver runs at 240 Hz over every piece
/// several times per frame, and rebuilding immutable copies in that loop
/// would allocate thousands of objects a second. Callers outside the engine
/// should treat these as read-only.
class Piece {
  Piece({
    required this.id,
    required this.owner,
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    this.boostLeft = 0,
    this.heldBy,
  });

  final int id;

  /// Only the colour a piece started as. It does *not* decide who may sling
  /// it -- whichever half it is resting on does.
  final SlingPuckPlayer owner;

  double x;
  double y;
  double vx;
  double vy;

  /// Seconds of drag-free coasting left from a launch or a hard hit. While
  /// this is positive the piece holds its speed exactly.
  double boostLeft;

  /// The player currently steering this piece with a finger, or `null`.
  /// A held piece is positioned directly and is skipped by the solver.
  SlingPuckPlayer? heldBy;

  bool get isHeld => heldBy != null;

  bool get isMoving => vx != 0 || vy != 0;

  double get speed => sqrt((vx * vx) + (vy * vy));
}

/// One of the two elastic bands, and everything needed to draw it.
///
/// A band is a fixture of the board rather than something attached to a
/// piece: it is always present, and pieces press it out of shape and are
/// catapulted straight back off it.
class Band {
  Band({required this.isTop, required this.restY});

  final bool isTop;

  /// The line the band hangs on when nothing is touching it.
  final double restY;

  /// Which way "into the band" points: -1 for the top band, +1 for the
  /// bottom one. A launch goes the opposite way.
  double get pressNormalY => isTop ? -1 : 1;

  BandPhase phase = BandPhase.idle;

  /// How far the band is currently pushed toward its wall, at the apex.
  /// Negative while it overshoots past flat on the way back.
  double depth = 0;

  /// Where the apex sits across the field. Follows the deepest pressing
  /// piece, then freezes for the spring-back.
  ///
  /// Starts mid-field: the field is 1.0 wide by definition of the unit.
  double apexX = 0.5;

  /// Spring velocity, used only while [phase] is [BandPhase.releasing].
  double springVelocity = 0;

  /// The y the apex is drawn at right now.
  double get apexY => restY + (pressNormalY * depth);

  void reset() {
    phase = BandPhase.idle;
    depth = 0;
    springVelocity = 0;
    apexX = 0.5;
  }
}
