import '../logic/reversi_game.dart';
import '../models/reversi_models.dart';

/// A small, deterministic Reversi opponent for casual Bot matches.
///
/// It weighs each legal square three ways: where on the board it sits,
/// how many discs it turns over, and how much room it leaves the
/// opponent afterwards. Position dominates, because in Reversi it has to
/// -- a corner can never be taken back, the squares beside a corner hand
/// one over, and grabbing the most discs early is the classic way to
/// lose. Greedy flip-counting alone would make a bot that beats nobody
/// and frustrates everybody.
///
/// It plays each candidate on the real board and takes it straight back
/// again, the way the Checkers bot does, so no copy of the game is made.
class SimpleReversiBotStrategy {
  /// A win is worth more than any board could be.
  static const double _decisive = 1000000;

  /// How much each square is worth to hold, in reading order. Corners
  /// are safe forever; their diagonal neighbours are the squares that
  /// give a corner away, so they cost.
  static const List<int> _squareValues = [
    120, -20, 20, 5, 5, 20, -20, 120, //
    -20, -40, -5, -5, -5, -5, -40, -20,
    20, -5, 15, 3, 3, 15, -5, 20,
    5, -5, 3, 3, 3, 3, -5, 5,
    5, -5, 3, 3, 3, 3, -5, 5,
    20, -5, 15, 3, 3, 15, -5, 20,
    -20, -40, -5, -5, -5, -5, -40, -20,
    120, -20, 20, 5, 5, 20, -20, 120,
  ];

  /// Each disc turned over is worth a little -- but only a little, next
  /// to where the disc lands.
  static const double _flipValue = 2;

  /// And every reply it leaves the opponent costs a little, so the bot
  /// prefers lines that shut them down.
  static const double _opponentMoveCost = 3;

  /// Returns a legal (row, col) for the player to move, or `null` when
  /// the match is over or there is nothing legal to play.
  (int, int)? chooseCell(ReversiGame game) {
    if (game.isGameOver) return null;

    final me = game.currentPlayer;
    (int, int)? best;
    var bestScore = double.negativeInfinity;

    // Reading order, with a strict comparison, so ties always resolve
    // the same way and a match can be replayed exactly.
    for (var row = 0; row < ReversiGame.size; row++) {
      for (var col = 0; col < ReversiGame.size; col++) {
        if (!game.canPlace(row, col)) continue;

        final score = _scoreMove(game, row, col, me);
        if (score > bestScore) {
          bestScore = score;
          best = (row, col);
        }
      }
    }

    return best;
  }

  double _scoreMove(ReversiGame game, int row, int col, ReversiPlayer me) {
    final move = game.tryPlace(row, col);
    if (move == null) return double.negativeInfinity;

    double score;
    if (move.isTerminal) {
      score = switch (move.winner) {
        null => 0, // a draw is worth neither winning nor losing
        _ => move.winner == me ? _decisive : -_decisive,
      };
    } else {
      // After the move it is usually the opponent to play -- unless they
      // had nothing and were skipped, which is a fine thing to engineer.
      final opponentReplies =
          game.currentPlayer == me ? 0 : game.legalMoves.length;

      score = _squareValues[(row * ReversiGame.size) + col] +
          (move.flipped.length * _flipValue) -
          (opponentReplies * _opponentMoveCost);
    }

    game.revert();
    return score;
  }
}
