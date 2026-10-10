import 'dart:collection';

import '../logic/hex_game.dart';
import '../models/hex_models.dart';

/// Picks a cell for the bot.
///
/// Hex has no captures and no material to count, so the only thing worth
/// measuring is how close each side is to joining its two edges. For a
/// player, that is: how many more stones would they have to place, at
/// best, to finish a chain? Own stones are free to travel through, empty
/// cells cost one, and the opponent's are walls.
///
/// The bot plays the cell that leaves it closest to finishing while
/// leaving the opponent furthest away, so a single number covers both
/// building its own chain and standing in the way of the other one --
/// which in Hex are usually the same move anyway.
///
/// Deliberately one ply deep (AGENTS.md §27): it reads the board rather
/// than searching it, and that is enough to make it play sensibly
/// without any of the machinery a real Hex engine would need.
class SimpleHexBotStrategy {
  /// Far enough beyond any real distance to stand in for "no way
  /// through", while still being an ordinary number to compare.
  static const int _unreachable = 9999;

  /// Taking the win now beats every positional consideration.
  static const double _winScore = 1000000;

  /// Breaks ties towards the middle, where a chain has the most ways to
  /// carry on. Small enough that it never outweighs a real difference in
  /// distance.
  static const double _centreWeight = 0.01;

  /// The cell the bot wants, or `null` when the game is already over.
  HexCell? chooseCell(HexGame game) {
    if (game.isGameOver) return null;

    final me = game.currentPlayer;
    final opponent = me.opponent;

    HexCell? best;
    var bestScore = double.negativeInfinity;

    for (var row = 0; row < HexGame.size; row++) {
      for (var col = 0; col < HexGame.size; col++) {
        if (!game.canPlace(row, col)) continue;

        // Scored on the real board and taken straight back off, the way
        // the other bots on this platform do it.
        final move = game.tryPlace(row, col);
        if (move == null) continue;

        final score = move.winner == me
            ? _winScore
            : (_distanceToConnect(game, opponent) -
                    _distanceToConnect(game, me))
                .toDouble();

        game.revert();

        final total = score + (_centreWeight * _centreBonus(row, col));
        if (total > bestScore) {
          bestScore = total;
          best = HexCell(row, col);
        }
      }
    }

    return best;
  }

  /// The fewest further stones [player] would need to join their two
  /// sides, ignoring whose turn it is.
  ///
  /// A 0-1 breadth-first search rather than a full Dijkstra: every step
  /// costs either nothing (a cell this player already holds) or one (an
  /// empty cell), and with only those two weights a double-ended queue
  /// keeps the frontier in order by itself.
  int _distanceToConnect(HexGame game, HexPlayer player) {
    final isBlue = player == HexPlayer.player1;
    final best = List.generate(
      HexGame.size,
      (_) => List<int>.filled(HexGame.size, _unreachable),
    );
    final frontier = DoubleLinkedQueue<HexCell>();

    int costOf(int row, int col) {
      final owner = game.stoneAt(row, col);
      if (owner == player) return 0;
      if (owner != null) return _unreachable;
      return 1;
    }

    void offer(int row, int col, int distance) {
      if (distance >= best[row][col]) return;
      best[row][col] = distance;
      final cell = HexCell(row, col);
      // A free step keeps its place at the head of the queue; a paid one
      // goes to the back, which is what keeps the order correct.
      if (costOf(row, col) == 0) {
        frontier.addFirst(cell);
      } else {
        frontier.addLast(cell);
      }
    }

    // Blue starts from the left column, Red from the top row.
    for (var i = 0; i < HexGame.size; i++) {
      final row = isBlue ? i : 0;
      final col = isBlue ? 0 : i;
      final cost = costOf(row, col);
      if (cost < _unreachable) offer(row, col, cost);
    }

    while (frontier.isNotEmpty) {
      final cell = frontier.removeFirst();
      final distance = best[cell.row][cell.col];

      for (final (dr, dc) in HexGame.neighbourOffsets) {
        final row = cell.row + dr;
        final col = cell.col + dc;
        if (row < 0 || row >= HexGame.size) continue;
        if (col < 0 || col >= HexGame.size) continue;

        final cost = costOf(row, col);
        if (cost >= _unreachable) continue;
        offer(row, col, distance + cost);
      }
    }

    var answer = _unreachable;
    for (var i = 0; i < HexGame.size; i++) {
      final row = isBlue ? i : HexGame.size - 1;
      final col = isBlue ? HexGame.size - 1 : i;
      if (best[row][col] < answer) answer = best[row][col];
    }
    return answer;
  }

  /// Higher towards the middle of the board.
  double _centreBonus(int row, int col) {
    const middle = (HexGame.size - 1) / 2;
    return -((row - middle).abs() + (col - middle).abs());
  }
}
