import 'package:flutter/foundation.dart';

import '../../../models/game_definition.dart';
import '../logic/tetra_tower_game.dart';

/// Coordinates a single local Tetra Tower match.
///
/// Only [GameMode.local] is implemented today: Tetra Tower has no Bot or
/// Online opponent yet (see AGENTS.md §72).
class TetraTowerMatchController extends ChangeNotifier {
  TetraTowerMatchController({
    required this.mode,
    TetraTowerGame? game,
  })  : assert(mode == GameMode.local),
        _game = game ?? TetraTowerGame();

  final GameMode mode;
  final TetraTowerGame _game;
  var _disposed = false;

  TetraTowerGame get game => _game;
  bool get supportsRevert => mode == GameMode.local;
  bool get canAcceptLocalInput => !_game.isGameOver;
  bool get canRevert => supportsRevert && _game.canRevert;

  /// Cycles the current piece to its next rotation. Purely a preview
  /// change -- doesn't consume the turn.
  void rotatePiece() {
    if (_disposed || !canAcceptLocalInput) return;
    _game.rotatePiece();
    _notifyIfActive();
  }

  /// Places the current piece at the given anchor if that's currently legal.
  bool submitLocalPlacement(int anchorRow, int anchorCol) {
    if (_disposed || !canAcceptLocalInput) return false;
    final move = _game.tryPlacePiece(anchorRow, anchorCol);
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
