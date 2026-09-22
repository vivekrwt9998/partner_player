import 'package:flutter/material.dart';

/// Overall availability state of a game.
enum GameStatus {
  available,
  comingSoon,
}

/// How local players physically interact with a shared device while playing
/// a game offline (see AGENTS.md §7). This is distinct from the game's
/// visual/board layout orientation (see §8): a game may look landscape-style
/// while still being played with the device lying flat between two players.
enum LocalInteractionType {
  /// Both players interact with the device while it stays in place between
  /// them (e.g. resting on a table), each reaching in from their own side.
  sharedDevice,

  /// The single device is physically handed from player to player after
  /// each turn.
  passAndPlay,
}

/// A game's own preferred board/UI composition — independent of the
/// physical device orientation, which must never be forced (AGENTS.md §8).
///
/// None of these values ever mean rotating the physical device or rotating
/// rendered pixels:
/// * [fixedLandscape] — the game's composition always stays landscape-shaped
///   (wide), fit/scaled to whatever space it is given. A portrait phone
///   still renders the same landscape composition, simply narrower; it is
///   never flipped into a portrait-shaped layout and never rotated.
/// * [fixedPortrait] — the mirror case: composition always stays
///   portrait-shaped (tall), regardless of device orientation.
/// * [adaptive] — the game's own build logic chooses a different
///   composition depending on the device's current orientation, and its
///   state must survive that change (see AGENTS.md §8.4).
///
/// Deliberately has no default value: every game must declare this
/// intentionally (see AGENTS.md §72).
enum GameOrientationBehavior {
  fixedLandscape,
  fixedPortrait,
  adaptive,
}

/// Physical placement/behavior of a game's turn indicator(s), driven by its
/// [LocalInteractionType] rather than hardcoded per game (see AGENTS.md
/// §10.1.4 / §10.1.6). Rendered by the reusable `TurnIndicatorOverlay`.
enum TurnIndicatorLayout {
  /// Players positioned on their own left/right side of the game layout.
  /// One mirrored corner badge per player, anchored bottom-left/bottom-right;
  /// only the active player's badge is shown. Left text is left-aligned,
  /// right text is right-aligned.
  sideBySide,

  /// The phone is passed between players; a single indicator tracks
  /// whichever player is currently active, anchored bottom-center.
  passAndPlay,

  /// Players are positioned opposite each other (one near the top of the
  /// layout, one near the bottom). One curved badge per player, anchored to
  /// their own side; each shows/hides with its own player's turn.
  faceToFace,

  /// The game has no turns at all: both players act on the board at the
  /// same time, continuously (Sling Puck). There is nothing to indicate, so
  /// `TurnIndicatorOverlay` renders nothing and the game shows its own live
  /// status instead.
  ///
  /// This is the one exception to "a turn indicator is required"
  /// (AGENTS.md §10.1.3), and it is spelled out here rather than left as a
  /// game quietly skipping the overlay.
  simultaneous,
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
  final LocalInteractionType localInteractionType;
  final TurnIndicatorLayout turnIndicatorLayout;
  final GameOrientationBehavior orientationBehavior;

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
    this.localInteractionType = LocalInteractionType.sharedDevice,
    this.turnIndicatorLayout = TurnIndicatorLayout.sideBySide,
    required this.orientationBehavior,
  });
}
