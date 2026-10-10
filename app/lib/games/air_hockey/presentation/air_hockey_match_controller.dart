import 'package:flutter/foundation.dart';

import '../../../models/game_definition.dart';
import '../bot/simple_air_hockey_bot_strategy.dart';
import '../logic/air_hockey_game.dart';
import '../models/air_hockey_models.dart';

/// Coordinates a single local or Bot Air Hockey match.
///
/// Air Hockey runs in real time rather than in turns, so this controller
/// is deliberately thin, the way Sling Puck's is: the screen owns a
/// ticker and pumps [advance] every frame, and fingers come straight
/// through [steer] and [release]. There is no turn to pass and, because
/// nothing happens in discrete moves, no Revert to offer.
///
/// In a Bot match the human always plays the near/bottom half and the
/// bot the far/top one. The bot is driven from the very same [advance],
/// through the very same public game API a finger uses -- it is not
/// given moves, it moves a hand.
class AirHockeyMatchController extends ChangeNotifier {
  AirHockeyMatchController({
    required this.mode,
    AirHockeyGame? game,
    SimpleAirHockeyBotStrategy? botStrategy,
  })  : assert(mode == GameMode.local || mode == GameMode.bot),
        _game = game ?? AirHockeyGame(),
        _botStrategy = mode == GameMode.bot
            ? (botStrategy ?? SimpleAirHockeyBotStrategy(player: botPlayer))
            : null {
    _botStrategy?.reset();
  }

  /// The half the bot plays in a Bot match.
  static const AirHockeyPlayer botPlayer = AirHockeyPlayer.player2;

  /// The half the human plays in a Bot match.
  static const AirHockeyPlayer humanPlayer = AirHockeyPlayer.player1;

  final GameMode mode;
  final AirHockeyGame _game;
  final SimpleAirHockeyBotStrategy? _botStrategy;
  var _disposed = false;

  AirHockeyGame get game => _game;

  bool get isBotMatch => mode == GameMode.bot;

  bool get canAcceptLocalInput => !_disposed && !_game.isGameOver;

  /// Whether a finger on [player]'s half should do anything. In a Bot
  /// match the far half belongs to the bot, so a stray finger there is
  /// ignored.
  bool canControl(AirHockeyPlayer player) {
    if (!canAcceptLocalInput) return false;
    return !isBotMatch || player == humanPlayer;
  }

  /// Nothing here happens in discrete moves, so there is nothing to take
  /// back (AGENTS.md §10.1.3).
  bool get supportsRevert => false;

  /// Mode-aware wording consumed by the shared result-screen
  /// presentation.
  String get redWinnerLabel => isBotMatch ? 'BOT\nWINS!' : 'RED PLAYER\nWINS!';

  /// Runs the bot's hand, then feeds [dt] real seconds into the
  /// fixed-step solver. Returns `true` on the frame the match is won, so
  /// the screen can start its result transition.
  bool advance(double dt) {
    if (_disposed) return false;

    final wasOver = _game.isGameOver;
    _botStrategy?.update(_game, dt);
    _game.advance(dt);

    if (!wasOver && _game.isGameOver) {
      _notifyIfActive();
      return true;
    }
    return false;
  }

  /// Points [player]'s mallet at ([x], [y]) in table units.
  void steer(AirHockeyPlayer player, double x, double y) {
    if (!canControl(player)) return;
    _game.steerMallet(player, x, y);
  }

  /// Takes the finger off [player]'s mallet.
  void release(AirHockeyPlayer player) {
    if (_disposed || !canControl(player)) return;
    _game.releaseMallet(player);
  }

  void restart() {
    if (_disposed) return;
    _game.reset();
    _botStrategy?.reset();
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
