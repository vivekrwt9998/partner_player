import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/game_definition.dart';
import '../bot/simple_dots_and_boxes_bot_strategy.dart';
import '../logic/dots_and_boxes_game.dart';
import '../models/dots_and_boxes_models.dart';

/// Coordinates a single local or Bot Dots and Boxes match.
///
/// A line is drawn and whatever it closes is claimed in the same step,
/// so this controller only has to gate input, drive the bot, and hand
/// the screen the move it needs to animate.
///
/// Closing a box earns another go, so the bot can be due to draw several
/// times in a row. The post-move check handles that by asking who is to
/// play rather than assuming the turn alternated.
class DotsAndBoxesMatchController extends ChangeNotifier {
  DotsAndBoxesMatchController({
    required this.mode,
    DotsAndBoxesGame? game,
    SimpleDotsAndBoxesBotStrategy? botStrategy,
    this.botThinkDuration = const Duration(milliseconds: 450),
  })  : assert(mode == GameMode.local || mode == GameMode.bot),
        _game = game ?? DotsAndBoxesGame(),
        _botStrategy = botStrategy ?? SimpleDotsAndBoxesBotStrategy() {
    // Blue always opens, so there is nothing to schedule here -- but a
    // seeded game may already be Red's to draw.
    _maybeScheduleBotMove();
  }

  final GameMode mode;
  final DotsAndBoxesGame _game;
  final SimpleDotsAndBoxesBotStrategy _botStrategy;

  /// How long the bot appears to think before drawing.
  final Duration botThinkDuration;

  Timer? _botTimer;
  DotsAndBoxesMove? _lastMove;
  var _isBotThinking = false;
  var _presentationBusy = false;
  var _disposed = false;
  var _generation = 0;

  DotsAndBoxesGame get game => _game;

  bool get isBotMatch => mode == GameMode.bot;

  bool get isBotThinking => _isBotThinking;

  /// The move the screen is currently animating, or `null` after a
  /// revert or restart -- which is how the screen knows to snap rather
  /// than replay the line being drawn.
  DotsAndBoxesMove? get lastMove => _lastMove;

  bool get supportsRevert => mode == GameMode.local;

  /// Whether a tap on the board may produce a move right now.
  bool get canAcceptLocalInput {
    if (_disposed || _game.isGameOver || _isBotThinking) return false;
    return mode == GameMode.local ||
        _game.currentPlayer == DotsAndBoxesPlayer.player1;
  }

  bool get canRevert => supportsRevert && _game.canRevert;

  /// Told by the screen while a line is still drawing itself on.
  ///
  /// The bot will not start thinking until this clears, so its reply
  /// cannot land on top of the line the player is still watching appear.
  ///
  /// A caller with no animation to play (this controller's own tests)
  /// simply never sets it, and the bot answers as soon as it is due.
  void setPresentationBusy(bool busy) {
    if (_disposed || _presentationBusy == busy) return;
    _presentationBusy = busy;
    if (!busy) _maybeScheduleBotMove();
  }

  /// Draws a line for the current player. Returns whether the engine
  /// took it.
  bool submitLocalEdge(BoxEdge edge) {
    if (_disposed || !canAcceptLocalInput) return false;
    return _applyMove(edge);
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

  /// Mode-aware wording consumed by the shared result-screen
  /// presentation.
  String get redWinnerLabel => isBotMatch ? 'BOT\nWINS!' : 'RED PLAYER\nWINS!';

  bool _applyMove(BoxEdge edge) {
    final move = _game.tryDrawEdge(edge);
    if (move == null) return false;

    _lastMove = move;
    _notifyIfActive();
    _maybeScheduleBotMove();
    return true;
  }

  /// Asks whether the bot is the one to draw, rather than assuming the
  /// turn alternated -- after closing a box it is the bot's go again.
  ///
  /// Called again by [setPresentationBusy] once the line has finished
  /// drawing, which is what makes the bot wait its turn out visually as
  /// well as logically.
  void _maybeScheduleBotMove() {
    if (!isBotMatch ||
        _disposed ||
        _presentationBusy ||
        _game.isGameOver ||
        _game.currentPlayer != DotsAndBoxesPlayer.player2) {
      return;
    }

    _isBotThinking = true;
    final generation = _generation;
    _botTimer = Timer(botThinkDuration, () {
      if (_disposed || generation != _generation) return;

      _botTimer = null;
      _isBotThinking = false;
      if (_game.isGameOver ||
          _game.currentPlayer != DotsAndBoxesPlayer.player2) {
        _notifyIfActive();
        return;
      }

      final edge = _botStrategy.chooseEdge(_game);
      if (edge != null) {
        _applyMove(edge);
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
