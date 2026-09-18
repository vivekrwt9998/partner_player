import '../logic/four_in_a_row_game.dart';
import '../models/four_in_a_row_models.dart';

/// A small, deterministic Four in a Row opponent for casual Bot matches.
///
/// It considers only immediate wins and blocks, then selects the first legal
/// center-weighted column. It never modifies the supplied game.
class SimpleFourInARowBotStrategy {
  static const List<int> _preferredColumns = [3, 2, 4, 1, 5, 0, 6];

  /// Returns a legal column for Red, or `null` when the match is over or no
  /// legal move remains.
  int? chooseColumn(FourInARowGame game) {
    if (game.isGameOver) return null;

    for (final column in _preferredColumns) {
      if (_wouldWin(game, column, FourInARowPlayer.player2)) {
        return column;
      }
    }

    for (final column in _preferredColumns) {
      if (_wouldWin(game, column, FourInARowPlayer.player1)) {
        return column;
      }
    }

    for (final column in _preferredColumns) {
      if (!game.isColumnFull(column)) return column;
    }

    return null;
  }

  bool _wouldWin(
    FourInARowGame game,
    int column,
    FourInARowPlayer player,
  ) {
    if (game.isColumnFull(column)) return false;

    final row = _landingRow(game, column);
    if (row == null) return false;

    const directions = [
      (rowDelta: 0, columnDelta: 1),
      (rowDelta: 1, columnDelta: 0),
      (rowDelta: 1, columnDelta: 1),
      (rowDelta: -1, columnDelta: 1),
    ];

    for (final direction in directions) {
      final connected = 1 +
          _countDirection(
            game,
            row,
            column,
            direction.rowDelta,
            direction.columnDelta,
            player,
          ) +
          _countDirection(
            game,
            row,
            column,
            -direction.rowDelta,
            -direction.columnDelta,
            player,
          );
      if (connected >= FourInARowGame.connectCount) return true;
    }

    return false;
  }

  int? _landingRow(FourInARowGame game, int column) {
    for (var row = FourInARowGame.rows - 1; row >= 0; row--) {
      if (game.getCell(row, column) == null) return row;
    }
    return null;
  }

  int _countDirection(
    FourInARowGame game,
    int row,
    int column,
    int rowDelta,
    int columnDelta,
    FourInARowPlayer player,
  ) {
    var count = 0;
    var currentRow = row + rowDelta;
    var currentColumn = column + columnDelta;

    while (currentRow >= 0 &&
        currentRow < FourInARowGame.rows &&
        currentColumn >= 0 &&
        currentColumn < FourInARowGame.cols &&
        game.getCell(currentRow, currentColumn) == player) {
      count++;
      currentRow += rowDelta;
      currentColumn += columnDelta;
    }

    return count;
  }
}
