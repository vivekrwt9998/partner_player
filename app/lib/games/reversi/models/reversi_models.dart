/// Player representation for Reversi.
enum ReversiPlayer {
  player1,
  player2;

  /// Returns the opponent player.
  ReversiPlayer get opponent => this == ReversiPlayer.player1
      ? ReversiPlayer.player2
      : ReversiPlayer.player1;

  /// Display name for the player.
  String get displayName =>
      this == ReversiPlayer.player1 ? 'Player 1' : 'Player 2';
}

/// Overall status of the game.
///
/// Unlike Checkers, Reversi really can end level: when neither side can
/// move, the board is counted, and an even split is a draw.
enum ReversiGameStatus {
  playing,
  won,
  draw,
}

/// A square on the board.
///
/// [row] counts from 0 at the top, [col] from 0 at the left. Value
/// equality is load-bearing: positions are used as map keys and compared
/// with `contains`.
class ReversiPosition {
  final int row;
  final int col;

  const ReversiPosition(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReversiPosition &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'ReversiPosition($row, $col)';
}

/// Immutable information about one successfully played disc.
class ReversiMove {
  final ReversiPlayer player;

  /// Where the new disc was laid down.
  final ReversiPosition position;

  /// Every disc this move turned over, in the order the engine walked
  /// them out from [position]. The screen animates these.
  final List<ReversiPosition> flipped;

  /// Set when the opponent had no legal reply and the turn came straight
  /// back to [player], so the screen can say so.
  final ReversiPlayer? passedPlayer;

  final ReversiGameStatus status;
  final ReversiPlayer? winner;

  const ReversiMove({
    required this.player,
    required this.position,
    required this.flipped,
    required this.passedPlayer,
    required this.status,
    required this.winner,
  });

  bool get isTerminal => status != ReversiGameStatus.playing;
}
