import '../logic/dots_and_boxes_game.dart';
import '../models/dots_and_boxes_models.dart';

/// A small, deterministic Dots and Boxes opponent for casual Bot
/// matches.
///
/// It plays the three rules a human picks up in their first game:
///
/// 1. Take any box that is already on three sides -- it is free, and it
///    earns another go, so it keeps taking until there are none left.
/// 2. Otherwise draw a line that leaves no box on three sides, so the
///    opponent gets nothing back.
/// 3. When every line would give something away, give away as little as
///    possible.
///
/// It tries each line on the real board and takes it straight back
/// again, the way the Checkers and Reversi bots do, so no copy of the
/// game is made.
class SimpleDotsAndBoxesBotStrategy {
  /// Closing a box beats anything else on the board.
  static const double _claimValue = 1000;

  /// What each box handed to the opponent costs.
  static const double _giftCost = 50;

  /// Returns a legal line for the player to draw, or `null` when the
  /// match is over or every line has been drawn.
  BoxEdge? chooseEdge(DotsAndBoxesGame game) {
    if (game.isGameOver) return null;

    BoxEdge? best;
    var bestScore = double.negativeInfinity;

    // Reading order with a strict comparison, so ties always resolve the
    // same way and a match can be replayed exactly.
    for (final edge in _allEdges()) {
      if (!game.canDraw(edge)) continue;

      final score = _scoreEdge(game, edge);
      if (score > bestScore) {
        bestScore = score;
        best = edge;
      }
    }

    return best;
  }

  double _scoreEdge(DotsAndBoxesGame game, BoxEdge edge) {
    final move = game.tryDrawEdge(edge);
    if (move == null) return double.negativeInfinity;

    final score = move.claimedBoxes.isNotEmpty
        ? _claimValue * move.claimedBoxes.length
        : -(_boxesOnThreeSides(game) * _giftCost);

    game.revert();
    return score;
  }

  /// Boxes sitting on three sides: whatever is left of these is what the
  /// opponent gets to walk in and take.
  int _boxesOnThreeSides(DotsAndBoxesGame game) {
    var count = 0;
    for (var row = 0; row < DotsAndBoxesGame.boxRows; row++) {
      for (var col = 0; col < DotsAndBoxesGame.boxColumns; col++) {
        if (game.boxOwner(row, col) == null && game.sidesDrawn(row, col) == 3) {
          count++;
        }
      }
    }
    return count;
  }

  static List<BoxEdge> _allEdges() => [
        for (var row = 0; row < DotsAndBoxesGame.dotRows; row++)
          for (var col = 0; col < DotsAndBoxesGame.boxColumns; col++)
            BoxEdge.horizontal(row, col),
        for (var row = 0; row < DotsAndBoxesGame.boxRows; row++)
          for (var col = 0; col < DotsAndBoxesGame.dotColumns; col++)
            BoxEdge.vertical(row, col),
      ];
}
