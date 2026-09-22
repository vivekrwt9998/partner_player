import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/game_definition.dart';
import '../bot/simple_checkers_bot_strategy.dart';
import '../logic/checkers_game.dart';
import '../models/checkers_models.dart';

/// Coordinates a single local or Bot Checkers match.
///
/// A capturing move can force a multi-jump chain (see [CheckersGame]).
/// [_applyMove] re-checks after every move -- including the Bot's own --
/// whether the mover must still be the Bot for a follow-up jump, so a
/// Bot's multi-jump chain plays out one hop at a time exactly like a
/// human's, rather than needing special-case handling here.
class CheckersMatchController extends ChangeNotifier {
  CheckersMatchController({
    required this.mode,
    CheckersGame? game,
    SimpleCheckersBotStrategy? botStrategy,
    this.botThinkDuration = const Duration(milliseconds: 350),
  })  : assert(mode == GameMode.local || mode == GameMode.bot),
        _game = game ?? CheckersGame(),
        _botStrategy = botStrategy ?? SimpleCheckersBotStrategy();

  final GameMode mode;
  final CheckersGame _game;
  final SimpleCheckersBotStrategy _botStrategy;
  final Duration botThinkDuration;

  Timer? _botTimer;
  var _isBotThinking = false;
  var _disposed = false;
  var _generation = 0;
  CheckersMove? _lastMove;

  CheckersGame get game => _game;
  bool get isBotMatch => mode == GameMode.bot;
  bool get isBotThinking => _isBotThinking;
  bool get supportsRevert => mode == GameMode.local;

  /// The most recently applied move (by either player, human or Bot), for
  /// the screen to animate. `null` right after a restart/revert, since
  /// those snap the board back rather than animating a move.
  CheckersMove? get lastMove => _lastMove;

  /// Whether a tap on the shared board may produce a move right now.
  bool get canAcceptLocalInput {
    if (_game.isGameOver || _isBotThinking) return false;
    return mode == GameMode.local ||
        _game.currentPlayer == CheckersPlayer.player1;
  }

  bool get canRevert =>
      supportsRevert && !_isBotThinking && _game.canRevert;

  /// Applies a board move if the active player is allowed to provide local input.
  bool submitLocalMove(int fromRow, int fromCol, int toRow, int toCol) {
    if (_disposed || !canAcceptLocalInput) return false;
    return _applyMove(fromRow, fromCol, toRow, toCol);
  }

  void restart() {
    if (_disposed) return;
    _cancelPendingBotMove();
    _generation++;
    _isBotThinking = false;
    _lastMove = null;
    _game.reset();
    _notifyIfActive();
  }

  void revert() {
    if (_disposed || !canRevert) return;
    _cancelPendingBotMove();
    _generation++;
    _lastMove = null;
    _game.revert();
    _notifyIfActive();
  }

  /// Mode-aware wording consumed by the shared result-screen presentation.
  String get redWinnerLabel =>
      isBotMatch ? 'BOT\nWINS!' : 'RED PLAYER\nWINS!';

  bool _applyMove(int fromRow, int fromCol, int toRow, int toCol) {
    final move = _game.tryMove(fromRow, fromCol, toRow, toCol);
    if (move == null) return false;

    _lastMove = move;
    _notifyIfActive();

    // True both when the turn just passed to the Bot, and when the Bot's
    // own move must continue a multi-jump chain (currentPlayer doesn't
    // change in that case) -- either way, the Bot needs to move next.
    if (isBotMatch &&
        !_game.isGameOver &&
        _game.currentPlayer == CheckersPlayer.player2) {
      _scheduleBotMove();
    }
    return true;
  }

  void _scheduleBotMove() {
    _isBotThinking = true;
    final generation = _generation;
    _botTimer = Timer(botThinkDuration, () {
      if (_disposed || generation != _generation) return;

      _botTimer = null;
      _isBotThinking = false;
      if (_game.isGameOver ||
          _game.currentPlayer != CheckersPlayer.player2) {
        _notifyIfActive();
        return;
      }

      final move = _botStrategy.chooseMove(_game);
      if (move != null) {
        _applyMove(move.$1, move.$2, move.$3, move.$4);
      } else {
        _notifyIfActive();
      }
    });
    _notifyIfActive();
  }

  void _cancelPendingBotMove() {
    _botTimer?.cancel();
    _botTimer = null;
  }

  void _notifyIfActive() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _cancelPendingBotMove();
    super.dispose();
  }
}
