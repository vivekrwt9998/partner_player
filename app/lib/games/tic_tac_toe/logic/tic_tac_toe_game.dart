import '../models/tic_tac_toe_models.dart';

/// Pure Dart game engine for Tic Tac Toe.
///
/// Standard rules:
/// - 3x3 grid
/// - 2 players take turns placing their mark in any empty cell
/// - Win condition: 3 consecutive marks (horizontal, vertical, or diagonal)
/// - Draw condition: Board full with no 3-in-a-row
/// - Revert capability: undo moves and restore previous state
class TicTacToeGame {
  static const int rows = 3;
  static const int cols = 3;
  static const int connectCount = 3;

  late List<List<TicTacToePlayer?>> _board;
  late TicTacToePlayer _currentPlayer;
  late TicTacToeGameStatus _status;
  TicTacToePlayer? _winner;
  List<BoardPosition> _winningPositions = const [];
  final List<({int row, int col, TicTacToePlayer player})> _moveHistory = [];

  TicTacToeGame() {
    reset();
  }

  /// Current 3x3 board grid. Row 0 is top, Row 2 is bottom.
  List<List<TicTacToePlayer?>> get board => _board;

  /// Player whose turn it currently is.
  TicTacToePlayer get currentPlayer => _currentPlayer;

  /// Current game lifecycle status.
  TicTacToeGameStatus get status => _status;

  /// Winner of the game, or `null` if game is ongoing or drawn.
  TicTacToePlayer? get winner => _winner;

  /// Winning cell positions ordered along the line, if the game was won.
  List<BoardPosition> get winningPositions => List.unmodifiable(_winningPositions);

  /// Whether the game is finished (won or draw).
  bool get isGameOver => _status != TicTacToeGameStatus.playing;

  /// Whether a move can currently be reverted/undone.
  bool get canRevert => _moveHistory.isNotEmpty;

  /// Number of moves made so far in this match.
  int get moveCount => _moveHistory.length;

  /// Get the mark at [row] and [col].
  TicTacToePlayer? getCell(int row, int col) {
    if (row < 0 || row >= rows || col < 0 || col >= cols) return null;
    return _board[row][col];
  }

  /// Whether a mark can currently be placed at [row]/[col].
  bool canPlace(int row, int col) {
    if (isGameOver) return false;
    if (row < 0 || row >= rows || col < 0 || col >= cols) return false;
    return _board[row][col] == null;
  }

  /// Places a mark for [currentPlayer] at [row]/[col] and returns its
  /// resolved outcome.
  ///
  /// `null` means the cell was invalid, occupied, or the game had already
  /// ended.
  TicTacToeMove? tryPlaceMark(int row, int col) {
    if (!canPlace(row, col)) return null;

    final movingPlayer = _currentPlayer;
    _board[row][col] = movingPlayer;
    _moveHistory.add((row: row, col: col, player: movingPlayer));

    final winningLine = _checkWin(row, col, movingPlayer);
    if (winningLine != null) {
      _status = TicTacToeGameStatus.won;
      _winner = movingPlayer;
      _winningPositions = winningLine;
      return TicTacToeMove(
        player: movingPlayer,
        row: row,
        col: col,
        status: _status,
        winner: _winner,
      );
    }

    if (_isBoardFull()) {
      _status = TicTacToeGameStatus.draw;
      return TicTacToeMove(
        player: movingPlayer,
        row: row,
        col: col,
        status: _status,
        winner: _winner,
      );
    }

    _currentPlayer = _currentPlayer.opponent;
    return TicTacToeMove(
      player: movingPlayer,
      row: row,
      col: col,
      status: _status,
      winner: _winner,
    );
  }

  /// Reverts (undoes) the last valid move.
  ///
  /// Restores board cell, active player, and clears any win/draw terminal state.
  /// Returns `true` if a move was reverted, `false` if history was empty.
  bool revert() {
    if (_moveHistory.isEmpty) return false;

    final lastMove = _moveHistory.removeLast();
    _board[lastMove.row][lastMove.col] = null;
    _currentPlayer = lastMove.player;
    _status = TicTacToeGameStatus.playing;
    _winner = null;
    _winningPositions = const [];

    return true;
  }

  /// Resets the game to initial state with Player 1.
  void reset() {
    _board = List.generate(
      rows,
      (_) => List<TicTacToePlayer?>.filled(cols, null),
    );
    _currentPlayer = TicTacToePlayer.player1;
    _status = TicTacToeGameStatus.playing;
    _winner = null;
    _winningPositions = const [];
    _moveHistory.clear();
  }

  bool _isBoardFull() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (_board[r][c] == null) return false;
      }
    }
    return true;
  }

  /// Checks for 3 consecutive marks in all 4 directions from [row], [col].
  /// Returns sorted positions along the line from one end to the other.
  List<BoardPosition>? _checkWin(int row, int col, TicTacToePlayer player) {
    const directions = [
      (dr: 0, dc: 1), // Horizontal (left-right)
      (dr: 1, dc: 0), // Vertical (top-bottom)
      (dr: 1, dc: 1), // Diagonal Down-Right (\)
      (dr: -1, dc: 1), // Diagonal Up-Right (/)
    ];

    for (final dir in directions) {
      final line = <BoardPosition>[BoardPosition(row, col)];

      // Positive direction
      int r = row + dir.dr;
      int c = col + dir.dc;
      while (_isValidCell(r, c) && _board[r][c] == player) {
        line.add(BoardPosition(r, c));
        r += dir.dr;
        c += dir.dc;
      }

      // Negative direction
      r = row - dir.dr;
      c = col - dir.dc;
      while (_isValidCell(r, c) && _board[r][c] == player) {
        line.add(BoardPosition(r, c));
        r -= dir.dr;
        c -= dir.dc;
      }

      if (line.length >= connectCount) {
        // Sort along the primary axis so positions form an ordered continuous line.
        line.sort((a, b) {
          if (a.row != b.row) return a.row.compareTo(b.row);
          return a.col.compareTo(b.col);
        });
        return line;
      }
    }

    return null;
  }

  bool _isValidCell(int row, int col) {
    return row >= 0 && row < rows && col >= 0 && col < cols;
  }
}
