import '../logic/checkers_game.dart';
import '../models/checkers_models.dart';

/// A small, deterministic Checkers opponent for casual Bot matches.
///
/// [CheckersGame] itself already forces captures and multi-jump chains, so
/// this strategy's real job is choosing *which* legal move to make when
/// there's more than one option: it favors capturing, chaining into
/// another capture, and promoting, and avoids leaving a piece capturable
/// next turn when a safer option exists. Every candidate is evaluated by
/// actually applying it to [game] and then reverting it, so the game is
/// left exactly as it was found -- only the chosen move is left for the
/// caller to actually apply for real.
class SimpleCheckersBotStrategy {
  static const _captureBonus = 100;
  static const _chainBonus = 60;
  static const _promotionBonus = 40;
  static const _hangingPenalty = 70;

  /// Returns the `(fromRow, fromCol, toRow, toCol)` the bot should play, or
  /// `null` when the match is over or it has no legal move.
  (int, int, int, int)? chooseMove(CheckersGame game) {
    if (game.isGameOver) return null;

    final candidates = _legalMovesForCurrentPlayer(game);
    if (candidates.isEmpty) return null;

    (int, int, int, int)? best;
    var bestScore = -1 << 30;

    for (final candidate in candidates) {
      final score = _score(game, candidate);
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    return best;
  }

  int _score(CheckersGame game, (int, int, int, int) candidate) {
    final (fromRow, fromCol, toRow, toCol) = candidate;
    final mover = game.currentPlayer;
    final move = game.tryMove(fromRow, fromCol, toRow, toCol);
    if (move == null) return -1 << 30;

    var score = 0;
    if (move.captured != null) score += _captureBonus;
    if (move.mustContinue) score += _chainBonus;
    if (move.promoted) score += _promotionBonus;

    // Did this move hand the opponent an immediate capture? Only relevant
    // once the turn has actually passed -- a chain continuation keeps the
    // same player moving, so there's nothing to check yet.
    if (!move.mustContinue && _anyCaptureAvailable(game, mover.opponent)) {
      score -= _hangingPenalty;
    }

    // A small nudge toward advancing rather than shuffling in place.
    score += mover == CheckersPlayer.player1 ? (fromRow - toRow) : (toRow - fromRow);

    game.revert();
    return score;
  }

  bool _anyCaptureAvailable(CheckersGame game, CheckersPlayer player) {
    for (var row = 0; row < CheckersGame.size; row++) {
      for (var col = 0; col < CheckersGame.size; col++) {
        final piece = game.getCell(row, col);
        if (piece == null || piece.player != player) continue;
        final destinations = game.legalMovesFrom(row, col);
        if (destinations.any((d) => (d.row - row).abs() == 2)) return true;
      }
    }
    return false;
  }

  List<(int, int, int, int)> _legalMovesForCurrentPlayer(CheckersGame game) {
    final moves = <(int, int, int, int)>[];
    final continueFrom = game.mustContinueFrom;

    if (continueFrom != null) {
      for (final dest in game.legalMovesFrom(continueFrom.row, continueFrom.col)) {
        moves.add((continueFrom.row, continueFrom.col, dest.row, dest.col));
      }
      return moves;
    }

    for (var row = 0; row < CheckersGame.size; row++) {
      for (var col = 0; col < CheckersGame.size; col++) {
        final piece = game.getCell(row, col);
        if (piece == null || piece.player != game.currentPlayer) continue;
        for (final dest in game.legalMovesFrom(row, col)) {
          moves.add((row, col, dest.row, dest.col));
        }
      }
    }
    return moves;
  }
}
