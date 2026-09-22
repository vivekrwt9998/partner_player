import '../logic/tic_tac_toe_game.dart';
import '../models/tic_tac_toe_models.dart';

/// A small, deterministic Tic Tac Toe opponent for casual Bot matches.
///
/// It considers only immediate wins and blocks, then falls back to a
/// classic center -> corners -> edges preference. It never modifies the
/// supplied game.
class SimpleTicTacToeBotStrategy {
  static const List<(int, int)> _preferredCells = [
    (1, 1),
    (0, 0), (0, 2), (2, 0), (2, 2),
    (0, 1), (1, 0), (1, 2), (2, 1),
  ];

  /// Returns a legal (row, col) for Red, or `null` when the match is over or
  /// no legal move remains.
  (int, int)? chooseCell(TicTacToeGame game) {
    if (game.isGameOver) return null;

    for (final cell in _preferredCells) {
      if (_wouldWin(game, cell.$1, cell.$2, TicTacToePlayer.player2)) {
        return cell;
      }
    }

    for (final cell in _preferredCells) {
      if (_wouldWin(game, cell.$1, cell.$2, TicTacToePlayer.player1)) {
        return cell;
      }
    }

    for (final cell in _preferredCells) {
      if (game.getCell(cell.$1, cell.$2) == null) return cell;
    }

    return null;
  }

  bool _wouldWin(
    TicTacToeGame game,
    int row,
    int col,
    TicTacToePlayer player,
  ) {
    if (game.getCell(row, col) != null) return false;

    const directions = [
      (rowDelta: 0, colDelta: 1),
      (rowDelta: 1, colDelta: 0),
      (rowDelta: 1, colDelta: 1),
      (rowDelta: -1, colDelta: 1),
    ];

    for (final direction in directions) {
      final connected = 1 +
          _countDirection(
            game,
            row,
            col,
            direction.rowDelta,
            direction.colDelta,
            player,
          ) +
          _countDirection(
            game,
            row,
            col,
            -direction.rowDelta,
            -direction.colDelta,
            player,
          );
      if (connected >= TicTacToeGame.connectCount) return true;
    }

    return false;
  }

  int _countDirection(
    TicTacToeGame game,
    int row,
    int col,
    int rowDelta,
    int colDelta,
    TicTacToePlayer player,
  ) {
    var count = 0;
    var currentRow = row + rowDelta;
    var currentCol = col + colDelta;

    while (currentRow >= 0 &&
        currentRow < TicTacToeGame.rows &&
        currentCol >= 0 &&
        currentCol < TicTacToeGame.cols &&
        game.getCell(currentRow, currentCol) == player) {
      count++;
      currentRow += rowDelta;
      currentCol += colDelta;
    }

    return count;
  }
}
