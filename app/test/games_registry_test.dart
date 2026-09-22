import 'package:app/data/games_registry.dart';
import 'package:app/models/game_definition.dart';
import 'package:app/navigation/game_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

/// `GameDefinition.orientationBehavior` has no default value (AGENTS.md
/// §72): every registered game must declare it intentionally. These tests
/// exist mainly so this file itself proves the field is required — it would
/// fail to compile if any [kGames] entry omitted it — and pin down the
/// current, deliberate values for each game.
void main() {
  GameDefinition gameById(String id) => kGames.firstWhere((g) => g.id == id);

  test('every registered game declares an explicit orientationBehavior', () {
    // Merely compiling this file (kGames is a `const` list) already proves
    // every entry supplied the required field; this just makes the
    // assertion explicit and gives a readable failure if a value changes.
    for (final game in kGames) {
      expect(
        game.orientationBehavior,
        isA<GameOrientationBehavior>(),
        reason: '${game.id} must declare orientationBehavior',
      );
    }
  });

  test('Four in a Row is fixedLandscape with the sideBySide indicator', () {
    final fourInARow = gameById('four_in_a_row');
    expect(
      fourInARow.orientationBehavior,
      GameOrientationBehavior.fixedLandscape,
    );
    expect(fourInARow.turnIndicatorLayout, TurnIndicatorLayout.sideBySide);
    expect(
      fourInARow.localInteractionType,
      LocalInteractionType.sharedDevice,
    );
  });

  test('Tic Tac Toe is fixedPortrait with the faceToFace indicator', () {
    final ticTacToe = gameById('tic_tac_toe');
    expect(
      ticTacToe.orientationBehavior,
      GameOrientationBehavior.fixedPortrait,
    );
    expect(ticTacToe.turnIndicatorLayout, TurnIndicatorLayout.faceToFace);
    expect(
      ticTacToe.localInteractionType,
      LocalInteractionType.sharedDevice,
    );
    expect(ticTacToe.status, GameStatus.available);
  });

  test('Checkers is fixedPortrait with the faceToFace indicator', () {
    final checkers = gameById('checkers');
    expect(
      checkers.orientationBehavior,
      GameOrientationBehavior.fixedPortrait,
    );
    expect(checkers.turnIndicatorLayout, TurnIndicatorLayout.faceToFace);
    expect(
      checkers.localInteractionType,
      LocalInteractionType.sharedDevice,
    );
    expect(checkers.status, GameStatus.available);
  });

  test('Tetra Tower is fixedPortrait with the faceToFace indicator', () {
    final tetraTower = gameById('tetra_tower');
    expect(
      tetraTower.orientationBehavior,
      GameOrientationBehavior.fixedPortrait,
    );
    expect(tetraTower.turnIndicatorLayout, TurnIndicatorLayout.faceToFace);
    expect(
      tetraTower.localInteractionType,
      LocalInteractionType.sharedDevice,
    );
    expect(tetraTower.status, GameStatus.available);
  });

  test('Sling Puck is fixedPortrait and, uniquely, has no turns', () {
    final slingPuck = gameById('sling_puck');
    expect(
      slingPuck.orientationBehavior,
      GameOrientationBehavior.fixedPortrait,
    );
    // Both players scrabble at the board at once, so there is no turn to
    // indicate. This is the platform's one exception to AGENTS.md §10.1.3
    // and it is declared here rather than quietly skipped by the screen.
    expect(slingPuck.turnIndicatorLayout, TurnIndicatorLayout.simultaneous);
    expect(
      slingPuck.localInteractionType,
      LocalInteractionType.sharedDevice,
    );
    expect(slingPuck.status, GameStatus.available);
  });

  test('Sling Puck is the only game without turns', () {
    final simultaneous = kGames
        .where((g) => g.turnIndicatorLayout == TurnIndicatorLayout.simultaneous)
        .map((g) => g.id)
        .toList();
    expect(simultaneous, ['sling_puck']);
  });

  test('Color War is fixedPortrait with the faceToFace indicator', () {
    final colorWar = gameById('color_war');
    expect(
      colorWar.orientationBehavior,
      GameOrientationBehavior.fixedPortrait,
    );
    expect(colorWar.turnIndicatorLayout, TurnIndicatorLayout.faceToFace);
    expect(
      colorWar.localInteractionType,
      LocalInteractionType.sharedDevice,
    );
    expect(colorWar.status, GameStatus.available);
  });

  test('Color War offers both its offline modes, but not Online yet', () {
    final colorWar = gameById('color_war');

    expect(GameLauncher.isModeAvailable(colorWar, GameMode.local), isTrue);
    expect(GameLauncher.isModeAvailable(colorWar, GameMode.bot), isTrue);
    expect(GameLauncher.isModeAvailable(colorWar, GameMode.online), isFalse);
  });

  test(
      'Battleship uses the adaptive placeholder pending its own gameplay '
      'screen', () {
    // Not a final product decision — see the comments in games_registry.dart.
    // Pinning this down so it changes deliberately, not silently, once the
    // game actually gets a screen designed.
    expect(
      gameById('battleship').orientationBehavior,
      GameOrientationBehavior.adaptive,
    );
  });

  test('Sling Puck offers both its offline modes, but not Online yet', () {
    final slingPuck = gameById('sling_puck');

    expect(GameLauncher.isModeAvailable(slingPuck, GameMode.local), isTrue);
    expect(GameLauncher.isModeAvailable(slingPuck, GameMode.bot), isTrue);
    expect(GameLauncher.isModeAvailable(slingPuck, GameMode.online), isFalse);
  });
}
