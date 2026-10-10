import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/game_definition.dart';
import '../bot/simple_reversi_bot_strategy.dart';
import '../logic/reversi_game.dart';
import '../models/reversi_models.dart';

/// Coordinates a single local or Bot Reversi match.
///
/// Reversi is turn-based and instant: a disc is laid and the capture is
/// resolved in the same step, so this controller only has to gate input,
/// drive the bot, and hand the screen the move it needs to animate. The
/// flip animation itself is the screen's business -- the board is
/// already in its final state by the time [lastMove] is read.
///
/// One Reversi-specific wrinkle: a player with no legal move is skipped,
/// so the bot can be due to play twice in a row. The post-move check
/// handles that for free by asking who is to move rather than assuming
/// the turn alternated.
class ReversiMatchController extends ChangeNotifier {
  ReversiMatchController({
    required this.mode,
    ReversiGame? game,
    SimpleReversiBotStrategy? botStrategy,
    this.botThinkDuration = const Duration(milliseconds: 450),
  })  : assert(mode == GameMode.local || mode == GameMode.bot),
        _game = game ?? ReversiGame(),
        _botStrategy = botStrategy ?? SimpleReversiBotStrategy() {
    // In a Bot match Blue always opens, so there is nothing to schedule
    // here -- but a seeded game may already be Red's to play.
    _maybeScheduleBotMove();
  }

  final GameMode mode;
  final ReversiGame _game;
  final SimpleReversiBotStrategy _botStrategy;

  /// How long the bot appears to think before answering.
  final Duration botThinkDuration;

  Timer? _botTimer;
  ReversiMove? _lastMove;
  var _isBotThinking = false;
  var _presentationBusy = false;
  var _disposed = false;
  var _generation = 0;

  ReversiGame get game => _game;

  bool get isBotMatch => mode == GameMode.bot;

  bool get isBotThinking => _isBotThinking;

  /// The move the screen is currently animating, or `null` after a
  /// revert or restart -- which is how the screen knows to snap rather
  /// than replay a flip.
  ReversiMove? get lastMove => _lastMove;

  bool get supportsRevert => mode == GameMode.local;

  /// Whether a tap on the board may produce a move right now.
  bool get canAcceptLocalInput {
    if (_disposed || _game.isGameOver || _isBotThinking) return false;
    return mode == GameMode.local ||
        _game.currentPlayer == ReversiPlayer.player1;
  }

  bool get canRevert => supportsRevert && _game.canRevert;

  /// Told by the screen while a move's flip is still playing out.
  ///
  /// The bot will not start thinking until this clears. The engine
  /// resolves a move the instant it is played, so without this the bot's
  /// reply could land while the previous capture was still turning over
  /// -- discs changing colour twice in the same breath, which reads as a
  /// flicker rather than as two moves.
  ///
  /// A caller with no animation to play (the controller's own tests)
  /// simply never sets it, and the bot answers as soon as it is due.
  void setPresentationBusy(bool busy) {
    if (_disposed || _presentationBusy == busy) return;
    _presentationBusy = busy;
    if (!busy) _maybeScheduleBotMove();
  }

  /// Lays a disc for the current player. Returns whether the engine took
  /// it.
  bool submitLocalMove(int row, int col) {
    if (_disposed || !canAcceptLocalInput) return false;
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

  /// Mode-aware wording consumed by the shared result-screen
  /// presentation.
  String get redWinnerLabel => isBotMatch ? 'BOT\nWINS!' : 'RED PLAYER\nWINS!';

  bool _applyMove(int row, int col) {
    final move = _game.tryPlace(row, col);
    if (move == null) return false;

    _lastMove = move;
    _notifyIfActive();
    _maybeScheduleBotMove();
    return true;
  }

  /// Asks whether the bot is the one to play, rather than assuming the
  /// turn alternated -- after a pass it can be the bot's turn again.
  ///
  /// Called again by [setPresentationBusy] once the board settles, which
  /// is what makes the bot wait its turn out visually as well as
  /// logically.
  void _maybeScheduleBotMove() {
    if (!isBotMatch ||
        _disposed ||
        _presentationBusy ||
        _game.isGameOver ||
        _game.currentPlayer != ReversiPlayer.player2) {
      return;
    }

    _isBotThinking = true;
    final generation = _generation;
    _botTimer = Timer(botThinkDuration, () {
      if (_disposed || generation != _generation) return;

      _botTimer = null;
      _isBotThinking = false;
      if (_game.isGameOver ||
          _game.currentPlayer != ReversiPlayer.player2) {
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
