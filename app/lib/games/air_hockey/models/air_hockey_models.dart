import 'dart:math';

/// Player representation for Air Hockey.
enum AirHockeyPlayer {
  player1,
  player2;

  /// Returns the opponent player.
  AirHockeyPlayer get opponent => this == AirHockeyPlayer.player1
      ? AirHockeyPlayer.player2
      : AirHockeyPlayer.player1;

  /// Display name for the player.
  String get displayName =>
      this == AirHockeyPlayer.player1 ? 'Player 1' : 'Player 2';
}

/// Overall status of the game.
///
/// There is no `draw`: the match ends the moment somebody reaches the
/// goal target, and only one player can get there first.
enum AirHockeyGameStatus {
  playing,
  won,
}

/// A body in the live simulation.
///
/// Deliberately **mutable**, like Sling Puck's [Piece]: the solver runs
/// at 240 Hz over these several times a frame, and rebuilding immutable
/// copies in that loop would allocate thousands of objects a second.
/// Callers outside the engine should treat them as read-only.
class PuckBody {
  PuckBody({
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
  });

  double x;
  double y;
  double vx;
  double vy;

  double get speed => sqrt((vx * vx) + (vy * vy));

  bool get isMoving => vx != 0 || vy != 0;
}

/// A player's striker.
///
/// A mallet is steered rather than thrown: the screen says where the
/// finger is, and the mallet travels there under its own speed limit.
/// That limit is what stops a flung finger from teleporting the mallet
/// straight through the puck, and it is also what gives a shove its
/// weight -- the puck is hit with however fast the mallet was actually
/// moving, not with how fast the finger was.
class MalletBody {
  MalletBody({
    required this.owner,
    required this.x,
    required this.y,
  })  : targetX = x,
        targetY = y;

  final AirHockeyPlayer owner;

  double x;
  double y;

  /// Where the finger is asking the mallet to be. Equal to the mallet's
  /// own position while nobody is touching it.
  double targetX;
  double targetY;

  /// How fast the mallet actually moved on the last step, which is what
  /// the puck gets hit with.
  double vx = 0;
  double vy = 0;

  /// Whether a finger is currently steering this mallet.
  bool isHeld = false;

  double get speed => sqrt((vx * vx) + (vy * vy));
}
