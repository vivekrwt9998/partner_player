import 'package:app/data/games_registry.dart';
import 'package:app/models/game_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Soccer Pool is fixedPortrait with the faceToFace indicator', () {
    final soccerPool = kGames.firstWhere((g) => g.id == 'soccer_pool');

    expect(
      soccerPool.orientationBehavior,
      GameOrientationBehavior.fixedPortrait,
    );
    expect(soccerPool.turnIndicatorLayout, TurnIndicatorLayout.faceToFace);
    expect(
      soccerPool.localInteractionType,
      LocalInteractionType.sharedDevice,
    );
    expect(soccerPool.status, GameStatus.available);
    expect(soccerPool.playerCount, 2);
  });
}