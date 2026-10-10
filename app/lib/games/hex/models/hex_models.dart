/// Player representation for Hex.
enum HexPlayer {
  player1,
  player2;

  /// Returns the opponent player.
  HexPlayer get opponent =>
      this == HexPlayer.player1 ? HexPlayer.player2 : HexPlayer.player1;

  /// Display name for the player.
  String get displayName =>
      this == HexPlayer.player1 ? 'Player 1' : 'Player 2';
}

/// Overall status of the game.
///
/// There is deliberately no `draw` here. Hex cannot be drawn: fill the
/// board however you like and exactly one player ends up holding a
/// chain between their two sides. Reversi needs three values, Checkers
/// needs two for a different reason, and inventing an unreachable third
/// value for Hex would only force a dead arm into the result switch.
enum HexGameStatus {
  playing,
  won,
}

/// A cell on the board.
///
/// [row] counts from 0 at the top, [col] from 0 at the left. Columns
/// step down-and-right on screen, rows step straight down. Value
/// equality is load-bearing: cells go into sets and maps while the
/// engine walks a chain.
class HexCell {
  final int row;
  final int col;

  const HexCell(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HexCell &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'HexCell($row, $col)';
}

/// Immutable information about one successfully placed stone.
class HexMove {
  final HexPlayer player;

  /// Where the new stone was laid down. A Hex stone is never moved,
  /// taken or turned over afterwards, so this is the whole of what the
  /// move did to the board.
  final HexCell cell;

  final HexGameStatus status;
  final HexPlayer? winner;

  /// Empty until the move that wins. Then it is the single unbroken
  /// chain the engine traced from one of the winner's sides to the
  /// other, in order, for the screen to light up (AGENTS.md 10.1.14).
  final List<HexCell> winningPath;

  const HexMove({
    required this.player,
    required this.cell,
    required this.status,
    required this.winner,
    this.winningPath = const [],
  });

  bool get isTerminal => status != HexGameStatus.playing;
}
