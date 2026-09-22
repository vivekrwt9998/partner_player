/// Player representation for Color War.
enum ColorWarPlayer {
  player1,
  player2;

  /// Returns the opponent player.
  ColorWarPlayer get opponent =>
      this == ColorWarPlayer.player1 ? ColorWarPlayer.player2 : ColorWarPlayer.player1;

  /// Display name for the player.
  String get displayName =>
      this == ColorWarPlayer.player1 ? 'Player 1' : 'Player 2';
}

/// Overall status of the game.
///
/// There is no draw: a chain reaction always ends with one colour holding
/// every orb on the board.
enum ColorWarGameStatus {
  playing,
  won,
}

/// The contents of one cell: how many orbs it holds and whose they are.
///
/// Immutable, so a board snapshot for Revert is just a copy of the rows.
class ColorWarCell {
  final ColorWarPlayer? owner;
  final int orbs;

  const ColorWarCell({this.owner, this.orbs = 0});

  /// A cell with nothing in it.
  static const ColorWarCell empty = ColorWarCell();

  bool get isEmpty => orbs == 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColorWarCell &&
          runtimeType == other.runtimeType &&
          owner == other.owner &&
          orbs == other.orbs;

  @override
  int get hashCode => Object.hash(owner, orbs);

  @override
  String toString() => 'ColorWarCell($owner, $orbs)';
}

/// A grid coordinate on the board.
///
/// [row] counts from 0 at the top, [col] from 0 at the left.
class ColorWarPosition {
  final int row;
  final int col;

  const ColorWarPosition(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColorWarPosition &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'ColorWarPosition($row, $col)';
}

/// Immutable information about one successfully applied orb placement.
///
/// [willExplode] means the placement left the board mid-cascade: the caller
/// must drive `ColorWarGame.stepBlast` until it settles before the turn
/// passes to the other player.
class ColorWarMove {
  final ColorWarPlayer player;
  final int row;
  final int col;
  final bool willExplode;
  final ColorWarGameStatus status;
  final ColorWarPlayer? winner;

  const ColorWarMove({
    required this.player,
    required this.row,
    required this.col,
    required this.willExplode,
    required this.status,
    required this.winner,
  });

  bool get isTerminal => status != ColorWarGameStatus.playing;
}

/// One wave of a chain reaction: every cell that burst at the same moment,
/// and what the board looked like afterwards.
///
/// The engine resolves a cascade one wave at a time so the screen can show
/// the reaction spreading instead of the board teleporting to its final
/// state.
class ColorWarBlast {
  /// Whose reaction this is. Every orb thrown out by this wave lands in
  /// this player's colour.
  final ColorWarPlayer player;

  /// The cells that burst in this wave.
  final List<ColorWarPosition> sources;

  /// Whether more waves are still queued after this one.
  final bool hasMore;

  final ColorWarGameStatus status;
  final ColorWarPlayer? winner;

  const ColorWarBlast({
    required this.player,
    required this.sources,
    required this.hasMore,
    required this.status,
    required this.winner,
  });
}
