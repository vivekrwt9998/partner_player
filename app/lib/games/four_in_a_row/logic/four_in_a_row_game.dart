import '../models/four_in_a_row_models.dart';

/// Pure Dart game engine for Four in a Row.
///
/// Standard Connect Four rules:
/// - 6 rows x 7 columns
/// - 2 players take turns dropping discs
/// - Win condition: 4 consecutive discs (horizontal, vertical, or diagonal)
/// - Draw condition: Board full with no 4-in-a-row
/// - Revert capability: undo moves and restore previous state
class FourInARowGame {
  static const int rows = 6;
  static const int cols = 7;
  static const int connectCount = 4;

  late List<List<FourInARowPlayer?>> _board;
  late FourInARowPlayer _currentPlayer;
  late FourInARowGameStatus _status;
  FourInARowPlayer? _winner;
  List<BoardPosition> _winningPositions = const [];
  final List<({int row, int col, FourInARowPlayer player})> _moveHistory = [];

  FourInARowGame() {
    reset();
  }

  /// Current 6x7 board grid. Row 0 is top, Row 5 is bottom.
  List<List<FourInARowPlayer?>> get board => _board;

  /// Player whose turn it currently is.
  FourInARowPlayer get currentPlayer => _currentPlayer;

  /// Current game lifecycle status.
  FourInARowGameStatus get status => _status;

  /// Winner of the game, or `null` if game is ongoing or drawn.
  FourInARowPlayer? get winner => _winner;

  /// Winning cell positions ordered along the line, if the game was won.
  List<BoardPosition> get winningPositions => List.unmodifiable(_winningPositions);

  /// Whether the game is finished (won or draw).
  bool get isGameOver => _status != FourInARowGameStatus.playing;

  /// Whether a move can currently be reverted/undone.
  bool get canRevert => _moveHistory.isNotEmpty;

  /// Number of moves made so far in this match.
  int get moveCount => _moveHistory.length;

  /// Get the piece at [row] and [col].
  FourInARowPlayer? getCell(int row, int col) {
    if (row < 0 || row >= rows || col < 0 || col >= cols) return null;
    return _board[row][col];
  }

  /// Whether a column is full (top row is occupied).
  bool isColumnFull(int col) {
    if (col < 0 || col >= cols) return true;
    return _board[0][col] != null;
  }

  /// Whether a disc can currently be dropped in [col].
  bool canDrop(int col) {
    if (isGameOver) return false;
    return !isColumnFull(col);
  }

  /// Applies a disc drop for [currentPlayer] and returns its resolved outcome.
  ///
  /// `null` means the column was invalid, full, or the game had already ended.
  /// The returned row is the authoritative landing row for this engine move.
  FourInARowMove? tryDropDisc(int col) {
    if (!canDrop(col)) return null;

    // Find the lowest empty cell in this column
    int targetRow = -1;
    for (int r = rows - 1; r >= 0; r--) {
      if (_board[r][col] == null) {
        targetRow = r;
        break;
      }
    }

    if (targetRow == -1) return null;

    // Place the piece & record history
    final movingPlayer = _currentPlayer;
    _board[targetRow][col] = movingPlayer;
    _moveHistory.add((row: targetRow, col: col, player: movingPlayer));

    // Check for win
    final winningLine = _checkWin(targetRow, col, movingPlayer);
    if (winningLine != null) {
      _status = FourInARowGameStatus.won;
      _winner = movingPlayer;
      _winningPositions = winningLine;
      return FourInARowMove(
        player: movingPlayer,
        column: col,
        row: targetRow,
        status: _status,
        winner: _winner,
      );
    }

    // Check for draw
    if (_isBoardFull()) {
      _status = FourInARowGameStatus.draw;
      return FourInARowMove(
        player: movingPlayer,
        column: col,
        row: targetRow,
        status: _status,
        winner: _winner,
      );
    }

    // Switch turn
    _currentPlayer = _currentPlayer.opponent;
    return FourInARowMove(
      player: movingPlayer,
      column: col,
      row: targetRow,
      status: _status,
      winner: _winner,
    );
  }

  /// Drops a disc for [currentPlayer] into column [col].
  ///
  /// Compatibility convenience for existing callers that only need success.
  bool dropDisc(int col) {
    return tryDropDisc(col) != null;
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
    _status = FourInARowGameStatus.playing;
    _winner = null;
    _winningPositions = const [];

    return true;
  }

  /// Resets the game to initial state with Player 1.
  void reset() {
    _board = List.generate(
      rows,
      (_) => List<FourInARowPlayer?>.filled(cols, null),
    );
    _currentPlayer = FourInARowPlayer.player1;
    _status = FourInARowGameStatus.playing;
    _winner = null;
    _winningPositions = const [];
    _moveHistory.clear();
  }

  bool _isBoardFull() {
    for (int c = 0; c < cols; c++) {
      if (_board[0][c] == null) return false;
    }
    return true;
  }

  /// Checks for 4 consecutive pieces in all 4 directions from [row], [col].
  /// Returns sorted positions along the line from one end to the other.
  List<BoardPosition>? _checkWin(int row, int col, FourInARowPlayer player) {
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
        // Sort along the primary axis so positions form an ordered continuous line
        line.sort((a, b) {
          if (a.col != b.col) return a.col.compareTo(b.col);
          return a.row.compareTo(b.row);
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
