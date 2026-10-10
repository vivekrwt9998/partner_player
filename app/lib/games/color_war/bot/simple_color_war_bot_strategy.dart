import '../logic/color_war_game.dart';
import '../models/color_war_models.dart';

/// A small, deterministic Color War opponent for casual Bot matches.
///
/// It plays every legal move out on a copy of the board, cascade and all,
/// and keeps the one that leaves it best off. One move deep is enough to
/// make it take a winning chain when there is one and to stop it feeding
/// cells to an opponent who is one orb from bursting — which is most of
/// what a casual player does too.
///
/// It never modifies the supplied game.
class SimpleColorWarBotStrategy {
  /// A win is worth more than any board could be.
  static const double _decisive = 1000000;

  /// Corners and edges burst sooner, so they are worth holding.
  static const double _lowCriticalMassBonus = 0.8;

  /// How much it dislikes leaving a cell the opponent can burst next turn.
  static const double _exposurePenalty = 2.5;

  /// Returns a legal (row, col) for the player to move, or `null` when the
  /// match is over, still reacting, or has no legal move left.
  (int, int)? chooseCell(ColorWarGame game) {
    if (game.isGameOver || game.hasPendingBlasts) return null;

    final me = game.currentPlayer;
    (int, int)? best;
    var bestScore = double.negativeInfinity;

    for (var row = 0; row < game.rows; row++) {
      for (var col = 0; col < game.cols; col++) {
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

  double _scoreMove(ColorWarGame game, int row, int col, ColorWarPlayer me) {
    final trial = game.copy()..tryPlaceOrb(row, col);
    trial.settle();

    if (trial.winner == me) return _decisive;
    if (trial.winner == me.opponent) return -_decisive;

    final cellLead = trial.cellsOwnedBy(me) - trial.cellsOwnedBy(me.opponent);
    final orbLead = trial.orbsOwnedBy(me) - trial.orbsOwnedBy(me.opponent);
    final cornerValue =
        (4 - trial.criticalMass(row, col)) * _lowCriticalMassBonus;

    return (cellLead * 3.0) +
        orbLead +
        cornerValue -
        (_countExposedCells(trial, me) * _exposurePenalty);
  }

  /// Cells of [player] sitting next to an opponent cell that is one orb
  /// from bursting -- the ones about to be taken off them.
  int _countExposedCells(ColorWarGame game, ColorWarPlayer player) {
    var exposed = 0;

    for (var row = 0; row < game.rows; row++) {
      for (var col = 0; col < game.cols; col++) {
        if (game.cellAt(row, col).owner != player) continue;
        if (_hasPrimedOpponentNeighbour(game, row, col, player)) exposed++;
      }
    }

    return exposed;
  }

  bool _hasPrimedOpponentNeighbour(
    ColorWarGame game,
    int row,
    int col,
    ColorWarPlayer player,
  ) {
    const steps = [(-1, 0), (1, 0), (0, -1), (0, 1)];

    for (final (rowStep, colStep) in steps) {
      final r = row + rowStep;
      final c = col + colStep;
      if (r < 0 || r >= game.rows || c < 0 || c >= game.cols) continue;

      final neighbour = game.cellAt(r, c);
      if (neighbour.owner == null || neighbour.owner == player) continue;
      if (neighbour.orbs >= game.criticalMass(r, c) - 1) return true;
    }

    return false;
  }
}
