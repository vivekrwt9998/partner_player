import '../models/checkers_models.dart';

/// One recorded move, kept only so [CheckersGame.revert] can undo it.
typedef _MoveRecord = ({
  CheckersPlayer player,
  BoardPosition from,
  BoardPosition to,
  BoardPosition? capturedAt,
  CheckersPiece? capturedPiece,
  bool wasPromoted,
  BoardPosition? previousMustContinueFrom,
  CheckersGameStatus previousStatus,
  CheckersPlayer? previousWinner,
});

/// Pure Dart game engine for Checkers (English/American draughts rules).
///
/// - 8x8 board, pieces only ever occupy the 32 dark squares.
/// - Men move/capture diagonally forward only; a King (a man that reaches
///   the far row) moves/captures diagonally in any direction.
/// - Capturing is forced: if any of a player's pieces can capture, only
///   capturing moves are legal that turn.
/// - A capture that lands where another capture is immediately available
///   with the *same* piece must continue (multi-jump), unless that capture
///   just crowned the piece -- kinging always ends the turn.
/// - A player loses the moment they have no legal move on their turn
///   (no pieces left, or every remaining piece is blocked).
class CheckersGame {
  static const int size = 8;

  late List<List<CheckersPiece?>> _board;
  late CheckersPlayer _currentPlayer;
  late CheckersGameStatus _status;
  CheckersPlayer? _winner;
  BoardPosition? _mustContinueFrom;
  final List<_MoveRecord> _moveHistory = [];

  CheckersGame() {
    reset();
  }

  /// Current 8x8 board grid. Row 0 is top, Row 7 is bottom. Light squares
  /// are always `null` -- checkers pieces never occupy them.
  List<List<CheckersPiece?>> get board => _board;

  /// Player whose turn it currently is.
  CheckersPlayer get currentPlayer => _currentPlayer;

  /// Current game lifecycle status.
  CheckersGameStatus get status => _status;

  /// Winner of the game, or `null` if still playing.
  CheckersPlayer? get winner => _winner;

  /// Whether the game is finished.
  bool get isGameOver => _status != CheckersGameStatus.playing;

  /// Whether a move can currently be reverted/undone.
  bool get canRevert => _moveHistory.isNotEmpty;

  /// Number of moves made so far in this match.
  int get moveCount => _moveHistory.length;

  /// The piece that must keep jumping this turn (mid multi-capture chain),
  /// or `null` when the current player may move any of their pieces.
  BoardPosition? get mustContinueFrom => _mustContinueFrom;

  /// The piece at [row]/[col], or `null` if empty/out of bounds.
  CheckersPiece? getCell(int row, int col) {
    if (!_inBounds(row, col)) return null;
    return _board[row][col];
  }

  /// Legal destinations for the piece at [row]/[col] right now, honoring
  /// the forced-capture rule and mid-chain continuation.
  List<BoardPosition> legalMovesFrom(int row, int col) {
    if (isGameOver) return const [];
    final piece = getCell(row, col);
    if (piece == null || piece.player != _currentPlayer) return const [];

    if (_mustContinueFrom != null) {
      if (_mustContinueFrom!.row != row || _mustContinueFrom!.col != col) {
        return const [];
      }
      return _captureDestinations(row, col, piece);
    }

    final captures = _captureDestinations(row, col, piece);
    if (captures.isNotEmpty) return captures;
    if (_anyCaptureAvailable(_currentPlayer)) return const [];
    return _simpleDestinations(row, col, piece);
  }

  /// Applies a move for the current player from [fromRow]/[fromCol] to
  /// [toRow]/[toCol]. Returns `null` if that destination isn't currently
  /// legal for that piece (see [legalMovesFrom]).
  CheckersMove? tryMove(int fromRow, int fromCol, int toRow, int toCol) {
    final piece = getCell(fromRow, fromCol);
    if (piece == null) return null;

    final destination = BoardPosition(toRow, toCol);
    if (!legalMovesFrom(fromRow, fromCol).contains(destination)) return null;

    final isCapture = (fromRow - toRow).abs() == 2;
    BoardPosition? capturedAt;
    CheckersPiece? capturedPiece;
    if (isCapture) {
      capturedAt = BoardPosition((fromRow + toRow) ~/ 2, (fromCol + toCol) ~/ 2);
      capturedPiece = _board[capturedAt.row][capturedAt.col];
      _board[capturedAt.row][capturedAt.col] = null;
    }

    final reachedBackRow = (piece.player == CheckersPlayer.player1 && toRow == 0) ||
        (piece.player == CheckersPlayer.player2 && toRow == size - 1);
    final promoted = !piece.isKing && reachedBackRow;
    final movedPiece = promoted ? piece.copyWith(isKing: true) : piece;

    _board[fromRow][fromCol] = null;
    _board[toRow][toCol] = movedPiece;

    _moveHistory.add((
      player: _currentPlayer,
      from: BoardPosition(fromRow, fromCol),
      to: destination,
      capturedAt: capturedAt,
      capturedPiece: capturedPiece,
      wasPromoted: promoted,
      previousMustContinueFrom: _mustContinueFrom,
      previousStatus: _status,
      previousWinner: _winner,
    ));

    // Kinging ends the turn immediately even mid-chain (standard rule),
    // otherwise the same piece must keep jumping if it still can.
    final mustContinue =
        isCapture && !promoted && _captureDestinations(toRow, toCol, movedPiece).isNotEmpty;

    final movingPlayer = _currentPlayer;
    if (mustContinue) {
      _mustContinueFrom = destination;
    } else {
      _mustContinueFrom = null;
      _currentPlayer = _currentPlayer.opponent;
      if (!_hasAnyLegalMove(_currentPlayer)) {
        _status = CheckersGameStatus.won;
        _winner = movingPlayer;
      }
    }

    return CheckersMove(
      player: movingPlayer,
      from: BoardPosition(fromRow, fromCol),
      to: destination,
      captured: capturedAt,
      promoted: promoted,
      mustContinue: mustContinue,
      status: _status,
      winner: _winner,
    );
  }

  /// Reverts (undoes) the last applied move, restoring the board, whose
  /// turn it was, any mid-chain continuation, and terminal state.
  bool revert() {
    if (_moveHistory.isEmpty) return false;
    final record = _moveHistory.removeLast();

    final movedPiece = _board[record.to.row][record.to.col]!;
    final restoredPiece = record.wasPromoted ? movedPiece.copyWith(isKing: false) : movedPiece;
    _board[record.to.row][record.to.col] = null;
    _board[record.from.row][record.from.col] = restoredPiece;

    final capturedAt = record.capturedAt;
    if (capturedAt != null) {
      _board[capturedAt.row][capturedAt.col] = record.capturedPiece;
    }

    _currentPlayer = record.player;
    _mustContinueFrom = record.previousMustContinueFrom;
    _status = record.previousStatus;
    _winner = record.previousWinner;

    return true;
  }

  /// Resets the game to its standard starting position with Player 1.
  void reset() {
    _board = List.generate(size, (_) => List<CheckersPiece?>.filled(size, null));

    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < size; col++) {
        if ((row + col).isOdd) {
          _board[row][col] = const CheckersPiece(player: CheckersPlayer.player2, isKing: false);
        }
      }
    }
    for (var row = size - 3; row < size; row++) {
      for (var col = 0; col < size; col++) {
        if ((row + col).isOdd) {
          _board[row][col] = const CheckersPiece(player: CheckersPlayer.player1, isKing: false);
        }
      }
    }

    _currentPlayer = CheckersPlayer.player1;
    _status = CheckersGameStatus.playing;
    _winner = null;
    _mustContinueFrom = null;
    _moveHistory.clear();
  }

  bool _inBounds(int row, int col) => row >= 0 && row < size && col >= 0 && col < size;

  /// The diagonal directions [piece] may move/capture in.
  List<({int dr, int dc})> _directionsFor(CheckersPiece piece) {
    if (piece.isKing) {
      return const [(dr: -1, dc: -1), (dr: -1, dc: 1), (dr: 1, dc: -1), (dr: 1, dc: 1)];
    }
    final forward = piece.player == CheckersPlayer.player1 ? -1 : 1;
    return [(dr: forward, dc: -1), (dr: forward, dc: 1)];
  }

  List<BoardPosition> _simpleDestinations(int row, int col, CheckersPiece piece) {
    final destinations = <BoardPosition>[];
    for (final dir in _directionsFor(piece)) {
      final r = row + dir.dr;
      final c = col + dir.dc;
      if (_inBounds(r, c) && _board[r][c] == null) {
        destinations.add(BoardPosition(r, c));
      }
    }
    return destinations;
  }

  List<BoardPosition> _captureDestinations(int row, int col, CheckersPiece piece) {
    final destinations = <BoardPosition>[];
    for (final dir in _directionsFor(piece)) {
      final midRow = row + dir.dr;
      final midCol = col + dir.dc;
      final landRow = row + (dir.dr * 2);
      final landCol = col + (dir.dc * 2);
      if (!_inBounds(landRow, landCol) || _board[landRow][landCol] != null) continue;

      final midPiece = getCell(midRow, midCol);
      if (midPiece == null || midPiece.player == piece.player) continue;

      destinations.add(BoardPosition(landRow, landCol));
    }
    return destinations;
  }

  bool _anyCaptureAvailable(CheckersPlayer player) {
    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        final piece = _board[row][col];
        if (piece != null &&
            piece.player == player &&
            _captureDestinations(row, col, piece).isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  bool _hasAnyLegalMove(CheckersPlayer player) {
    if (_anyCaptureAvailable(player)) return true;

    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        final piece = _board[row][col];
        if (piece == null || piece.player != player) continue;
        if (_simpleDestinations(row, col, piece).isNotEmpty) return true;
      }
    }
    return false;
  }
}
