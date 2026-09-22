import 'dart:math';

import '../models/tetra_tower_models.dart';

/// One recorded placement, kept only so [TetraTowerGame.revert] can undo it.
typedef _MoveRecord = ({
  TetraTowerPlayer player,
  TetrominoShape shape,
  List<BoardPosition> cells,
  int layerIndex,
  bool startedNewLayer,
  double previousInstability,
  TetraTowerGameStatus previousStatus,
  TetraTowerPlayer? previousWinner,
});

/// Pure Dart game engine for Tetra Tower: a Jenga-style tower built from
/// Tetris-shaped (tetromino) pieces instead of physically simulated blocks.
///
/// - The tower is a stack of layers, each a [gridSize] x [gridSize] grid.
/// - Each turn the current player is handed a random tetromino (they may
///   rotate it, see [rotatePiece]) and places it anywhere it fits on the
///   *current* (topmost, still-being-filled) layer.
/// - Placing over empty space in the layer below ("overhang") makes the
///   tower less stable, and so does sheer height -- every placement adds to
///   a running instability total (see [totalInstability]). There's no real
///   physics simulation here; that instability crossing [collapseThreshold]
///   *is* the tower falling (AGENTS.md §54, Do Not Over-Engineer).
/// - Once the next piece can't fit anywhere on the current layer, a new
///   empty layer starts on top of it.
/// - Whoever places the piece that tips the tower over loses.
class TetraTowerGame {
  static const int gridSize = 4;

  /// Instability added per cell of a placement that has nothing solid
  /// beneath it in the layer below.
  static const double overhangPenalty = 12;

  /// Instability added per placement just for being on a given layer --
  /// taller is inherently shakier, even when perfectly supported.
  static const double heightPenaltyPerLayer = 2;

  /// Total instability at which the tower falls.
  static const double collapseThreshold = 100;

  final Random _random;

  late List<List<List<TetraTowerPlayer?>>> _layers;
  late TetraTowerPlayer _currentPlayer;
  late TetraTowerGameStatus _status;
  TetraTowerPlayer? _winner;
  late double _totalInstability;
  late int _currentLayerIndex;
  late TetrominoShape _currentShape;
  late int _currentRotationIndex;
  final List<_MoveRecord> _moveHistory = [];

  TetraTowerGame({Random? random}) : _random = random ?? Random() {
    reset();
  }

  /// All layers built so far, bottom (index 0) to top. Each is a
  /// [gridSize] x [gridSize] grid of the player who placed that cell, or
  /// `null` if still empty.
  List<List<List<TetraTowerPlayer?>>> get layers => _layers;

  /// The layer currently being filled (the top of the tower).
  int get currentLayerIndex => _currentLayerIndex;

  /// Player whose turn it currently is.
  TetraTowerPlayer get currentPlayer => _currentPlayer;

  /// Current game lifecycle status.
  TetraTowerGameStatus get status => _status;

  /// Winner of the game (the player who *didn't* knock the tower over), or
  /// `null` if still playing.
  TetraTowerPlayer? get winner => _winner;

  /// How close the tower is to falling; collapses at [collapseThreshold].
  double get totalInstability => _totalInstability;

  /// The shape the current player must place this turn.
  TetrominoShape get currentShape => _currentShape;

  /// Which of [currentShape]'s rotations is currently selected.
  int get currentRotationIndex => _currentRotationIndex;

  /// The current piece's occupied cells, relative to its own bounding box
  /// (not yet positioned on the grid -- see [legalAnchorsForCurrentPiece]
  /// and [tryPlacePiece] for that).
  List<(int, int)> get currentPieceCells =>
      _currentShape.rotations[_currentRotationIndex];

  bool get isGameOver => _status != TetraTowerGameStatus.playing;

  bool get canRevert => _moveHistory.isNotEmpty;

  int get moveCount => _moveHistory.length;

  /// The piece owner at [row]/[col] on [layerIndex], or `null` if empty or
  /// out of bounds.
  TetraTowerPlayer? getCell(int layerIndex, int row, int col) {
    if (layerIndex < 0 || layerIndex >= _layers.length) return null;
    if (!_inBounds(row, col)) return null;
    return _layers[layerIndex][row][col];
  }

  /// Cycles the current piece to its next rotation. Doesn't consume the
  /// turn -- a player can rotate as many times as they like before placing.
  void rotatePiece() {
    if (isGameOver) return;
    final rotationCount = _currentShape.rotations.length;
    _currentRotationIndex = (_currentRotationIndex + 1) % rotationCount;
  }

  /// Whether the current piece (in its current rotation) fits at [anchorRow]
  /// / [anchorCol] on the current layer: every cell in bounds and empty.
  bool canPlaceAt(int anchorRow, int anchorCol) {
    if (isGameOver) return false;
    return _fitsAt(currentPieceCells, _currentLayerIndex, anchorRow, anchorCol);
  }

  /// Every anchor position where [canPlaceAt] holds for the current piece,
  /// for the UI to highlight.
  List<BoardPosition> legalAnchorsForCurrentPiece() {
    final anchors = <BoardPosition>[];
    for (var row = 0; row < gridSize; row++) {
      for (var col = 0; col < gridSize; col++) {
        if (canPlaceAt(row, col)) anchors.add(BoardPosition(row, col));
      }
    }
    return anchors;
  }

  /// Places the current piece with its bounding-box corner at
  /// [anchorRow]/[anchorCol]. Returns `null` if that position isn't
  /// currently legal (see [canPlaceAt]).
  TetraTowerMove? tryPlacePiece(int anchorRow, int anchorCol) {
    if (!canPlaceAt(anchorRow, anchorCol)) return null;

    final movingPlayer = _currentPlayer;
    final shape = _currentShape;
    final rotationIndex = _currentRotationIndex;
    final layerIndex = _currentLayerIndex;
    final cells = currentPieceCells
        .map((c) => BoardPosition(c.$1 + anchorRow, c.$2 + anchorCol))
        .toList();

    for (final cell in cells) {
      _layers[layerIndex][cell.row][cell.col] = movingPlayer;
    }

    final supportedCells = layerIndex == 0
        ? cells.length
        : cells.where((c) => _layers[layerIndex - 1][c.row][c.col] != null).length;
    final overhangCells = cells.length - supportedCells;
    final instabilityAdded =
        (overhangCells * overhangPenalty) + (heightPenaltyPerLayer * layerIndex);
    final previousInstability = _totalInstability;
    _totalInstability += instabilityAdded;

    final previousStatus = _status;
    final previousWinner = _winner;
    var startedNewLayer = false;

    if (_totalInstability >= collapseThreshold) {
      _status = TetraTowerGameStatus.collapsed;
      _winner = movingPlayer.opponent;
    } else {
      _currentPlayer = movingPlayer.opponent;
      _pickRandomPiece();
      if (!_currentPieceFitsSomewhereOnLayer(layerIndex)) {
        _layers.add(_emptyLayer());
        _currentLayerIndex++;
        startedNewLayer = true;
      }
    }

    _moveHistory.add((
      player: movingPlayer,
      shape: shape,
      cells: cells,
      layerIndex: layerIndex,
      startedNewLayer: startedNewLayer,
      previousInstability: previousInstability,
      previousStatus: previousStatus,
      previousWinner: previousWinner,
    ));

    return TetraTowerMove(
      player: movingPlayer,
      shape: shape,
      rotationIndex: rotationIndex,
      anchor: BoardPosition(anchorRow, anchorCol),
      cells: cells,
      layerIndex: layerIndex,
      startedNewLayer: startedNewLayer,
      instabilityAdded: instabilityAdded,
      totalInstability: _totalInstability,
      status: _status,
      winner: _winner,
    );
  }

  /// Reverts (undoes) the last placement, restoring the layer, whoever's
  /// turn it was (with the same piece up for grabs again), instability, and
  /// terminal state. Removes the layer above too, if that placement was
  /// what started it.
  bool revert() {
    if (_moveHistory.isEmpty) return false;
    final record = _moveHistory.removeLast();

    for (final cell in record.cells) {
      _layers[record.layerIndex][cell.row][cell.col] = null;
    }
    if (record.startedNewLayer) {
      _layers.removeLast();
    }

    _currentLayerIndex = record.layerIndex;
    _currentPlayer = record.player;
    _currentShape = record.shape;
    _currentRotationIndex = 0;
    _totalInstability = record.previousInstability;
    _status = record.previousStatus;
    _winner = record.previousWinner;

    return true;
  }

  /// Resets the game to an empty single-layer tower with Player 1.
  void reset() {
    _layers = [_emptyLayer()];
    _currentPlayer = TetraTowerPlayer.player1;
    _status = TetraTowerGameStatus.playing;
    _winner = null;
    _totalInstability = 0;
    _currentLayerIndex = 0;
    _moveHistory.clear();
    _pickRandomPiece();
  }

  List<List<TetraTowerPlayer?>> _emptyLayer() {
    return List.generate(gridSize, (_) => List<TetraTowerPlayer?>.filled(gridSize, null));
  }

  void _pickRandomPiece() {
    _currentShape = TetrominoShape.values[_random.nextInt(TetrominoShape.values.length)];
    _currentRotationIndex = 0;
  }

  bool _inBounds(int row, int col) => row >= 0 && row < gridSize && col >= 0 && col < gridSize;

  bool _fitsAt(List<(int, int)> pieceCells, int layerIndex, int anchorRow, int anchorCol) {
    for (final cell in pieceCells) {
      final row = cell.$1 + anchorRow;
      final col = cell.$2 + anchorCol;
      if (!_inBounds(row, col)) return false;
      if (_layers[layerIndex][row][col] != null) return false;
    }
    return true;
  }

  /// Whether [_currentShape], in any of its rotations, fits anywhere on
  /// [layerIndex] as it currently stands.
  bool _currentPieceFitsSomewhereOnLayer(int layerIndex) {
    for (final rotation in _currentShape.rotations) {
      for (var row = 0; row < gridSize; row++) {
        for (var col = 0; col < gridSize; col++) {
          if (_fitsAt(rotation, layerIndex, row, col)) return true;
        }
      }
    }
    return false;
  }
}
