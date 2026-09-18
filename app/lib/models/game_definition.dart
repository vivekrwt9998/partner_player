import 'package:flutter/material.dart';

/// Overall availability state of a game.
enum GameStatus {
  available,
  comingSoon,
}

/// Supported gameplay modes across the platform.
enum GameMode {
  local,
  bot,
  online;

  /// Human-readable title for the mode.
  String get title => switch (this) {
        GameMode.local => 'Play with Local',
        GameMode.bot => 'Play with Bot',
        GameMode.online => 'Play Online',
      };

  /// Brief description explaining the mode.
  String get subtitle => switch (this) {
        GameMode.local => 'Pass & play or play side-by-side on this device',
        GameMode.bot => 'Challenge our AI bot to test your skills',
        GameMode.online => 'Match with friends or players worldwide',
      };

  /// Icon representing this mode.
  IconData get icon => switch (this) {
        GameMode.local => Icons.phone_android_rounded,
        GameMode.bot => Icons.smart_toy_rounded,
        GameMode.online => Icons.public_rounded,
      };
}

/// Immutable descriptor for a game definition in the catalog.
///
/// Contains all static metadata needed by the Game Lobby and generic
/// Game Details screens.
class GameDefinition {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String? imagePath;
  final int playerCount;
  final GameStatus status;
  final List<GameMode> supportedModes;
  final List<String> howToPlayRules;
  final List<String> tags;

  const GameDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.imagePath,
    required this.playerCount,
    required this.status,
    this.supportedModes = const [GameMode.local, GameMode.bot, GameMode.online],
    this.howToPlayRules = const [],
    this.tags = const [],
  });
}
