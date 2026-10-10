import 'package:meta/meta.dart';

import '../models/dots_and_boxes_models.dart';

/// Pure Dart game engine for Dots and Boxes.
///
/// Rules:
/// - A grid of dots, [dotColumns] across and [dotRows] down. Players take
///   turns drawing one line between two neighbouring dots.
/// - Closing the fourth side of a box claims it -- and earns another go,
///   so one turn can run on for as long as boxes keep closing. A single
///   line can close two boxes at once, when it is the fourth side of the
///   box on either side of it.
/// - When every line has been drawn the boxes are counted and whoever
///   holds more wins; an even split is a draw.
class DotsAndBoxesGame {
  /// Dots across and down. The boxes between them are one fewer each
  /// way, so the board is [boxColumns] x [boxRows].
  static const int dotColumns = 6;
  static const int dotRows = 9;

  static int get boxColumns => dotColumns - 1;
  static int get boxRows => dotRows - 1;

  /// Every line on the board, drawn or not.
  static int get totalEdges =>
      (dotRows * boxColumns) + (boxRows * dotColumns);

  late List<List<bool>> _horizontal;
  late List<List<bool>> _vertical;
  late List<List<DotsAndBoxesPlayer?>> _owners;
  late DotsAndBoxesPlayer _currentPlayer;
  late DotsAndBoxesGameStatus _status;
  DotsAndBoxesPlayer? _winner;

  /// Every line drawn so far, in order, with who drew it. Keeping the
  /// order is what lets the board show the other player their last turn.
  final List<({DotsAndBoxesPlayer player, BoxEdge edge})> _drawnOrder = [];

  /// Board states from before each line, for Revert.
  final List<_Snapshot> _history = [];

  DotsAndBoxesGame() {
    reset();
  }

  DotsAndBoxesPlayer get currentPlayer => _currentPlayer;

  DotsAndBoxesGameStatus get status => _status;

  DotsAndBoxesPlayer? get winner => _winner;

  bool get isGameOver => _status != DotsAndBoxesGameStatus.playing;

  bool get canRevert => _history.isNotEmpty;

  /// Number of lines drawn so far in this match.
  int get moveCount => _history.length;

  int get blueScore => boxesOwnedBy(DotsAndBoxesPlayer.player1);

  int get redScore => boxesOwnedBy(DotsAndBoxesPlayer.player2);

  /// The single most recent line, so the board can pick it out in the
  /// colour of whoever drew it. Everything older is just a line.
  ///
  /// Deliberately only the last one. Closing a box earns another go, so
  /// a player on a run lays several lines in one turn; colouring all of
  /// them turns that corner of the board into a solid block and stops
  /// the lines reading as lines at all.
  BoxEdge? get lastEdge => _drawnOrder.isEmpty ? null : _drawnOrder.last.edge;

  /// Who drew [lastEdge], or `null` before the first line.
  DotsAndBoxesPlayer? get lastEdgePlayer =>
      _drawnOrder.isEmpty ? null : _drawnOrder.last.player;

  bool isDrawn(BoxEdge edge) {
    if (!_isOnBoard(edge)) return false;
    return edge.isHorizontal
        ? _horizontal[edge.row][edge.col]
        : _vertical[edge.row][edge.col];
  }

  DotsAndBoxesPlayer? boxOwner(int row, int col) {
    if (row < 0 || row >= boxRows || col < 0 || col >= boxColumns) return null;
    return _owners[row][col];
  }

  /// How many of a box's four sides have been drawn.
  ///
  /// Three is the number that matters: a box on three sides is a free
  /// one for whoever draws next, which is the whole of the tactics here.
  int sidesDrawn(int row, int col) {
    if (row < 0 || row >= boxRows || col < 0 || col >= boxColumns) return 0;

    var sides = 0;
    if (_horizontal[row][col]) sides++;
    if (_horizontal[row + 1][col]) sides++;
    if (_vertical[row][col]) sides++;
    if (_vertical[row][col + 1]) sides++;
    return sides;
  }

  int boxesOwnedBy(DotsAndBoxesPlayer player) {
    var count = 0;
    for (final row in _owners) {
      for (final owner in row) {
        if (owner == player) count++;
      }
    }
    return count;
  }

  /// Whether this line can be drawn right now.
  bool canDraw(BoxEdge edge) =>
      !isGameOver && _isOnBoard(edge) && !isDrawn(edge);

  /// Draws [edge] for [currentPlayer] and claims whatever it closes.
  ///
  /// `null` means the line was off the board, already drawn, or the game
  /// had already finished.
  DotsAndBoxesMove? tryDrawEdge(BoxEdge edge) {
    if (!canDraw(edge)) return null;

    final player = _currentPlayer;
    _history.add(_snapshot());

    if (edge.isHorizontal) {
      _horizontal[edge.row][edge.col] = true;
    } else {
      _vertical[edge.row][edge.col] = true;
    }
    _drawnOrder.add((player: player, edge: edge));

    final claimed = <BoxCell>[];
    for (final box in _boxesTouching(edge)) {
      if (_owners[box.row][box.col] == null && _isBoxClosed(box)) {
        _owners[box.row][box.col] = player;
        claimed.add(box);
      }
    }

    // Closing a box earns another go; otherwise the turn passes.
    final playsAgain = claimed.isNotEmpty;
    if (!playsAgain) _currentPlayer = player.opponent;

    if (_drawnOrder.length == totalEdges) _finish();

    return DotsAndBoxesMove(
      player: player,
      edge: edge,
      claimedBoxes: List.unmodifiable(claimed),
      playsAgain: playsAgain,
      status: _status,
      winner: _winner,
    );
  }

  /// Undoes the last line, along with any box it closed.
  bool revert() {
    if (!canRevert) return false;
    _restore(_history.removeLast());
    return true;
  }

  /// Clears the board and hands the first line to Blue.
  void reset() {
    _horizontal = List.generate(
      dotRows,
      (_) => List<bool>.filled(boxColumns, false),
    );
    _vertical = List.generate(
      boxRows,
      (_) => List<bool>.filled(dotColumns, false),
    );
    _owners = List.generate(
      boxRows,
      (_) => List<DotsAndBoxesPlayer?>.filled(boxColumns, null),
    );
    _currentPlayer = DotsAndBoxesPlayer.player1;
    _status = DotsAndBoxesGameStatus.playing;
    _winner = null;
    _drawnOrder.clear();
    _history.clear();
  }

  /// Draws a run of lines straight onto the board. Test seam: the
  /// interesting positions here -- a box about to close, a board one
  /// line from finishing -- are a long way from an empty grid, and a
  /// test that scripts eighty moves says nothing about the rule it is
  /// checking.
  ///
  /// The lines are played as real moves, so boxes close and turns pass
  /// exactly as they would in a match; [startingPlayer] is simply who
  /// goes first. History is cleared afterwards, so Revert does not reach
  /// back into the setup.
  @visibleForTesting
  void debugPlay(
    List<BoxEdge> edges, {
    DotsAndBoxesPlayer startingPlayer = DotsAndBoxesPlayer.player1,
  }) {
    _currentPlayer = startingPlayer;
    for (final edge in edges) {
      final move = tryDrawEdge(edge);
      assert(move != null, 'debugPlay was handed an illegal line: $edge');
    }
    _history.clear();
  }

  // --- internals -----------------------------------------------------------

  bool _isOnBoard(BoxEdge edge) {
    if (edge.row < 0 || edge.col < 0) return false;
    return edge.isHorizontal
        ? edge.row < dotRows && edge.col < boxColumns
        : edge.row < boxRows && edge.col < dotColumns;
  }

  /// The one or two boxes a line forms a side of.
  List<BoxCell> _boxesTouching(BoxEdge edge) {
    final boxes = <BoxCell>[];

    if (edge.isHorizontal) {
      // The box above it, and the box below it.
      if (edge.row > 0) boxes.add(BoxCell(edge.row - 1, edge.col));
      if (edge.row < boxRows) boxes.add(BoxCell(edge.row, edge.col));
    } else {
      // The box to its left, and the box to its right.
      if (edge.col > 0) boxes.add(BoxCell(edge.row, edge.col - 1));
      if (edge.col < boxColumns) boxes.add(BoxCell(edge.row, edge.col));
    }

    return boxes;
  }

  bool _isBoxClosed(BoxCell box) =>
      _horizontal[box.row][box.col] &&
      _horizontal[box.row + 1][box.col] &&
      _vertical[box.row][box.col] &&
      _vertical[box.row][box.col + 1];

  /// Every line is drawn, so every box has an owner: count them.
  void _finish() {
    final blue = blueScore;
    final red = redScore;

    if (blue == red) {
      _status = DotsAndBoxesGameStatus.draw;
      _winner = null;
      return;
    }
    _status = DotsAndBoxesGameStatus.won;
    _winner = blue > red
        ? DotsAndBoxesPlayer.player1
        : DotsAndBoxesPlayer.player2;
  }

  _Snapshot _snapshot() => _Snapshot(
        horizontal: [for (final row in _horizontal) List<bool>.of(row)],
        vertical: [for (final row in _vertical) List<bool>.of(row)],
        owners: [
          for (final row in _owners) List<DotsAndBoxesPlayer?>.of(row),
        ],
        drawnOrder: List.of(_drawnOrder),
        currentPlayer: _currentPlayer,
        status: _status,
        winner: _winner,
      );

  void _restore(_Snapshot snapshot) {
    _horizontal = [for (final row in snapshot.horizontal) List<bool>.of(row)];
    _vertical = [for (final row in snapshot.vertical) List<bool>.of(row)];
    _owners = [
      for (final row in snapshot.owners) List<DotsAndBoxesPlayer?>.of(row),
    ];
    _drawnOrder
      ..clear()
      ..addAll(snapshot.drawnOrder);
    _currentPlayer = snapshot.currentPlayer;
    _status = snapshot.status;
    _winner = snapshot.winner;
  }
}

/// Everything needed to put the board back the way it was before a line.
class _Snapshot {
  final List<List<bool>> horizontal;
  final List<List<bool>> vertical;
  final List<List<DotsAndBoxesPlayer?>> owners;
  final List<({DotsAndBoxesPlayer player, BoxEdge edge})> drawnOrder;
  final DotsAndBoxesPlayer currentPlayer;
  final DotsAndBoxesGameStatus status;
  final DotsAndBoxesPlayer? winner;

  const _Snapshot({
    required this.horizontal,
    required this.vertical,
    required this.owners,
    required this.drawnOrder,
    required this.currentPlayer,
    required this.status,
    required this.winner,
  });
}
