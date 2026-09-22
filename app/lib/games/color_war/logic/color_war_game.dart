import '../models/color_war_models.dart';

/// Pure Dart game engine for Color War (a chain-reaction game).
///
/// Rules:
/// - A square grid of cells. Every cell holds the same [burstLimit],
///   wherever it sits on the board.
/// - On your turn you drop one orb into any empty cell, or into a cell you
///   already own. You may never add to the opponent's cell.
/// - A cell that reaches [burstLimit] bursts: it empties, throwing one orb
///   into each orthogonal neighbour, and every cell it hits turns your
///   colour. Those cells can burst in turn, so one orb can set off a chain.
///   A cell at the rim has fewer neighbours to throw to, so the orbs it
///   cannot pass on are simply lost over the edge.
/// - Once a player has had a turn, losing their last cell loses the game.
///   The board always ends up one colour, so there is no draw.
///
/// A cascade is resolved one wave at a time via [stepBlast] rather than all
/// at once, so the UI can show the reaction spreading. The turn only passes
/// to the other player once the board has settled.
class ColorWarGame {
  /// The board the game is played on. Square, so it reads the same however
  /// the device is held.
  static const int defaultSize = 5;

  /// How many orbs any cell holds before it bursts -- the same everywhere
  /// on the board, corner or middle.
  static const int burstLimit = 4;

  ColorWarGame({int rows = defaultSize, int cols = defaultSize})
      : assert(rows >= 2 && cols >= 2, 'a chain needs somewhere to spread'),
        rows = rows,
        cols = cols {
    reset();
  }

  final int rows;
  final int cols;

  late List<List<ColorWarCell>> _board;
  late ColorWarPlayer _currentPlayer;
  late ColorWarGameStatus _status;
  ColorWarPlayer? _winner;

  /// Who set off the cascade currently in flight, if any.
  ColorWarPlayer? _blastOwner;

  /// Cells at or over [burstLimit], waiting to burst.
  List<ColorWarPosition> _pending = const [];

  /// Players who have had at least one turn. Until a player has played,
  /// owning nothing is the normal starting position rather than a loss.
  final Set<ColorWarPlayer> _hasPlayed = {};

  /// Board states from before each placement, for Revert. A cascade can
  /// touch most of the board, so undoing it move-by-move is not practical;
  /// a 5x5 snapshot is cheap enough to just keep.
  final List<_Snapshot> _history = [];

  /// The whole board. Row 0 is the top row.
  List<List<ColorWarCell>> get board => _board;

  ColorWarPlayer get currentPlayer => _currentPlayer;

  ColorWarGameStatus get status => _status;

  ColorWarPlayer? get winner => _winner;

  bool get isGameOver => _status != ColorWarGameStatus.playing;

  /// Whether a chain reaction is still spreading.
  bool get hasPendingBlasts => _pending.isNotEmpty;

  /// Whose chain reaction is currently spreading, if one is.
  ColorWarPlayer? get blastOwner => _blastOwner;

  /// Cells still waiting to burst, in reading order.
  List<ColorWarPosition> get pendingBlasts => List.unmodifiable(_pending);

  bool get canRevert => _history.isNotEmpty && !hasPendingBlasts;

  /// Number of placements made so far in this match.
  int get moveCount => _history.length;

  ColorWarCell cellAt(int row, int col) {
    if (!_isOnBoard(row, col)) return ColorWarCell.empty;
    return _board[row][col];
  }

  /// The score shown to players: how many cells of the board [player] holds.
  int cellsOwnedBy(ColorWarPlayer player) {
    var count = 0;
    for (final row in _board) {
      for (final cell in row) {
        if (cell.owner == player) count++;
      }
    }
    return count;
  }

  /// Total orbs [player] has on the board.
  int orbsOwnedBy(ColorWarPlayer player) {
    var count = 0;
    for (final row in _board) {
      for (final cell in row) {
        if (cell.owner == player) count += cell.orbs;
      }
    }
    return count;
  }

  /// Whether the current player may drop an orb here right now.
  bool canPlace(int row, int col) {
    if (isGameOver || hasPendingBlasts) return false;
    if (!_isOnBoard(row, col)) return false;
    final owner = _board[row][col].owner;
    return owner == null || owner == _currentPlayer;
  }

  /// Drops one orb for [currentPlayer] at [row]/[col].
  ///
  /// `null` means the cell was off the board, held by the opponent, or the
  /// board was busy or finished. Otherwise the move is applied; if
  /// [ColorWarMove.willExplode] is true the caller drives [stepBlast] until
  /// the board settles.
  ColorWarMove? tryPlaceOrb(int row, int col) {
    if (!canPlace(row, col)) return null;

    final player = _currentPlayer;
    _history.add(_snapshot());

    final cell = _board[row][col];
    _board[row][col] = ColorWarCell(owner: player, orbs: cell.orbs + 1);
    _hasPlayed.add(player);

    _blastOwner = player;
    _refreshPending();
    _checkForWin();

    if (!hasPendingBlasts && !isGameOver) _passTurn();

    return ColorWarMove(
      player: player,
      row: row,
      col: col,
      willExplode: hasPendingBlasts,
      status: _status,
      winner: _winner,
    );
  }

  /// Bursts every cell that is currently at or over [burstLimit], all at
  /// once, and returns what happened.
  ///
  /// Returns `null` when there was nothing left to burst.
  ColorWarBlast? stepBlast() {
    if (_pending.isEmpty || isGameOver) return null;

    final player = _blastOwner ?? _currentPlayer;
    final sources = _pending;
    _pending = const [];

    // Empty the bursting cells first, then hand out their orbs, so two
    // cells bursting into each other in the same wave both get their orb.
    for (final position in sources) {
      final cell = _board[position.row][position.col];
      final left = cell.orbs - burstLimit;
      _board[position.row][position.col] =
          left > 0 ? ColorWarCell(owner: cell.owner, orbs: left) : ColorWarCell.empty;
    }
    for (final position in sources) {
      for (final neighbour in _neighboursOf(position)) {
        final cell = _board[neighbour.row][neighbour.col];
        _board[neighbour.row][neighbour.col] =
            ColorWarCell(owner: player, orbs: cell.orbs + 1);
      }
    }

    _refreshPending();
    _checkForWin();

    if (!hasPendingBlasts && !isGameOver) _passTurn();

    return ColorWarBlast(
      player: player,
      sources: List.unmodifiable(sources),
      hasMore: hasPendingBlasts,
      status: _status,
      winner: _winner,
    );
  }

  /// Runs a cascade to completion in one go — for the bot's lookahead and
  /// for tests. The screen steps wave by wave instead, so players can see
  /// the reaction spread.
  ///
  /// [maxWaves] is a safety net only: a burst never hands out more orbs
  /// than it swallowed, and loses any it has no neighbour for, so the orb
  /// count can only fall and a cascade always runs out.
  void settle({int maxWaves = 500}) {
    var waves = 0;
    while (hasPendingBlasts && !isGameOver && waves < maxWaves) {
      stepBlast();
      waves++;
    }
  }

  /// Undoes the last placement, cascade and all.
  bool revert() {
    if (!canRevert) return false;
    _restore(_history.removeLast());
    return true;
  }

  /// Resets the board to an empty grid with Player 1 to move.
  void reset() {
    _board = List.generate(
      rows,
      (_) => List<ColorWarCell>.filled(cols, ColorWarCell.empty),
    );
    _currentPlayer = ColorWarPlayer.player1;
    _status = ColorWarGameStatus.playing;
    _winner = null;
    _blastOwner = null;
    _pending = const [];
    _hasPlayed.clear();
    _history.clear();
  }

  /// An independent copy of this game, used by the bot to try a move out
  /// without touching the real board.
  ColorWarGame copy() {
    final clone = ColorWarGame(rows: rows, cols: cols);
    clone._restore(_snapshot());
    return clone;
  }

  /// Replaces the board wholesale. Test seam: building an interesting
  /// position by playing into it move by move would bury what a test is
  /// actually about.
  ///
  /// [cells] must be [rows] x [cols].
  void debugConfigure({
    required List<List<ColorWarCell>> cells,
    ColorWarPlayer currentPlayer = ColorWarPlayer.player1,
    bool bothPlayersHaveMoved = true,
  }) {
    assert(cells.length == rows, 'expected $rows rows');
    assert(cells.every((row) => row.length == cols), 'expected $cols columns');

    _board = [for (final row in cells) List<ColorWarCell>.of(row)];
    _currentPlayer = currentPlayer;
    _status = ColorWarGameStatus.playing;
    _winner = null;
    _blastOwner = null;
    _pending = const [];
    _history.clear();
    _hasPlayed
      ..clear()
      ..addAll(bothPlayersHaveMoved
          ? ColorWarPlayer.values
          : const <ColorWarPlayer>[]);
  }

  // --- internals -----------------------------------------------------------

  bool _isOnBoard(int row, int col) =>
      row >= 0 && row < rows && col >= 0 && col < cols;

  List<ColorWarPosition> _neighboursOf(ColorWarPosition position) {
    final neighbours = <ColorWarPosition>[];
    if (position.row > 0) {
      neighbours.add(ColorWarPosition(position.row - 1, position.col));
    }
    if (position.row < rows - 1) {
      neighbours.add(ColorWarPosition(position.row + 1, position.col));
    }
    if (position.col > 0) {
      neighbours.add(ColorWarPosition(position.row, position.col - 1));
    }
    if (position.col < cols - 1) {
      neighbours.add(ColorWarPosition(position.row, position.col + 1));
    }
    return neighbours;
  }

  void _refreshPending() {
    List<ColorWarPosition>? ready;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        if (_board[row][col].orbs >= burstLimit) {
          (ready ??= <ColorWarPosition>[]).add(ColorWarPosition(row, col));
        }
      }
    }
    _pending = ready ?? const [];
  }

  /// A player is out once they have had a turn and hold nothing.
  ///
  /// Checked between waves as well as after a placement: a cascade that has
  /// already wiped the opponent out has nothing left to spread into, and
  /// would otherwise keep bursting forever.
  void _checkForWin() {
    if (_hasPlayed.length < ColorWarPlayer.values.length) return;

    for (final player in ColorWarPlayer.values) {
      if (cellsOwnedBy(player) == 0) {
        _status = ColorWarGameStatus.won;
        _winner = player.opponent;
        _pending = const [];
        _blastOwner = null;
        return;
      }
    }
  }

  void _passTurn() {
    _blastOwner = null;
    _currentPlayer = _currentPlayer.opponent;
  }

  _Snapshot _snapshot() => _Snapshot(
        board: [for (final row in _board) List<ColorWarCell>.of(row)],
        currentPlayer: _currentPlayer,
        status: _status,
        winner: _winner,
        hasPlayed: Set<ColorWarPlayer>.of(_hasPlayed),
      );

  void _restore(_Snapshot snapshot) {
    _board = [for (final row in snapshot.board) List<ColorWarCell>.of(row)];
    _currentPlayer = snapshot.currentPlayer;
    _status = snapshot.status;
    _winner = snapshot.winner;
    _blastOwner = null;
    _pending = const [];
    _hasPlayed
      ..clear()
      ..addAll(snapshot.hasPlayed);
  }
}

/// Everything needed to put the board back the way it was before a move.
class _Snapshot {
  final List<List<ColorWarCell>> board;
  final ColorWarPlayer currentPlayer;
  final ColorWarGameStatus status;
  final ColorWarPlayer? winner;
  final Set<ColorWarPlayer> hasPlayed;

  const _Snapshot({
    required this.board,
    required this.currentPlayer,
    required this.status,
    required this.winner,
    required this.hasPlayed,
  });
}
