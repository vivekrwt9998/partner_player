import 'package:app/games/soccer_pool/models/soccer_pool_models.dart';
import 'package:app/games/soccer_pool/presentation/soccer_pool_match_controller.dart';
import 'package:app/models/game_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SoccerPoolMatchController', () {
    test('Local mode accepts shots and advances the engine', () {
      final controller =
          SoccerPoolMatchController(mode: GameMode.local);
      addTearDown(controller.dispose);

      final ownToken = controller.game.pieces
          .firstWhere((p) => !p.isBall && p.owner == SoccerPoolPlayer.player1);

      expect(controller.canAcceptLocalInput, isTrue);
      expect(
        controller.tryShoot(ownToken.id, const SoccerPoolVector(0.1, 0.1)),
        isTrue,
      );
      // While the shot is resolving, no new shot may be triggered.
      expect(controller.canAcceptLocalInput, isFalse);

      controller.advance(0.02);
    });

    test('Bot mode is rejected by the controller for now', () {
      expect(
        () => SoccerPoolMatchController(mode: GameMode.bot),
        throwsA(isA<AssertionError>()),
      );
    });

    test('restart resets the engine and re-enables input', () {
      final controller =
          SoccerPoolMatchController(mode: GameMode.local);
      addTearDown(controller.dispose);

      final ownToken = controller.game.pieces
          .firstWhere((p) => !p.isBall && p.owner == SoccerPoolPlayer.player1);

      controller.tryShoot(ownToken.id, const SoccerPoolVector(0.4, 0.4));
      controller.restart();

      expect(controller.canAcceptLocalInput, isTrue);
      expect(controller.game.currentPlayer, SoccerPoolPlayer.player1);
      expect(controller.game.blueScore, 0);
      expect(controller.game.redScore, 0);
    });
  });
}