import 'package:flutter/foundation.dart';

import '../../../models/game_definition.dart';
import '../logic/tic_tac_toe_game.dart';

/// Coordinates a single local Tic Tac Toe match.
///
/// Only [GameMode.local] is implemented today: Tic Tac Toe has no Bot or
/// Online opponent yet (see AGENTS.md §72).
class TicTacToeMatchController extends ChangeNotifier {
  TicTacToeMatchController({
    required this.mode,
    TicTacToeGame? game,
  })  : assert(mode == GameMode.local),
        _game = game ?? TicTacToeGame();

  final GameMode mode;
  final TicTacToeGame _game;
  var _disposed = false;

  TicTacToeGame get game => _game;
  bool get supportsRevert => mode == GameMode.local;
  bool get canAcceptLocalInput => !_game.isGameOver;
  bool get canRevert => supportsRevert && _game.canRevert;

  /// Applies a board tap for the current player's mark.
  bool submitLocalCell(int row, int col) {
    if (_disposed || !canAcceptLocalInput) return false;
    final move = _game.tryPlaceMark(row, col);
    if (move == null) return false;

    _notifyIfActive();
    return true;
  }

  void restart() {
    if (_disposed) return;
    _game.reset();
    _notifyIfActive();
  }

  void revert() {
    if (_disposed || !canRevert) return;
    _game.revert();
    _notifyIfActive();
  }

  void _notifyIfActive() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
