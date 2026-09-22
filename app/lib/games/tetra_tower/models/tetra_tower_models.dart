import 'dart:math' as math;

/// Player representation for Tetra Tower.
enum TetraTowerPlayer {
  player1,
  player2;

  /// Returns the opponent player.
  TetraTowerPlayer get opponent =>
      this == TetraTowerPlayer.player1 ? TetraTowerPlayer.player2 : TetraTowerPlayer.player1;

  /// Display name for the player.
  String get displayName => this == TetraTowerPlayer.player1 ? 'Player 1' : 'Player 2';
}

/// Overall status of the game.
///
/// There is no `draw`: the tower falls on somebody, or the game is still
/// going.
enum TetraTowerGameStatus {
  playing,
  collapsed,
}

/// Represents a grid coordinate within a single layer.
///
/// [row] and [col] both range from 0 to [TetraTowerGame.gridSize] - 1
/// (defined in the engine file to avoid a circular import).
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

/// The seven classic tetromino shapes. Each carries its own distinct
/// on-screen rotations (some have only 1 or 2 unique rotations since they're
/// symmetric); see [rotations].
enum TetrominoShape {
  i,
  o,
  t,
  s,
  z,
  j,
  l;

  /// One canonical layout per shape, in an unrotated orientation. Every
  /// other rotation is derived from this at load time (see [rotations]) --
  /// hand-writing all 4 rotations for every shape would just be more
  /// opportunities to typo a coordinate.
  List<(int, int)> get _canonicalCells => switch (this) {
        TetrominoShape.i => const [(0, 0), (0, 1), (0, 2), (0, 3)],
        TetrominoShape.o => const [(0, 0), (0, 1), (1, 0), (1, 1)],
        TetrominoShape.t => const [(0, 0), (0, 1), (0, 2), (1, 1)],
        TetrominoShape.s => const [(0, 1), (0, 2), (1, 0), (1, 1)],
        TetrominoShape.z => const [(0, 0), (0, 1), (1, 1), (1, 2)],
        TetrominoShape.j => const [(0, 0), (1, 0), (1, 1), (1, 2)],
        TetrominoShape.l => const [(0, 2), (1, 0), (1, 1), (1, 2)],
      };

  /// Every distinct rotation of this shape (1 for O, 2 for I/S/Z, 4 for
  /// T/J/L), each normalized so its own bounding box starts at (0, 0).
  List<List<(int, int)>> get rotations => _rotationsCache[this]!;

  static final Map<TetrominoShape, List<List<(int, int)>>> _rotationsCache = {
    for (final shape in TetrominoShape.values) shape: _computeRotations(shape._canonicalCells),
  };

  static List<List<(int, int)>> _computeRotations(List<(int, int)> canonical) {
    final rotations = <List<(int, int)>>[];
    var current = _normalize(canonical);
    for (var i = 0; i < 4; i++) {
      final alreadySeen = rotations.any((r) => _sameShape(r, current));
      if (alreadySeen) break;
      rotations.add(current);
      current = _normalize(_rotate90(current));
    }
    return rotations;
  }

  static List<(int, int)> _rotate90(List<(int, int)> cells) {
    final maxRow = cells.map((c) => c.$1).reduce(math.max);
    return cells.map((c) => (c.$2, maxRow - c.$1)).toList();
  }

  static List<(int, int)> _normalize(List<(int, int)> cells) {
    final minRow = cells.map((c) => c.$1).reduce(math.min);
    final minCol = cells.map((c) => c.$2).reduce(math.min);
    final shifted = cells.map((c) => (c.$1 - minRow, c.$2 - minCol)).toList();
    shifted.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    return shifted;
  }

  static bool _sameShape(List<(int, int)> a, List<(int, int)> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Immutable information about one successfully applied piece placement.
class TetraTowerMove {
  final TetraTowerPlayer player;
  final TetrominoShape shape;
  final int rotationIndex;
  final BoardPosition anchor;
  final List<BoardPosition> cells;
  final int layerIndex;
  final bool startedNewLayer;
  final double instabilityAdded;
  final double totalInstability;
  final TetraTowerGameStatus status;
  final TetraTowerPlayer? winner;

  const TetraTowerMove({
    required this.player,
    required this.shape,
    required this.rotationIndex,
    required this.anchor,
    required this.cells,
    required this.layerIndex,
    required this.startedNewLayer,
    required this.instabilityAdded,
    required this.totalInstability,
    required this.status,
    required this.winner,
  });

  bool get isTerminal => status != TetraTowerGameStatus.playing;
}
