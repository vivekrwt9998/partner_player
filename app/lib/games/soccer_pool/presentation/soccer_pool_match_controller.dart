import 'package:flutter/foundation.dart';

import '../../../models/game_definition.dart';
import '../logic/soccer_pool_game.dart';
import '../models/soccer_pool_models.dart';

/// Coordinates a single local Soccer Pool match.
///
/// Soccer Pool is a turn-based flick-the-piece game: each player takes a
/// turn flicking one of their tokens at the ball (or at the opponent's
/// tokens) trying to score in the opponent's goal. The match controller
/// owns the turn state machine and forwards physics updates from the
/// screen's frame ticker into the engine.
///
/// Only [GameMode.local] is implemented today: Soccer Pool has no Bot or
/// Online opponent yet (see AGENTS.md §72).
class SoccerPoolMatchController extends ChangeNotifier {
  SoccerPoolMatchController({
    required this.mode,
    SoccerPoolGame? game,
  })  : assert(mode == GameMode.local),
        _game = game ?? SoccerPoolGame();

  final GameMode mode;
  final SoccerPoolGame _game;
  var _disposed = false;

  SoccerPoolGame get game => _game;

  /// Whether a shot may be triggered by a local input right now. A shot
  /// cannot be started while another shot is still resolving, while the
  /// game is over, or after the controller has been disposed.
  bool get canAcceptLocalInput =>
      !_disposed && !_game.isGameOver && !_game.isMoving;

  /// Local mode only — there's no opponent making moves in the back.
  bool get supportsRevert => false;

  /// Launches [pieceId] (one of the current player's tokens) with [velocity]
  /// in field units per second. Returns whether the engine accepted the
  /// shot.
  bool tryShoot(int pieceId, SoccerPoolVector velocity) {
    if (_disposed || !canAcceptLocalInput) return false;
    final accepted = _game.tryShoot(pieceId, velocity);
    if (accepted) _notifyIfActive();
    return accepted;
  }

  /// Feeds real seconds into the engine's fixed-step solver. Returns
  /// `true` on the frame the game is won, so the screen can start its
  /// result transition.
  bool advance(double elapsedSeconds) {
    if (_disposed || _game.isGameOver) return false;
    final wasOver = _game.isGameOver;
    final result = _game.advance(elapsedSeconds);
    if (!wasOver && _game.isGameOver) {
      _notifyIfActive();
      return true;
    }
    if (result) _notifyIfActive();
    return false;
  }

  void restart() {
    if (_disposed) return;
    _game.reset();
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