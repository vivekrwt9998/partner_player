import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../models/game_definition.dart';
import '../logic/snakes_and_ladders_game.dart';
import '../models/snakes_and_ladders_models.dart';

/// Coordinates a single local Snakes and Ladders match.
///
/// The die lives here rather than in the engine, so the engine stays a
/// pure function of the rolls it is given and a test can hand it any
/// sequence it likes.
class SnakesAndLaddersMatchController extends ChangeNotifier {
  SnakesAndLaddersMatchController({
    required this.mode,
    SnakesAndLaddersGame? game,
    Random? random,
  })  : assert(mode == GameMode.local,
            'Snakes and Ladders only has its Local mode'),
        _game = game ?? SnakesAndLaddersGame(),
        _random = random ?? Random();

  final GameMode mode;
  final SnakesAndLaddersGame _game;
  final Random _random;
  var _disposed = false;

  SnakesAndLaddersGame get game => _game;

  /// The roll the screen is currently animating, or `null` after a
  /// restart -- which is how it knows to snap rather than replay one.
  SnakesAndLaddersMove? get lastMove => _game.lastMove;

  bool get canAcceptLocalInput => !_disposed && !_game.isGameOver;

  /// Nothing here is a decision to take back. Undoing a roll would not
  /// return a choice to the player, it would hand them a second go at
  /// the die, so Revert is left out rather than shown disabled
  /// (AGENTS.md §10.1.9).
  bool get supportsRevert => false;

  /// Mode-aware wording consumed by the shared result-screen
  /// presentation. A getter rather than a constant because a Bot match
  /// will say BOT WINS here once that mode exists.
  String get redWinnerLabel => 'RED PLAYER\nWINS!';

  /// Rolls the die for the player to move and applies it. Returns the
  /// move, or `null` if the board would not take a roll.
  SnakesAndLaddersMove? rollDice() {
    if (!canAcceptLocalInput) return null;

    final move = _game.applyRoll(_random.nextInt(6) + 1);
    if (move == null) return null;

    _notifyIfActive();
    return move;
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
