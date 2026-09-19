/// Player representation for Tic Tac Toe.
enum TicTacToePlayer {
  player1,
  player2;

  /// Returns the opponent player.
  TicTacToePlayer get opponent =>
      this == TicTacToePlayer.player1 ? TicTacToePlayer.player2 : TicTacToePlayer.player1;

  /// Display name for the player.
  String get displayName => this == TicTacToePlayer.player1 ? 'Player 1' : 'Player 2';
}

/// Overall status of the game.
enum TicTacToeGameStatus {
  playing,
  won,
  draw,
}

/// Immutable information about one successfully applied mark placement.
class TicTacToeMove {
  final TicTacToePlayer player;
  final int row;
  final int col;
  final TicTacToeGameStatus status;
  final TicTacToePlayer? winner;

  const TicTacToeMove({
    required this.player,
    required this.row,
    required this.col,
    required this.status,
    required this.winner,
  });

  bool get isTerminal => status != TicTacToeGameStatus.playing;
}

/// Represents a grid coordinate on the board.
///
/// [row] ranges from 0 (top) to 2 (bottom).
/// [col] ranges from 0 (left) to 2 (right).
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
