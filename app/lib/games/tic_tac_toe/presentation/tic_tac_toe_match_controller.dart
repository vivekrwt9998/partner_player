import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/game_definition.dart';
import '../bot/simple_tic_tac_toe_bot_strategy.dart';
import '../logic/tic_tac_toe_game.dart';
import '../models/tic_tac_toe_models.dart';

/// Coordinates a single local or Bot Tic Tac Toe match.
///
/// Unlike Four in a Row's falling disc, a mark is placed instantly, so this
/// controller applies a move and (for Bot matches) schedules the opponent's
/// reply directly, with no separate animation-completion signal needed from
/// the screen.
class TicTacToeMatchController extends ChangeNotifier {
  TicTacToeMatchController({
    required this.mode,
    TicTacToeGame? game,
    SimpleTicTacToeBotStrategy? botStrategy,
    this.botThinkDuration = const Duration(milliseconds: 350),
  })  : assert(mode == GameMode.local || mode == GameMode.bot),
        _game = game ?? TicTacToeGame(),
        _botStrategy = botStrategy ?? SimpleTicTacToeBotStrategy();

  final GameMode mode;
  final TicTacToeGame _game;
  final SimpleTicTacToeBotStrategy _botStrategy;
  final Duration botThinkDuration;

  Timer? _botTimer;
  var _isBotThinking = false;
  var _disposed = false;
  var _generation = 0;

  TicTacToeGame get game => _game;
  bool get isBotMatch => mode == GameMode.bot;
  bool get isBotThinking => _isBotThinking;
  bool get supportsRevert => mode == GameMode.local;

  /// Whether a tap on the shared board may produce a move right now.
  bool get canAcceptLocalInput {
    if (_game.isGameOver || _isBotThinking) return false;
    return mode == GameMode.local ||
        _game.currentPlayer == TicTacToePlayer.player1;
  }

  bool get canRevert =>
      supportsRevert && !_isBotThinking && _game.canRevert;

  /// Applies a board tap if the active player is allowed to provide local input.
  bool submitLocalCell(int row, int col) {
    if (_disposed || !canAcceptLocalInput) return false;
    return _applyMove(row, col);
  }

  void restart() {
    if (_disposed) return;
    _cancelPendingBotMove();
    _generation++;
    _isBotThinking = false;
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

  bool _applyMove(int row, int col) {
    final move = _game.tryPlaceMark(row, col);
    if (move == null) return false;

    _notifyIfActive();

    if (isBotMatch &&
        !_game.isGameOver &&
        _game.currentPlayer == TicTacToePlayer.player2) {
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
          _game.currentPlayer != TicTacToePlayer.player2) {
        _notifyIfActive();
        return;
      }

      final cell = _botStrategy.chooseCell(_game);
      if (cell != null) {
        _applyMove(cell.$1, cell.$2);
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
