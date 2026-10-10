import 'package:meta/meta.dart';

import '../models/snakes_and_ladders_models.dart';

/// Pure Dart engine for Snakes and Ladders, played to the rules this
/// game is usually played to in India.
///
/// - A token waits off the board until its player rolls a six. Off the
///   board is square zero, so that six is an ordinary move and brings
///   the token on at square six.
/// - A six always earns another roll.
/// - The last square has to be hit exactly. A roll that would go past
///   it is refused and the token stays where it is.
/// - Land at the foot of a ladder and climb it; land on a snake's head
///   and slide down. One jump per landing: no square is both the top of
///   one and the start of another, so nothing chains.
class SnakesAndLaddersGame {
  SnakesAndLaddersGame() {
    reset();
  }

  static const int columns = 10;
  static const int rows = 10;
  static const int lastSquare = columns * rows;

  /// The roll a waiting token needs before it may come on.
  static const int entryRoll = 6;

  /// Every snake and ladder, keyed by the square you land on.
  ///
  /// Nothing starts below [entryRoll]: the first square a token can
  /// ever occupy is six, so a ladder at square four would never be
  /// climbed by anybody.
  static const Map<int, int> jumps = {
    // Ladders.
    8: 26,
    9: 31,
    21: 42,
    28: 84,
    36: 44,
    40: 59,
    51: 67,
    71: 91,
    80: 100,
    // Snakes.
    16: 6,
    47: 26,
    49: 11,
    56: 53,
    62: 19,
    64: 60,
    87: 24,
    93: 73,
    95: 75,
    98: 78,
  };

  final Map<SnakesAndLaddersPlayer, int> _positions = {};

  late SnakesAndLaddersPlayer _currentPlayer;
  late SnakesAndLaddersGameStatus _status;
  SnakesAndLaddersPlayer? _winner;
  SnakesAndLaddersMove? _lastMove;
  var _moveCount = 0;

  SnakesAndLaddersPlayer get currentPlayer => _currentPlayer;

  SnakesAndLaddersGameStatus get status => _status;

  SnakesAndLaddersPlayer? get winner => _winner;

  bool get isGameOver => _status != SnakesAndLaddersGameStatus.playing;

  /// The last roll and everything it did, or `null` before the first.
  SnakesAndLaddersMove? get lastMove => _lastMove;

  /// How many rolls have been taken this match.
  int get moveCount => _moveCount;

  /// Where a token stands. Zero means it is still waiting to come on.
  int positionOf(SnakesAndLaddersPlayer player) => _positions[player] ?? 0;

  bool isOnBoard(SnakesAndLaddersPlayer player) => positionOf(player) > 0;

  /// Whether a roll would do anything at all right now.
  bool get canRoll => !isGameOver;

  /// Applies a roll of [value] for the player to move.
  ///
  /// `null` means the roll was not a legal thing to ask for -- the game
  /// is over, or the value is not something a die can show. A roll that
  /// is legal but achieves nothing still comes back as a move, with
  /// [SnakesAndLaddersMove.blocked] set, because the screen has to
  /// explain why the token did not budge.
  SnakesAndLaddersMove? applyRoll(int value) {
    if (isGameOver || value < 1 || value > 6) return null;

    final player = _currentPlayer;
    final from = positionOf(player);
    final rollsAgain = value == entryRoll;

    // Still waiting to come on, and this is not the six that lets it.
    if (from == 0 && value != entryRoll) {
      return _record(
        SnakesAndLaddersMove(
          player: player,
          roll: value,
          from: 0,
          landedOn: 0,
          to: 0,
          jump: null,
          entered: false,
          blocked: true,
          rollsAgain: false,
          status: _status,
          winner: _winner,
        ),
      );
    }

    final landedOn = from + value;

    // The last square has to be hit exactly.
    if (landedOn > lastSquare) {
      return _record(
        SnakesAndLaddersMove(
          player: player,
          roll: value,
          from: from,
          landedOn: from,
          to: from,
          jump: null,
          entered: false,
          blocked: true,
          rollsAgain: rollsAgain,
          status: _status,
          winner: _winner,
        ),
      );
    }

    final landedAt = jumps[landedOn];
    final jump = landedAt == null ? null : Jump(landedOn, landedAt);
    final to = landedAt ?? landedOn;

    _positions[player] = to;

    if (to == lastSquare) {
      _status = SnakesAndLaddersGameStatus.won;
      _winner = player;
    }

    return _record(
      SnakesAndLaddersMove(
        player: player,
        roll: value,
        from: from,
        landedOn: landedOn,
        to: to,
        jump: jump,
        entered: from == 0,
        blocked: false,
        rollsAgain: rollsAgain,
        status: _status,
        winner: _winner,
      ),
    );
  }

  void reset() {
    _positions
      ..clear()
      ..[SnakesAndLaddersPlayer.player1] = 0
      ..[SnakesAndLaddersPlayer.player2] = 0;
    _currentPlayer = SnakesAndLaddersPlayer.player1;
    _status = SnakesAndLaddersGameStatus.playing;
    _winner = null;
    _lastMove = null;
    _moveCount = 0;
  }

  /// Drops a position in, for tests.
  ///
  /// Rolling a token up to square 95 to see what the snake there does
  /// would take dozens of scripted rolls, so the engine takes the same
  /// debug seam the other games have.
  @visibleForTesting
  void debugConfigure({
    int bluePosition = 0,
    int redPosition = 0,
    SnakesAndLaddersPlayer currentPlayer = SnakesAndLaddersPlayer.player1,
  }) {
    assert(bluePosition >= 0 && bluePosition <= lastSquare);
    assert(redPosition >= 0 && redPosition <= lastSquare);

    _positions[SnakesAndLaddersPlayer.player1] = bluePosition;
    _positions[SnakesAndLaddersPlayer.player2] = redPosition;
    _currentPlayer = currentPlayer;
    _status = SnakesAndLaddersGameStatus.playing;
    _winner = null;
    _lastMove = null;
    _moveCount = 0;
  }

  /// Where a square sits on screen: the row counted from the **top**
  /// and the column from the left.
  ///
  /// The numbering snakes: square 1 is bottom left, 10 is bottom right,
  /// 11 sits directly above 10, and every row after that runs the
  /// opposite way to the one below it.
  static (int row, int column) gridFor(int square) {
    final fromBottom = (square - 1) ~/ columns;
    final along = (square - 1) % columns;
    return (
      rows - 1 - fromBottom,
      fromBottom.isEven ? along : columns - 1 - along,
    );
  }

  SnakesAndLaddersMove _record(SnakesAndLaddersMove move) {
    _lastMove = move;
    _moveCount++;
    if (!move.rollsAgain && !isGameOver) {
      _currentPlayer = _currentPlayer.opponent;
    }
    return move;
  }
}
