import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/game_definition.dart';
import '../bot/simple_hex_bot_strategy.dart';
import '../logic/hex_game.dart';
import '../models/hex_models.dart';

/// Coordinates a single local or Bot Hex match.
///
/// A Hex turn is one stone and nothing else -- no capture, no cascade,
/// no pass -- so this controller only has to gate input, drive the bot,
/// and hand the screen the move it needs to animate.
class HexMatchController extends ChangeNotifier {
  HexMatchController({
    required this.mode,
    HexGame? game,
    SimpleHexBotStrategy? botStrategy,
    this.botThinkDuration = const Duration(milliseconds: 450),
  })  : assert(mode == GameMode.local || mode == GameMode.bot),
        _game = game ?? HexGame(),
        _botStrategy = botStrategy ?? SimpleHexBotStrategy() {
    // Blue always opens, so there is nothing to schedule here -- but a
    // seeded game may already be Red's to play.
    _maybeScheduleBotMove();
  }

  final GameMode mode;
  final HexGame _game;
  final SimpleHexBotStrategy _botStrategy;

  /// How long the bot appears to think before playing.
  final Duration botThinkDuration;

  Timer? _botTimer;
  HexMove? _lastMove;
  var _isBotThinking = false;
  var _presentationBusy = false;
  var _disposed = false;
  var _generation = 0;

  HexGame get game => _game;

  bool get isBotMatch => mode == GameMode.bot;

  bool get isBotThinking => _isBotThinking;

  /// The move the screen is currently animating, or `null` after a
  /// revert or restart -- which is how the screen knows to snap rather
  /// than replay a stone landing.
  HexMove? get lastMove => _lastMove;

  bool get supportsRevert => mode == GameMode.local;

  /// Whether a tap on the board may produce a move right now.
  bool get canAcceptLocalInput {
    if (_disposed || _game.isGameOver || _isBotThinking) return false;
    return mode == GameMode.local ||
        _game.currentPlayer == HexPlayer.player1;
  }

  bool get canRevert => supportsRevert && _game.canRevert;

  /// Mode-aware wording consumed by the shared result-screen
  /// presentation.
  String get redWinnerLabel => isBotMatch ? 'BOT\nWINS!' : 'RED PLAYER\nWINS!';

  /// Told by the screen while a stone is still landing.
  ///
  /// The bot will not start thinking until this clears, so its reply
  /// cannot appear on top of the stone the player is still watching
  /// arrive.
  ///
  /// A caller with no animation to play (this controller's own tests)
  /// simply never sets it, and the bot answers as soon as it is due.
  void setPresentationBusy(bool busy) {
    if (_disposed || _presentationBusy == busy) return;
    _presentationBusy = busy;
    if (!busy) _maybeScheduleBotMove();
  }

  /// Places a stone for the current player. Returns whether the engine
  /// took it.
  bool submitLocalMove(int row, int col) {
    if (!canAcceptLocalInput) return false;
    return _applyMove(row, col);
  }

  void restart() {
    if (_disposed) return;
    _cancelPendingBotMove();
    _generation++;
    _isBotThinking = false;
    _lastMove = null;
    _game.reset();
    _notifyIfActive();
    _maybeScheduleBotMove();
  }

  void revert() {
    if (_disposed || !canRevert) return;
    _cancelPendingBotMove();
    _generation++;
    _isBotThinking = false;
    _lastMove = null;
    _game.revert();
    _notifyIfActive();
  }

  bool _applyMove(int row, int col) {
    final move = _game.tryPlace(row, col);
    if (move == null) return false;

    _lastMove = move;
    _notifyIfActive();
    _maybeScheduleBotMove();
    return true;
  }

  /// Asks whether the bot is the one to play rather than assuming the
  /// turn alternated, so a seeded or reverted board is handled the same
  /// way as an ordinary one.
  ///
  /// Called again by [setPresentationBusy] once the stone has finished
  /// landing, which is what makes the bot wait its turn out visually as
  /// well as logically.
  void _maybeScheduleBotMove() {
    if (!isBotMatch ||
        _disposed ||
        _presentationBusy ||
        _game.isGameOver ||
        _game.currentPlayer != HexPlayer.player2) {
      return;
    }

    _isBotThinking = true;
    final generation = _generation;
    _botTimer = Timer(botThinkDuration, () {
      if (_disposed || generation != _generation) return;

      _botTimer = null;
      _isBotThinking = false;
      if (_game.isGameOver || _game.currentPlayer != HexPlayer.player2) {
        _notifyIfActive();
        return;
      }

      final cell = _botStrategy.chooseCell(_game);
      if (cell != null) {
        _applyMove(cell.row, cell.col);
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
