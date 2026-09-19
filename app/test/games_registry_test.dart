import 'package:app/data/games_registry.dart';
import 'package:app/models/game_definition.dart';
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
}
