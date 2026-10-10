import 'package:meta/meta.dart';

import '../models/reversi_models.dart';

/// Pure Dart game engine for Reversi (Othello).
///
/// Rules:
/// - An 8x8 board starting with four discs in the middle, two a side.
///   Blue plays first.
/// - You may only play on an empty square that outflanks the opponent:
///   somewhere along one of the eight directions there has to be an
///   unbroken run of their discs ending in one of yours. Every disc in
///   every such run turns your colour.
/// - A square that would turn nothing over is not a legal move.
/// - If you have no legal move your turn is skipped and the opponent goes
///   again. If neither side can move the game is over, and whoever holds
///   more discs wins -- level is a draw.
class ReversiGame {
  /// The board is 8x8, so it reads the same however the device is held.
  static const int size = 8;

  /// The eight directions a run can be outflanked along.
  static const List<(int, int)> _directions = [
    (-1, -1), (-1, 0), (-1, 1),
    (0, -1), (0, 1),
    (1, -1), (1, 0), (1, 1),
  ];

  late List<List<ReversiPlayer?>> _board;
  late ReversiPlayer _currentPlayer;
  late ReversiGameStatus _status;
  ReversiPlayer? _winner;

  /// Legal moves for [_currentPlayer], each mapped to the discs it would
  /// turn over. Computed once per board state rather than per query: the
  /// screen marks *every* playable square, and [tryPlace] validating
  /// against this same map is what keeps the hints and the rules from
  /// drifting apart.
  Map<ReversiPosition, List<ReversiPosition>> _legalMoves = const {};

  /// Board states from before each move, for Revert. One move turns over
  /// an arbitrary set of discs, so an inverse-move record buys nothing
  /// over a copy of 64 cells.
  final List<_Snapshot> _history = [];

  ReversiGame() {
    reset();
  }

  /// The whole board. Row 0 is the top row.
  List<List<ReversiPlayer?>> get board => _board;

  ReversiPlayer get currentPlayer => _currentPlayer;

  ReversiGameStatus get status => _status;

  ReversiPlayer? get winner => _winner;

  bool get isGameOver => _status != ReversiGameStatus.playing;

  /// Every square [currentPlayer] may play, with the discs each would
  /// turn over.
  Map<ReversiPosition, List<ReversiPosition>> get legalMoves =>
      Map.unmodifiable(_legalMoves);

  /// Just the playable squares, for the screen's markers.
  Iterable<ReversiPosition> get legalSquares => _legalMoves.keys;

  bool get canRevert => _history.isNotEmpty;

  /// Number of discs played so far in this match.
  int get moveCount => _history.length;

  int get blueScore => scoreOf(ReversiPlayer.player1);

  int get redScore => scoreOf(ReversiPlayer.player2);

  ReversiPlayer? discAt(int row, int col) {
    if (!_isOnBoard(row, col)) return null;
    return _board[row][col];
  }

  /// How many discs [player] holds. This is the scoreboard *and* the win
  /// condition.
  int scoreOf(ReversiPlayer player) {
    var count = 0;
    for (final row in _board) {
      for (final disc in row) {
        if (disc == player) count++;
      }
    }
    return count;
  }

  /// Whether [currentPlayer] may lay a disc here right now.
  bool canPlace(int row, int col) =>
      !isGameOver && _legalMoves.containsKey(ReversiPosition(row, col));

  /// Lays a disc for [currentPlayer] at [row]/[col] and turns over
  /// everything it outflanks.
  ///
  /// `null` means the square was off the board, taken, would turn nothing
  /// over, or the game had already finished.
  ReversiMove? tryPlace(int row, int col) {
    final position = ReversiPosition(row, col);
    final flipped = _legalMoves[position];
    if (isGameOver || flipped == null) return null;

    final player = _currentPlayer;
    _history.add(_snapshot());

    _board[row][col] = player;
    for (final disc in flipped) {
      _board[disc.row][disc.col] = player;
    }

    // Hand over the turn; if the opponent is stuck it comes straight
    // back, and if that leaves nobody able to move the game is over.
    ReversiPlayer? passedPlayer;
    _currentPlayer = player.opponent;
    _refreshLegalMoves();
    if (_legalMoves.isEmpty) {
      passedPlayer = _currentPlayer;
      _currentPlayer = player;
      _refreshLegalMoves();
      if (_legalMoves.isEmpty) {
        passedPlayer = null;
        _finish();
      }
    }

    return ReversiMove(
      player: player,
      position: position,
      flipped: List.unmodifiable(flipped),
      passedPlayer: passedPlayer,
      status: _status,
      winner: _winner,
    );
  }

  /// Undoes the last disc, everything it turned over, and any pass or
  /// game-over that followed it.
  bool revert() {
    if (!canRevert) return false;
    _restore(_history.removeLast());
    return true;
  }

  /// Resets to the opening position with Blue to move.
  void reset() {
    _board = List.generate(
      size,
      (_) => List<ReversiPlayer?>.filled(size, null),
    );
    // The standard opening cross: each colour on one diagonal.
    _board[3][3] = ReversiPlayer.player2;
    _board[4][4] = ReversiPlayer.player2;
    _board[3][4] = ReversiPlayer.player1;
    _board[4][3] = ReversiPlayer.player1;

    _currentPlayer = ReversiPlayer.player1;
    _status = ReversiGameStatus.playing;
    _winner = null;
    _history.clear();
    _refreshLegalMoves();
  }

  /// Replaces the board wholesale. Test seam: the interesting positions
  /// here -- a player with no move, a full board, an even split -- would
  /// each take a long scripted game to reach, which buries what the test
  /// is actually about.
  ///
  /// [cells] must be [size] x [size].
  @visibleForTesting
  void debugConfigure({
    required List<List<ReversiPlayer?>> cells,
    ReversiPlayer currentPlayer = ReversiPlayer.player1,
  }) {
    assert(cells.length == size, 'expected $size rows');
    assert(cells.every((row) => row.length == size), 'expected $size columns');

    _board = [for (final row in cells) List<ReversiPlayer?>.of(row)];
    _currentPlayer = currentPlayer;
    _status = ReversiGameStatus.playing;
    _winner = null;
    _history.clear();
    _refreshLegalMoves();

    // A configured board can already be finished for both sides.
    if (_legalMoves.isEmpty) {
      _currentPlayer = currentPlayer.opponent;
      _refreshLegalMoves();
      if (_legalMoves.isEmpty) {
        _currentPlayer = currentPlayer;
        _finish();
      }
    }
  }

  // --- internals -----------------------------------------------------------

  bool _isOnBoard(int row, int col) =>
      row >= 0 && row < size && col >= 0 && col < size;

  void _refreshLegalMoves() {
    if (isGameOver) {
      _legalMoves = const {};
      return;
    }

    final moves = <ReversiPosition, List<ReversiPosition>>{};
    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        if (_board[row][col] != null) continue;
        final flipped = _flipsFrom(row, col, _currentPlayer);
        if (flipped.isNotEmpty) {
          moves[ReversiPosition(row, col)] = flipped;
        }
      }
    }
    _legalMoves = moves;
  }

  /// Every disc playing [player] at [row]/[col] would turn over: walk each
  /// direction over an unbroken run of the opponent's discs and keep the
  /// run only if one of [player]'s own discs closes it off.
  List<ReversiPosition> _flipsFrom(int row, int col, ReversiPlayer player) {
    final flipped = <ReversiPosition>[];

    for (final (rowStep, colStep) in _directions) {
      final run = <ReversiPosition>[];
      var r = row + rowStep;
      var c = col + colStep;

      while (_isOnBoard(r, c) && _board[r][c] == player.opponent) {
        run.add(ReversiPosition(r, c));
        r += rowStep;
        c += colStep;
      }

      if (run.isNotEmpty && _isOnBoard(r, c) && _board[r][c] == player) {
        flipped.addAll(run);
      }
    }

    return flipped;
  }

  /// Nobody can move: count the board.
  void _finish() {
    _legalMoves = const {};
    final blue = scoreOf(ReversiPlayer.player1);
    final red = scoreOf(ReversiPlayer.player2);

    if (blue == red) {
      _status = ReversiGameStatus.draw;
      _winner = null;
      return;
    }
    _status = ReversiGameStatus.won;
    _winner = blue > red ? ReversiPlayer.player1 : ReversiPlayer.player2;
  }

  _Snapshot _snapshot() => _Snapshot(
        board: [for (final row in _board) List<ReversiPlayer?>.of(row)],
        currentPlayer: _currentPlayer,
        status: _status,
        winner: _winner,
      );

  void _restore(_Snapshot snapshot) {
    _board = [for (final row in snapshot.board) List<ReversiPlayer?>.of(row)];
    _currentPlayer = snapshot.currentPlayer;
    _status = snapshot.status;
    _winner = snapshot.winner;
    _refreshLegalMoves();
  }
}

/// Everything needed to put the board back the way it was before a move.
class _Snapshot {
  final List<List<ReversiPlayer?>> board;
  final ReversiPlayer currentPlayer;
  final ReversiGameStatus status;
  final ReversiPlayer? winner;

  const _Snapshot({
    required this.board,
    required this.currentPlayer,
    required this.status,
    required this.winner,
  });
}
