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

  test('only the real-time games declare no turns', () {
    // The AGENTS.md §10.1.3 exception is for games where both players act
    // on the board at the same time, continuously. Every other game owes
    // its players a turn indicator, so this list is deliberately short
    // and spelled out rather than left to drift.
    final simultaneous = kGames
        .where((g) => g.turnIndicatorLayout == TurnIndicatorLayout.simultaneous)
        .map((g) => g.id)
        .toList();
    expect(simultaneous, ['sling_puck', 'air_hockey']);
  });

  test('Air Hockey is fixedPortrait and, like Sling Puck, has no turns', () {
    final airHockey = gameById('air_hockey');

    expect(
      airHockey.orientationBehavior,
      GameOrientationBehavior.fixedPortrait,
    );
    expect(airHockey.turnIndicatorLayout, TurnIndicatorLayout.simultaneous);
    expect(airHockey.localInteractionType, LocalInteractionType.sharedDevice);
    expect(airHockey.status, GameStatus.available);
    expect(airHockey.playerCount, 2);
  });

  test('Air Hockey offers both its offline modes, but not Online yet', () {
    final airHockey = gameById('air_hockey');

    expect(airHockey.supportedModes,
        [GameMode.local, GameMode.bot, GameMode.online]);
    expect(GameLauncher.isModeAvailable(airHockey, GameMode.local), isTrue);
    expect(GameLauncher.isModeAvailable(airHockey, GameMode.bot), isTrue);
    expect(GameLauncher.isModeAvailable(airHockey, GameMode.online), isFalse);
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

  test('Reversi is fixedPortrait with the faceToFace indicator', () {
    final reversi = gameById('reversi');
    expect(
      reversi.orientationBehavior,
      GameOrientationBehavior.fixedPortrait,
    );
    expect(reversi.turnIndicatorLayout, TurnIndicatorLayout.faceToFace);
    expect(
      reversi.localInteractionType,
      LocalInteractionType.sharedDevice,
    );
    expect(reversi.status, GameStatus.available);
    expect(reversi.playerCount, 2);
  });

  test('Reversi offers both its offline modes, but not Online yet', () {
    final reversi = gameById('reversi');

    expect(reversi.supportedModes,
        [GameMode.local, GameMode.bot, GameMode.online]);
    expect(GameLauncher.isModeAvailable(reversi, GameMode.local), isTrue);
    expect(GameLauncher.isModeAvailable(reversi, GameMode.bot), isTrue);
    expect(GameLauncher.isModeAvailable(reversi, GameMode.online), isFalse);
  });

  test('Dots and Boxes is fixedPortrait with the faceToFace indicator', () {
    final dotsAndBoxes = gameById('dots_and_boxes');
    expect(
      dotsAndBoxes.orientationBehavior,
      GameOrientationBehavior.fixedPortrait,
    );
    expect(dotsAndBoxes.turnIndicatorLayout, TurnIndicatorLayout.faceToFace);
    expect(
      dotsAndBoxes.localInteractionType,
      LocalInteractionType.sharedDevice,
    );
    expect(dotsAndBoxes.status, GameStatus.available);
    expect(dotsAndBoxes.playerCount, 2);
  });

  test('Dots and Boxes offers both its offline modes, but not Online yet',
      () {
    final dotsAndBoxes = gameById('dots_and_boxes');

    expect(dotsAndBoxes.supportedModes,
        [GameMode.local, GameMode.bot, GameMode.online]);
    expect(GameLauncher.isModeAvailable(dotsAndBoxes, GameMode.local), isTrue);
    expect(GameLauncher.isModeAvailable(dotsAndBoxes, GameMode.bot), isTrue);
    expect(
        GameLauncher.isModeAvailable(dotsAndBoxes, GameMode.online), isFalse);
  });

  test('Hex is fixedPortrait with the faceToFace indicator', () {
    final hex = gameById('hex');
    expect(hex.orientationBehavior, GameOrientationBehavior.fixedPortrait);
    expect(hex.turnIndicatorLayout, TurnIndicatorLayout.faceToFace);
    expect(hex.localInteractionType, LocalInteractionType.sharedDevice);
    expect(hex.status, GameStatus.available);
    expect(hex.playerCount, 2);
  });

  test('Hex offers both its offline modes, but not Online yet', () {
    final hex = gameById('hex');

    expect(hex.supportedModes, [GameMode.local, GameMode.bot, GameMode.online]);
    expect(GameLauncher.isModeAvailable(hex, GameMode.local), isTrue);
    expect(GameLauncher.isModeAvailable(hex, GameMode.bot), isTrue);
    expect(GameLauncher.isModeAvailable(hex, GameMode.online), isFalse);
  });

  test('Snakes and Ladders is fixedPortrait with the faceToFace indicator',
      () {
    final snakes = gameById('snakes_and_ladders');

    expect(snakes.orientationBehavior, GameOrientationBehavior.fixedPortrait);
    expect(snakes.turnIndicatorLayout, TurnIndicatorLayout.faceToFace);
    expect(snakes.localInteractionType, LocalInteractionType.sharedDevice);
    expect(snakes.status, GameStatus.available);
    expect(snakes.playerCount, 2);
  });

  test('Snakes and Ladders offers only its Local mode so far', () {
    final snakes = gameById('snakes_and_ladders');

    expect(snakes.supportedModes,
        [GameMode.local, GameMode.bot, GameMode.online]);
    expect(GameLauncher.isModeAvailable(snakes, GameMode.local), isTrue);
    expect(GameLauncher.isModeAvailable(snakes, GameMode.bot), isFalse);
    expect(GameLauncher.isModeAvailable(snakes, GameMode.online), isFalse);
  });

  test('every catalogue entry is playable, in the lobby order', () {
    // Battleship was a placeholder with no gameplay screen and has been
    // taken out; the two games that still only have a Local mode sit at
    // the end. kGames order is the lobby order.
    expect(kGames.map((g) => g.id).toList(), [
      'four_in_a_row',
      'tic_tac_toe',
      'checkers',
      'sling_puck',
      'color_war',
      'reversi',
      'dots_and_boxes',
      'hex',
      'air_hockey',
      'soccer_pool',
      'tetra_tower',
      'snakes_and_ladders',
    ]);
    expect(kGames.every((g) => g.status == GameStatus.available), isTrue);
  });

  test('Sling Puck offers both its offline modes, but not Online yet', () {
    final slingPuck = gameById('sling_puck');

    expect(GameLauncher.isModeAvailable(slingPuck, GameMode.local), isTrue);
    expect(GameLauncher.isModeAvailable(slingPuck, GameMode.bot), isTrue);
    expect(GameLauncher.isModeAvailable(slingPuck, GameMode.online), isFalse);
  });
}
