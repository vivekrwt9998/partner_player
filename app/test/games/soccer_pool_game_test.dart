import 'package:app/games/soccer_pool/logic/soccer_pool_game.dart';
import 'package:app/games/soccer_pool/models/soccer_pool_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _p1 = SoccerPoolPlayer.player1;
const _p2 = SoccerPoolPlayer.player2;

void main() {
  group('Setup', () {
    test('five tokens a side, plus the ball, on a 1.0 x 1.58 pitch', () {
      final game = SoccerPoolGame();

      final tokens = game.pieces.where((p) => !p.isBall).toList();
      expect(tokens.length, 10);
      expect(tokens.where((p) => p.owner == _p1).length, 5);
      expect(tokens.where((p) => p.owner == _p2).length, 5);

      expect(game.ball.isBall, isTrue);
      expect(SoccerPoolGame.fieldWidth, 1.0);
      expect(SoccerPoolGame.fieldHeight, closeTo(1.58, 0.001));
    });

    test('player1 (Blue) defends the bottom goal, player2 (Red) the top', () {
      final game = SoccerPoolGame();
      final blue = game.pieces.where((p) => p.owner == _p1).toList();
      final red = game.pieces.where((p) => p.owner == _p2).toList();

      for (final piece in blue) {
        expect(piece.position.y, greaterThan(SoccerPoolGame.fieldHeight / 2));
      }
      for (final piece in red) {
        expect(piece.position.y, lessThan(SoccerPoolGame.fieldHeight / 2));
      }
    });

    test('the ball starts in the centre, idle, with player1 to move first', () {
      final game = SoccerPoolGame();
      final ball = game.ball;
      expect(ball.position.x, closeTo(0.5, 0.001));
      expect(ball.position.y, closeTo(SoccerPoolGame.fieldHeight / 2, 0.001));
      expect(ball.velocity.x, 0);
      expect(ball.velocity.y, 0);
      expect(game.currentPlayer, _p1);
      expect(game.canShoot, isTrue);
    });

    test('no two pieces start on top of each other', () {
      final game = SoccerPoolGame();
      final pieces = game.pieces;
      for (var i = 0; i < pieces.length; i++) {
        for (var j = i + 1; j < pieces.length; j++) {
          final dx = pieces[i].position.x - pieces[j].position.x;
          final dy = pieces[i].position.y - pieces[j].position.y;
          final distanceSquared = (dx * dx) + (dy * dy);
          final radii = (pieces[i].isBall
                  ? SoccerPoolGame.ballRadius
                  : SoccerPoolGame.tokenRadius) +
              (pieces[j].isBall
                  ? SoccerPoolGame.ballRadius
                  : SoccerPoolGame.tokenRadius);
          expect(distanceSquared, greaterThanOrEqualTo(radii * radii));
        }
      }
    });
  });

  group('Shooting', () {
    test('only the current player can shoot, and only with their own token',
        () {
      final game = SoccerPoolGame();
      final ownToken = game.pieces
          .firstWhere((p) => !p.isBall && p.owner == _p1);
      final opponentToken = game.pieces
          .firstWhere((p) => !p.isBall && p.owner == _p2);
      final shot = SoccerPoolVector(0, 0.5);

      expect(game.tryShoot(ownToken.id, shot), isTrue);

      // While a shot is in progress the player cannot start another.
      expect(game.canShoot, isFalse);

      // Reset for the second half of the check.
      game.reset();

      // A token belonging to the opponent cannot be shot by player1.
      expect(game.tryShoot(opponentToken.id, shot), isFalse);
    });

    test('turn passes to the opponent after a shot comes to rest', () {
      final game = SoccerPoolGame();
      final ownToken = game.pieces
          .firstWhere((p) => !p.isBall && p.owner == _p1);

      expect(game.tryShoot(ownToken.id, SoccerPoolVector(0.2, 0.2)), isTrue);

      // Run the solver until the shot is settled, or give up after a few
      // seconds of simulated time.
      var elapsed = 0.0;
      while (elapsed < 6 && (game.isMoving || game.canShoot)) {
        game.advance(0.02);
        elapsed += 0.02;
      }

      expect(game.isMoving, isFalse);
      expect(game.canShoot, isTrue);
      expect(game.currentPlayer, _p2);
    });
  });

  group('Reset', () {
    test('reset returns every piece to its starting position', () {
      final game = SoccerPoolGame();
      final before = game.pieces
          .map((p) => (id: p.id, x: p.position.x, y: p.position.y))
          .toList();

      game.tryShoot(
        game.pieces.firstWhere((p) => !p.isBall && p.owner == _p1).id,
        SoccerPoolVector(0.4, 0.4),
      );
      game.advance(0.4);

      game.reset();

      for (var i = 0; i < game.pieces.length; i++) {
        expect(game.pieces[i].id, before[i].id);
        expect(game.pieces[i].position.x, closeTo(before[i].x, 0.001));
        expect(game.pieces[i].position.y, closeTo(before[i].y, 0.001));
      }
      expect(game.currentPlayer, _p1);
      expect(game.blueScore, 0);
      expect(game.redScore, 0);
    });
  });
}