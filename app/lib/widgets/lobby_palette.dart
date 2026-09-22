import 'package:flutter/material.dart';

/// The lobby's cartoon palette.
///
/// The gameplay screens each own their board colours; this is the shared
/// set for the "outside the game" surfaces -- lobby backdrop, game cards,
/// their painted artwork and the bottom bar -- so they all read as one
/// bright, kid-facing world (AGENTS.md §9).
abstract final class LobbyPalette {
  /// Sky, top to bottom.
  static const Color skyTop = Color(0xFF63C6F5);
  static const Color skyBottom = Color(0xFFBFE9FF);

  /// Ground the boards sit on.
  static const Color grass = Color(0xFF6DBE45);
  static const Color grassDark = Color(0xFF4E9B31);

  /// Cartoon outline. Every shape is drawn with this so nothing floats.
  static const Color ink = Color(0xFF14325C);

  /// Chrome: the bottom bar, card borders and badges.
  static const Color navy = Color(0xFF1B2A44);
  static const Color navyLight = Color(0xFF2C405F);

  /// Accents.
  static const Color sun = Color(0xFFFFC42E);
  static const Color blue = Color(0xFF2E86E0);
  static const Color cyan = Color(0xFF3BB9F0);
  static const Color red = Color(0xFFE8453C);
  static const Color purple = Color(0xFF7A4DE8);
  static const Color cream = Color(0xFFF6E7C9);
  static const Color wood = Color(0xFFD9A868);
  static const Color woodDark = Color(0xFFA9743C);
}
