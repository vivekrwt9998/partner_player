import 'package:flutter/foundation.dart';

import '../../../models/game_definition.dart';
import '../bot/simple_sling_puck_bot_strategy.dart';
import '../logic/game_tuning.dart';
import '../logic/sling_puck_game.dart';
import '../models/sling_puck_models.dart';

/// Coordinates a single local or Bot Sling Puck match.
///
/// Sling Puck runs in real time rather than in turns, so this controller is
/// deliberately thin: the screen owns a ticker and pumps [advance] every
/// frame, and touches come straight through [grab], [moveHeld] and
/// [release]. There is no turn to pass and, because moves are not discrete,
/// no Revert to offer.
///
/// In a Bot match the human always plays the near/bottom half and the bot
/// the far/top one. The bot is driven from the very same [advance], through
/// the very same public game API a finger uses -- it is not given moves,
/// it moves a hand.
class SlingPuckMatchController extends ChangeNotifier {
  SlingPuckMatchController({
    required this.mode,
    SlingPuckGame? game,
    SimpleSlingPuckBotStrategy? botStrategy,
  })  : assert(mode == GameMode.local || mode == GameMode.bot),
        _game = game ?? SlingPuckGame(),
        _botStrategy = mode == GameMode.bot
            ? (botStrategy ?? SimpleSlingPuckBotStrategy(player: botPlayer))
            : null {
    _botStrategy?.reset();
  }

  /// The half the bot plays in a Bot match.
  static const SlingPuckPlayer botPlayer = SlingPuckPlayer.player2;

  /// The half the human plays in a Bot match.
  static const SlingPuckPlayer humanPlayer = SlingPuckPlayer.player1;

  final GameMode mode;
  final SlingPuckGame _game;
  final SimpleSlingPuckBotStrategy? _botStrategy;
  var _disposed = false;

  SlingPuckGame get game => _game;

  bool get isBotMatch => mode == GameMode.bot;

  /// The bot, for the debug overlay. `null` in a local match.
  SimpleSlingPuckBotStrategy? get botStrategy => _botStrategy;

  bool get canAcceptLocalInput => !_disposed && !_game.isGameOver;

  /// Whether a touch on [player]'s half should do anything. In a Bot match
  /// the far half belongs to the bot, so a stray finger there is ignored.
  bool canControl(SlingPuckPlayer player) {
    if (!canAcceptLocalInput) return false;
    return !isBotMatch || player == humanPlayer;
  }

  /// Swaps in new tuning values (the debug overlay's sliders).
  void applyTuning(GameTuning tuning) {
    if (_disposed) return;
    _game.tuning = tuning;
    _notifyIfActive();
  }

  /// Runs the bot's hand, then feeds [dt] real seconds into the fixed-step
  /// solver. Returns `true` on the frame the match is won, so the screen
  /// can start its result transition.
  ///
  /// Keeps running after the win so the field visibly comes to rest behind
  /// the result screen; it is [grab] that stops taking input.
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

  /// Takes hold of [pieceId] for [player]. Returns whether it worked.
  bool grab(int pieceId, SlingPuckPlayer player) {
    if (!canControl(player)) return false;
    return _game.grab(pieceId, player);
  }

  /// Carries [player]'s held piece to ([x], [y]) in field units.
  void moveHeld(SlingPuckPlayer player, double x, double y) {
    if (!canControl(player)) return;
    _game.moveHeld(player, x, y);
  }

  /// Lets go of [player]'s piece, flicking it at ([vx], [vy]) field units
  /// per second. Zero velocity simply puts it down.
  void release(SlingPuckPlayer player, {double vx = 0, double vy = 0}) {
    if (_disposed || (isBotMatch && player != humanPlayer)) return;
    _game.release(player, vx: vx, vy: vy);
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
