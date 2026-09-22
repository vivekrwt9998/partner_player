/// Player representation for Checkers.
enum CheckersPlayer {
  player1,
  player2;

  /// Returns the opponent player.
  CheckersPlayer get opponent =>
      this == CheckersPlayer.player1 ? CheckersPlayer.player2 : CheckersPlayer.player1;

  /// Display name for the player.
  String get displayName => this == CheckersPlayer.player1 ? 'Player 1' : 'Player 2';
}

/// Overall status of the game.
///
/// There is no `draw`: a player loses the moment they have no piece left
/// that can move, so every finished game has a winner.
enum CheckersGameStatus {
  playing,
  won,
}

/// A single checker piece.
class CheckersPiece {
  final CheckersPlayer player;
  final bool isKing;

  const CheckersPiece({required this.player, required this.isKing});

  CheckersPiece copyWith({bool? isKing}) {
    return CheckersPiece(player: player, isKing: isKing ?? this.isKing);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckersPiece &&
          runtimeType == other.runtimeType &&
          player == other.player &&
          isKing == other.isKing;

  @override
  int get hashCode => Object.hash(player, isKing);
}

/// Represents a grid coordinate on the board.
///
/// [row] ranges from 0 (top) to 7 (bottom).
/// [col] ranges from 0 (left) to 7 (right).
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

/// Immutable information about one successfully applied move.
class CheckersMove {
  final CheckersPlayer player;
  final BoardPosition from;
  final BoardPosition to;

  /// The square a captured piece was removed from, or `null` for a
  /// non-capturing move.
  final BoardPosition? captured;

  /// Whether this move crowned the piece as a King.
  final bool promoted;

  /// Whether the same piece must jump again before the turn passes (a
  /// multi-capture chain).
  final bool mustContinue;

  final CheckersGameStatus status;
  final CheckersPlayer? winner;

  const CheckersMove({
    required this.player,
    required this.from,
    required this.to,
    required this.captured,
    required this.promoted,
    required this.mustContinue,
    required this.status,
    required this.winner,
  });

  bool get isTerminal => status != CheckersGameStatus.playing;
}
