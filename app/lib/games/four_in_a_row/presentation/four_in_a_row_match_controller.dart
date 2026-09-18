import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/game_definition.dart';
import '../bot/simple_four_in_a_row_bot_strategy.dart';
import '../logic/four_in_a_row_game.dart';
import '../models/four_in_a_row_models.dart';

/// Coordinates a single local or Bot Four in a Row match.
///
/// This class owns game sequencing, while the screen continues to own all
/// rendering and animation. A move stays active until the screen confirms its
/// falling-disc animation has completed.
class FourInARowMatchController extends ChangeNotifier {
  FourInARowMatchController({
    required this.mode,
    FourInARowGame? game,
    SimpleFourInARowBotStrategy? botStrategy,
    this.botThinkDuration = const Duration(milliseconds: 350),
  })  : assert(mode == GameMode.local || mode == GameMode.bot),
        _game = game ?? FourInARowGame(),
        _botStrategy = botStrategy ?? SimpleFourInARowBotStrategy();

  final GameMode mode;
  final FourInARowGame _game;
  final SimpleFourInARowBotStrategy _botStrategy;
  final Duration botThinkDuration;

  Timer? _botTimer;
  FourInARowMove? _activeMove;
  var _isBotThinking = false;
  var _isResultReady = false;
  var _disposed = false;
  var _generation = 0;

  FourInARowGame get game => _game;
  FourInARowMove? get activeMove => _activeMove;
  bool get isMoveAnimating => _activeMove != null;
  bool get isBotMatch => mode == GameMode.bot;
  bool get isBotThinking => _isBotThinking;
  bool get isResultReady => _isResultReady;
  bool get supportsRevert => mode == GameMode.local;

  /// Whether a tap on the shared board may produce a move right now.
  bool get canAcceptLocalInput {
    if (_game.isGameOver || isMoveAnimating || _isBotThinking) return false;
    return mode == GameMode.local ||
        _game.currentPlayer == FourInARowPlayer.player1;
  }

  bool get canRevert =>
      supportsRevert &&
      !_isBotThinking &&
      !isMoveAnimating &&
      !_isResultReady &&
      _game.canRevert;

  /// Applies a board tap if the active player is allowed to provide local input.
  bool submitLocalColumn(int column) {
    if (_disposed || !canAcceptLocalInput) return false;
    return _applyMove(column);
  }

  /// Signals that the UI has completed the animation for [activeMove].
  void onMoveAnimationCompleted() {
    if (_disposed || _activeMove == null) return;

    _activeMove = null;
    if (_game.isGameOver) {
      _isResultReady = true;
      notifyListeners();
      return;
    }

    if (isBotMatch && _game.currentPlayer == FourInARowPlayer.player2) {
      _scheduleBotMove();
      return;
    }

    notifyListeners();
  }

  void restart() {
    if (_disposed) return;
    _cancelPendingBotMove();
    _generation++;
    _activeMove = null;
    _isBotThinking = false;
    _isResultReady = false;
    _game.reset();
    _notifyIfActive();
  }

  void revert() {
    if (_disposed || !canRevert) return;
    _cancelPendingBotMove();
    _generation++;
    _game.revert();
    _notifyIfActive();
  }

  /// Mode-aware wording consumed by the shared result-screen presentation.
  String get redWinnerLabel =>
      isBotMatch ? 'BOT\nWINS!' : 'RED PLAYER\nWINS!';

  bool _applyMove(int column) {
    final move = _game.tryDropDisc(column);
    if (move == null) return false;

    _activeMove = move;
    _isResultReady = false;
    _notifyIfActive();
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
          _game.currentPlayer != FourInARowPlayer.player2) {
        _notifyIfActive();
        return;
      }

      final column = _botStrategy.chooseColumn(_game);
      if (column != null) {
        _applyMove(column);
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
