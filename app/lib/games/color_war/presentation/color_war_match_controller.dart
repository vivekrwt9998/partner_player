import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/game_definition.dart';
import '../bot/simple_color_war_bot_strategy.dart';
import '../logic/color_war_game.dart';
import '../models/color_war_models.dart';

/// Coordinates a single local or Bot Color War match.
///
/// Unlike the platform's other turn games, a move here is not over when the
/// orb lands: the chain reaction it sets off is resolved one wave at a
/// time, on a timer, so players can watch it spread. Everything that
/// depends on that -- when input reopens, when the turn passes, when the
/// bot replies -- is sequenced here rather than in the screen, so the
/// screen only ever renders the current board.
class ColorWarMatchController extends ChangeNotifier {
  ColorWarMatchController({
    required this.mode,
    ColorWarGame? game,
    SimpleColorWarBotStrategy? botStrategy,
    this.botThinkDuration = const Duration(milliseconds: 400),
    this.blastStepDuration = const Duration(milliseconds: 150),
  })  : assert(mode == GameMode.local || mode == GameMode.bot),
        _game = game ?? ColorWarGame(),
        _botStrategy = botStrategy ?? SimpleColorWarBotStrategy();

  final GameMode mode;
  final ColorWarGame _game;
  final SimpleColorWarBotStrategy _botStrategy;

  /// How long the bot appears to think before answering.
  final Duration botThinkDuration;

  /// How long one wave of a chain reaction is held on screen.
  final Duration blastStepDuration;

  Timer? _botTimer;
  Timer? _blastTimer;
  var _isBotThinking = false;
  var _disposed = false;
  var _generation = 0;

  List<ColorWarPosition> _burstingCells = const [];
  ColorWarPlayer? _burstingPlayer;
  var _burstTick = 0;

  ColorWarGame get game => _game;
  bool get isBotMatch => mode == GameMode.bot;
  bool get isBotThinking => _isBotThinking;
  bool get supportsRevert => mode == GameMode.local;

  /// Whether a chain reaction is still spreading across the board.
  bool get isReacting => _game.hasPendingBlasts;

  /// The cells bursting right now, held here for one [blastStepDuration]
  /// *before* the board is updated so the screen can throw orbs out of
  /// them. Empty whenever nothing is going off.
  List<ColorWarPosition> get burstingCells => _burstingCells;

  /// Whose orbs are flying, so they can be drawn in the right colour.
  ColorWarPlayer? get burstingPlayer => _burstingPlayer;

  /// Counts up once per burst. The screen restarts its animation when this
  /// changes, which two identical waves in a row would otherwise hide.
  int get burstTick => _burstTick;

  /// Whether a tap on the shared board may produce a move right now.
  bool get canAcceptLocalInput {
    if (_game.isGameOver || _isBotThinking || isReacting) return false;
    return mode == GameMode.local ||
        _game.currentPlayer == ColorWarPlayer.player1;
  }

  bool get canRevert => supportsRevert && !_isBotThinking && _game.canRevert;

  /// Applies a board tap if the active player is allowed to provide local
  /// input.
  bool submitLocalCell(int row, int col) {
    if (_disposed || !canAcceptLocalInput) return false;
    return _applyMove(row, col);
  }

  void restart() {
    if (_disposed) return;
    _cancelPendingWork();
    _generation++;
    _isBotThinking = false;
    _game.reset();
    _notifyIfActive();
  }

  void revert() {
    if (_disposed || !canRevert) return;
    _cancelPendingWork();
    _generation++;
    _isBotThinking = false;
    _game.revert();
    _notifyIfActive();
  }

  /// Mode-aware wording consumed by the shared result-screen presentation.
  String get redWinnerLabel => isBotMatch ? 'BOT\nWINS!' : 'RED PLAYER\nWINS!';

  bool _applyMove(int row, int col) {
    final move = _game.tryPlaceOrb(row, col);
    if (move == null) return false;

    _notifyIfActive();

    if (_game.hasPendingBlasts) {
      _scheduleNextBlast();
    } else {
      _maybeScheduleBotMove();
    }
    return true;
  }

  /// Resolves the cascade one wave per [blastStepDuration], so the reaction
  /// reads as something spreading rather than a board that teleported.
  ///
  /// The wave is announced first and applied when the timer fires, so the
  /// screen gets that whole window to show orbs flying out of the cells
  /// that are about to go, while the board still shows them full.
  void _scheduleNextBlast() {
    _burstingCells = _game.pendingBlasts;
    _burstingPlayer = _game.blastOwner;
    _burstTick++;
    _notifyIfActive();

    final generation = _generation;
    _blastTimer = Timer(blastStepDuration, () {
      if (_disposed || generation != _generation) return;

      _blastTimer = null;
      _burstingCells = const [];
      _burstingPlayer = null;
      _game.stepBlast();
      _notifyIfActive();

      if (_game.hasPendingBlasts) {
        _scheduleNextBlast();
      } else {
        _maybeScheduleBotMove();
      }
    });
  }

  void _maybeScheduleBotMove() {
    if (!isBotMatch ||
        _game.isGameOver ||
        _game.currentPlayer != ColorWarPlayer.player2) {
      return;
    }
    _scheduleBotMove();
  }

  void _scheduleBotMove() {
    _isBotThinking = true;
    final generation = _generation;
    _botTimer = Timer(botThinkDuration, () {
      if (_disposed || generation != _generation) return;

      _botTimer = null;
      _isBotThinking = false;
      if (_game.isGameOver ||
          _game.currentPlayer != ColorWarPlayer.player2 ||
          _game.hasPendingBlasts) {
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

  void _cancelPendingWork() {
    _botTimer?.cancel();
    _botTimer = null;
    _blastTimer?.cancel();
    _blastTimer = null;
    _burstingCells = const [];
    _burstingPlayer = null;
  }

  void _notifyIfActive() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _cancelPendingWork();
    super.dispose();
  }
}
