/// Player representation for Four in a Row.
enum FourInARowPlayer {
  player1,
  player2;

  /// Returns the opponent player.
  FourInARowPlayer get opponent =>
      this == FourInARowPlayer.player1 ? FourInARowPlayer.player2 : FourInARowPlayer.player1;

  /// Display name for the player.
  String get displayName => this == FourInARowPlayer.player1 ? 'Player 1' : 'Player 2';
}

/// Overall status of the game.
enum FourInARowGameStatus {
  playing,
  won,
  draw,
}

/// Represents a grid coordinate on the board.
///
/// [row] ranges from 0 (top) to 5 (bottom).
/// [col] ranges from 0 (left) to 6 (right).
class BoardPosition {
  final int row;
  final int col;

  const BoardPosition(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardPosition &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  @override
  String toString() => 'BoardPosition($row, $col)';
}

/// Win result holding winner and the winning line positions.
class FourInARowWinResult {
  final FourInARowPlayer winner;
  final List<BoardPosition> winningPositions;

  const FourInARowWinResult({
    required this.winner,
    required this.winningPositions,
  });
}
