import 'package:flutter/material.dart';
import '../models/game_definition.dart';
import '../screens/games/four_in_a_row/four_in_a_row_screen.dart';

/// Centralized game routing and launch coordinator.
///
/// Decouples generic UI screens (like [GameDetailsScreen]) from knowing
/// specific game widget classes.
class GameLauncher {
  /// Determines if a specific [mode] is currently playable for [game].
  static bool isModeAvailable(GameDefinition game, GameMode mode) {
    if (game.status != GameStatus.available) return false;

    // Current phase: only Four in a Row + Local is fully playable offline
    return switch ((game.id, mode)) {
      ('four_in_a_row', GameMode.local) => true,
      _ => false,
    };
  }

  /// Launches the game screen for the specified [game] and [mode].
  ///
  /// If the mode is not yet available, shows a user-friendly feedback message.
  static void launch(BuildContext context, GameDefinition game, GameMode mode) {
    if (!isModeAvailable(game, mode)) {
      final modeName = switch (mode) {
        GameMode.local => 'Local mode',
        GameMode.bot => 'Bot mode',
        GameMode.online => 'Online mode',
      };

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$modeName is coming soon!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final screen = _resolveScreen(game.id, mode);
    if (screen != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
    }
  }

  /// Resolves game ID and mode pair to its corresponding gameplay screen.
  static Widget? _resolveScreen(String gameId, GameMode mode) {
    return switch ((gameId, mode)) {
      ('four_in_a_row', GameMode.local) => const FourInARowScreen(),
      _ => null,
    };
  }
}
