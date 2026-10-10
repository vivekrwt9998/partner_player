import 'package:meta/meta.dart';

import '../models/hex_models.dart';

/// Pure Dart game engine for Hex.
///
/// Rules:
/// - An 11x11 rhombus of hexagons. Blue plays first.
/// - A turn is one stone on any empty cell. Stones are never moved,
///   taken or turned over, so the board only ever fills up.
/// - Every cell touches up to six others, and a chain may run through
///   any of them.
/// - Blue wins by joining the left column to the right column with an
///   unbroken chain of its own stones; Red wins by joining the top row
///   to the bottom row. The corner cells count towards both sides they
///   sit on.
/// - There is no pass and no draw. A player always has somewhere to put
///   a stone, and a full Hex board always holds exactly one winning
///   chain -- which is why [HexGameStatus] has no `draw`.
class HexGame {
  /// 11 columns and 11 rows, so 121 cells.
  static const int size = 11;

  /// The six neighbours of a cell, as (row, col) offsets.
  ///
  /// The order matters beyond adjacency: index `k` is also hexagon edge
  /// `k` on screen, the edge spanning the flat-top hexagon corners at
  /// `k * 60` and `(k + 1) * 60` degrees. The board painter leans on
  /// that to colour the four sides -- a cell with no neighbour across
  /// edge `k` is a cell sitting on the boundary there.
  static const List<(int, int)> neighbourOffsets = [
    (0, 1), // edge 0 -- right
    (1, 0), // edge 1 -- down
    (1, -1), // edge 2 -- down-left
    (0, -1), // edge 3 -- left
    (-1, 0), // edge 4 -- up
    (-1, 1), // edge 5 -- up-right
  ];

  late List<List<HexPlayer?>> _board;
  late HexPlayer _currentPlayer;
  late HexGameStatus _status;
  HexPlayer? _winner;
  List<HexCell> _winningPath = const [];

  /// Every stone played so far, newest last. One move writes one cell
  /// and nothing else, so the move itself is all Revert needs; see
  /// [revert].
  final List<HexMove> _history = [];

  HexGame() {
    reset();
  }

  /// The whole board. Row 0 is the top row.
  List<List<HexPlayer?>> get board => _board;

  HexPlayer get currentPlayer => _currentPlayer;

  HexGameStatus get status => _status;

  HexPlayer? get winner => _winner;

  bool get isGameOver => _status != HexGameStatus.playing;

  /// The chain that won, in order from the first side the winner joined
  /// to the second. Empty while the game is still going.
  List<HexCell> get winningPath => List.unmodifiable(_winningPath);

  bool get canRevert => _history.isNotEmpty;

  /// Number of stones played so far in this match.
  int get moveCount => _history.length;

  HexPlayer? stoneAt(int row, int col) {
    if (!_isOnBoard(row, col)) return null;
    return _board[row][col];
  }

  /// Whether [currentPlayer] may lay a stone here right now.
  ///
  /// Hex has no notion of a move that achieves nothing, so unlike
  /// Reversi every empty cell is playable and the screen needs no
  /// legal-move markers.
  bool canPlace(int row, int col) =>
      !isGameOver && _isOnBoard(row, col) && _board[row][col] == null;

  /// Lays a stone for [currentPlayer] at [row]/[col].
  ///
  /// `null` means the cell was off the board, already taken, or the game
  /// had already finished.
  HexMove? tryPlace(int row, int col) {
    if (!canPlace(row, col)) return null;

    final player = _currentPlayer;
    _board[row][col] = player;

    // Only the player who just moved can have completed a chain, so
    // there is one connection check per turn rather than two.
    final path = _connectionPath(player);
    if (path != null) {
      _status = HexGameStatus.won;
      _winner = player;
      _winningPath = path;
    } else {
      _currentPlayer = player.opponent;
    }

    final move = HexMove(
      player: player,
      cell: HexCell(row, col),
      status: _status,
      winner: _winner,
      winningPath: _winningPath,
    );
    _history.add(move);
    return move;
  }

  /// Takes back the last stone.
  ///
  /// Reversi keeps a snapshot of all 64 squares because one move turns
  /// over an arbitrary set of discs. A Hex move writes exactly one cell
  /// and touches nothing else, so undoing it is that single write in
  /// reverse; copying 121 cells to lift one stone would be waste
  /// dressed up as symmetry. The rest of the state is implied: whoever
  /// played the stone was to move, and the game was necessarily still
  /// running when they did.
  bool revert() {
    if (_history.isEmpty) return false;

    final move = _history.removeLast();
    _board[move.cell.row][move.cell.col] = null;
    _currentPlayer = move.player;
    _status = HexGameStatus.playing;
    _winner = null;
    _winningPath = const [];
    return true;
  }

  void reset() {
    _board = List.generate(
      size,
      (_) => List<HexPlayer?>.filled(size, null),
    );
    _currentPlayer = HexPlayer.player1;
    _status = HexGameStatus.playing;
    _winner = null;
    _winningPath = const [];
    _history.clear();
  }

  /// Drops a whole board in, for tests.
  ///
  /// An interesting Hex position is ten or more scripted moves deep, so
  /// building one by replaying [tryPlace] is unreadable. Same seam as
  /// `ColorWarGame.debugConfigure` and `ReversiGame.debugConfigure`.
  @visibleForTesting
  void debugConfigure({
    required List<List<HexPlayer?>> cells,
    HexPlayer currentPlayer = HexPlayer.player1,
  }) {
    assert(cells.length == size, 'a Hex board has $size rows');
    assert(
      cells.every((row) => row.length == size),
      'a Hex board has $size columns',
    );

    _board = [for (final row in cells) List<HexPlayer?>.of(row)];
    _currentPlayer = currentPlayer;
    _status = HexGameStatus.playing;
    _winner = null;
    _winningPath = const [];
    _history.clear();

    // A hand-built board may already hold a finished chain. Try the
    // player who would have moved last first: in a real game they are
    // the only one who could just have won.
    for (final player in [currentPlayer.opponent, currentPlayer]) {
      final path = _connectionPath(player);
      if (path == null) continue;
      _status = HexGameStatus.won;
      _winner = player;
      _winningPath = path;
      break;
    }
  }

  /// Walks [player] stones out from their first side looking for their
  /// second, and returns the chain that got there.
  ///
  /// A plain breadth-first search carrying parent links. Returning the
  /// traced path rather than just `true` is what lets the screen light
  /// up one clean chain instead of the whole connected blob, and
  /// because it is breadth-first that chain is also the shortest one
  /// available.
  List<HexCell>? _connectionPath(HexPlayer player) {
    final isBlue = player == HexPlayer.player1;

    final parents = <HexCell, HexCell?>{};
    final queue = <HexCell>[];

    // Seed with every stone already sitting on the starting side:
    // Blue starts from the left column, Red from the top row.
    for (var i = 0; i < size; i++) {
      final cell = isBlue ? HexCell(i, 0) : HexCell(0, i);
      if (_board[cell.row][cell.col] != player) continue;
      parents[cell] = null;
      queue.add(cell);
    }

    for (var head = 0; head < queue.length; head++) {
      final cell = queue[head];
      final reachedFarSide =
          isBlue ? cell.col == size - 1 : cell.row == size - 1;
      if (reachedFarSide) return _pathTo(cell, parents);

      for (final (dr, dc) in neighbourOffsets) {
        final row = cell.row + dr;
        final col = cell.col + dc;
        if (!_isOnBoard(row, col)) continue;
        if (_board[row][col] != player) continue;

        final next = HexCell(row, col);
        if (parents.containsKey(next)) continue;
        parents[next] = cell;
        queue.add(next);
      }
    }

    return null;
  }

  /// Follows the parent links back from [end] and hands the chain over
  /// the right way round: starting side first.
  List<HexCell> _pathTo(HexCell end, Map<HexCell, HexCell?> parents) {
    final path = <HexCell>[];
    HexCell? cell = end;
    while (cell != null) {
      path.add(cell);
      cell = parents[cell];
    }
    return List.unmodifiable(path.reversed);
  }

  bool _isOnBoard(int row, int col) =>
      row >= 0 && row < size && col >= 0 && col < size;
}
