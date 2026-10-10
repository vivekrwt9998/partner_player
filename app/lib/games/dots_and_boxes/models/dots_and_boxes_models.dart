/// Player representation for Dots and Boxes.
enum DotsAndBoxesPlayer {
  player1,
  player2;

  /// Returns the opponent player.
  DotsAndBoxesPlayer get opponent => this == DotsAndBoxesPlayer.player1
      ? DotsAndBoxesPlayer.player2
      : DotsAndBoxesPlayer.player1;

  /// Display name for the player.
  String get displayName =>
      this == DotsAndBoxesPlayer.player1 ? 'Player 1' : 'Player 2';
}

/// Overall status of the game.
enum DotsAndBoxesGameStatus {
  playing,
  won,

  /// Every box is claimed by the time the last line is drawn, and the
  /// board holds an even number of them, so the two sides really can
  /// come out level.
  draw,
}

/// Which way a line runs between two dots.
enum EdgeOrientation {
  /// Joins the dot at [BoxEdge.row]/[BoxEdge.col] to the one on its right.
  horizontal,

  /// Joins the dot at [BoxEdge.row]/[BoxEdge.col] to the one below it.
  vertical,
}

/// One line between two neighbouring dots, named by the dot it starts
/// from and the direction it runs in.
///
/// Value equality is load-bearing: edges are used as map keys and
/// compared with `contains`.
class BoxEdge {
  final EdgeOrientation orientation;
  final int row;
  final int col;

  const BoxEdge(this.orientation, this.row, this.col);

  const BoxEdge.horizontal(this.row, this.col)
      : orientation = EdgeOrientation.horizontal;

  const BoxEdge.vertical(this.row, this.col)
      : orientation = EdgeOrientation.vertical;

  bool get isHorizontal => orientation == EdgeOrientation.horizontal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoxEdge &&
          runtimeType == other.runtimeType &&
          orientation == other.orientation &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => Object.hash(orientation, row, col);

  @override
  String toString() => 'BoxEdge(${orientation.name}, $row, $col)';
}

/// One box on the board, named by its top-left dot.
class BoxCell {
  final int row;
  final int col;

  const BoxCell(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoxCell &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'BoxCell($row, $col)';
}

/// Immutable information about one successfully drawn line.
class DotsAndBoxesMove {
  final DotsAndBoxesPlayer player;
  final BoxEdge edge;

  /// The boxes this line closed -- one, or two when the line was the
  /// fourth side of the boxes on both sides of it.
  final List<BoxCell> claimedBoxes;

  /// Whether closing a box earned [player] another go.
  final bool playsAgain;

  final DotsAndBoxesGameStatus status;
  final DotsAndBoxesPlayer? winner;

  const DotsAndBoxesMove({
    required this.player,
    required this.edge,
    required this.claimedBoxes,
    required this.playsAgain,
    required this.status,
    required this.winner,
  });

  bool get isTerminal => status != DotsAndBoxesGameStatus.playing;
}
