import 'package:app/games/air_hockey/logic/air_hockey_game.dart';
import 'package:app/games/air_hockey/models/air_hockey_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _blue = AirHockeyPlayer.player1;
const _red = AirHockeyPlayer.player2;

/// Runs the solver for [seconds] in frame-sized slices, the way the
/// screen's ticker does.
void _run(AirHockeyGame game, double seconds, {double frame = 1 / 60}) {
  var left = seconds;
  while (left > 0) {
    game.advance(left < frame ? left : frame);
    left -= frame;
  }
}

void main() {
  group('Setup', () {
    test('starts with the puck on the centre spot and nothing scored', () {
      final game = AirHockeyGame();

      expect(game.puck.x, closeTo(AirHockeyGame.tableWidth / 2, 1e-9));
      expect(game.puck.y, closeTo(AirHockeyGame.tableHeight / 2, 1e-9));
      expect(game.puck.isMoving, isFalse);
      expect(game.blueScore, 0);
      expect(game.redScore, 0);
      expect(game.status, AirHockeyGameStatus.playing);
      expect(game.isGameOver, isFalse);
      expect(game.winner, isNull);
      expect(game.goalCount, 0);
    });

    test('each mallet starts in its own half', () {
      final game = AirHockeyGame();

      expect(game.malletFor(_blue).y,
          greaterThan(AirHockeyGame.tableHeight / 2));
      expect(game.malletFor(_red).y, lessThan(AirHockeyGame.tableHeight / 2));
    });

    test('the table is a real one stood on its end', () {
      expect(AirHockeyGame.tableHeight / AirHockeyGame.tableWidth, 2);
      expect(AirHockeyGame.goalsToWin, 3);
    });
  });

  group('Steering a mallet', () {
    test('a mallet travels towards the finger rather than jumping to it', () {
      final game = AirHockeyGame();
      final mallet = game.malletFor(_blue);
      final startY = mallet.y;

      game.steerMallet(_blue, 0.2, 1.2);
      game.advance(1 / 60);

      expect(mallet.y, lessThan(startY), reason: 'it set off towards 1.2');
      expect(mallet.y, greaterThan(1.2),
          reason: 'but one frame is not enough to arrive');
      expect(mallet.speed, greaterThan(0));
    });

    test('a mallet cannot cross the centre line into the other half', () {
      final game = AirHockeyGame();

      // Blue reaches deep into Red's half.
      game.steerMallet(_blue, 0.5, 0.2);
      _run(game, 2);

      expect(
        game.malletFor(_blue).y,
        greaterThanOrEqualTo(
          (AirHockeyGame.tableHeight / 2) + AirHockeyGame.malletRadius - 1e-6,
        ),
      );

      // And Red the other way.
      game.steerMallet(_red, 0.5, 1.8);
      _run(game, 2);

      expect(
        game.malletFor(_red).y,
        lessThanOrEqualTo(
          (AirHockeyGame.tableHeight / 2) - AirHockeyGame.malletRadius + 1e-6,
        ),
      );
    });

    test('a mallet stays inside the side walls', () {
      final game = AirHockeyGame();

      game.steerMallet(_blue, -5, 1.5);
      _run(game, 2);
      expect(game.malletFor(_blue).x,
          closeTo(AirHockeyGame.malletRadius, 1e-6));

      game.steerMallet(_blue, 5, 1.5);
      _run(game, 2);
      expect(
        game.malletFor(_blue).x,
        closeTo(AirHockeyGame.tableWidth - AirHockeyGame.malletRadius, 1e-6),
      );
    });

    test('letting go stops the mallet where it stands', () {
      final game = AirHockeyGame();

      game.steerMallet(_blue, 0.2, 1.2);
      game.advance(1 / 60);
      final restingX = game.malletFor(_blue).x;

      game.releaseMallet(_blue);
      _run(game, 1);

      expect(game.malletFor(_blue).x, closeTo(restingX, 1e-9));
      expect(game.malletFor(_blue).speed, 0);
      expect(game.malletFor(_blue).isHeld, isFalse);
    });

    test('a shove sends the puck away from the mallet', () {
      final game = AirHockeyGame()
        ..debugConfigure(
          puckX: 0.5,
          puckY: 1.0,
          blueMalletX: 0.5,
          blueMalletY: 1.5,
          // Out of the way, or the puck rebounds off it mid-assertion.
          redMalletX: 0.1,
          redMalletY: 0.1,
        );

      // Blue drives up into the puck sitting on the centre spot.
      game.steerMallet(_blue, 0.5, 1.0);
      _run(game, 0.3);

      expect(game.puck.vy, lessThan(0),
          reason: 'the puck was knocked up the table, away from Blue');
      expect(game.puck.speed, greaterThan(0.1));
    });
  });

  group('Walls', () {
    test('the puck bounces off a side wall', () {
      final game = AirHockeyGame()
        ..debugConfigure(puckX: 0.5, puckY: 1.0, puckVx: -1.2);

      _run(game, 0.6);

      expect(game.puck.vx, greaterThan(0), reason: 'it came back off');
      expect(game.puck.x, greaterThanOrEqualTo(AirHockeyGame.puckRadius));
    });

    test('the puck bounces off an end wall away from the mouth', () {
      final game = AirHockeyGame()
        ..debugConfigure(puckX: 0.08, puckY: 1.0, puckVy: -1.4, blueMalletX: 0.1, blueMalletY: 1.9, redMalletX: 0.1, redMalletY: 0.1);

      _run(game, 1.2);

      expect(game.blueScore, 0, reason: 'nowhere near the mouth');
      expect(game.puck.y, greaterThan(0));
    });

    test('the puck never leaves the table along the sides', () {
      final game = AirHockeyGame()
        ..debugConfigure(puckX: 0.5, puckY: 1.0, puckVx: 2.6, puckVy: 0.4);

      _run(game, 3);

      expect(game.puck.x, greaterThanOrEqualTo(-1e-6));
      expect(game.puck.x, lessThanOrEqualTo(AirHockeyGame.tableWidth + 1e-6));
    });
  });

  group('Scoring', () {
    test('a puck through the far mouth is a goal for Blue', () {
      final game = AirHockeyGame()
        ..debugConfigure(puckX: 0.5, puckY: 0.6, puckVy: -1.5, blueMalletX: 0.1, blueMalletY: 1.9, redMalletX: 0.1, redMalletY: 0.1);

      _run(game, 1);

      expect(game.blueScore, 1);
      expect(game.redScore, 0);
      expect(game.lastScorer, _blue);
      expect(game.goalCount, 1);
    });

    test('a puck through the near mouth is a goal for Red', () {
      final game = AirHockeyGame()
        ..debugConfigure(puckX: 0.5, puckY: 1.4, puckVy: 1.5, blueMalletX: 0.1, blueMalletY: 1.9, redMalletX: 0.1, redMalletY: 0.1);

      _run(game, 1);

      expect(game.redScore, 1);
      expect(game.blueScore, 0);
      expect(game.lastScorer, _red);
    });

    test('a goal puts the puck back on the spot and holds play', () {
      final game = AirHockeyGame()
        ..debugConfigure(puckX: 0.5, puckY: 0.6, puckVy: -1.5, blueMalletX: 0.1, blueMalletY: 1.9, redMalletX: 0.1, redMalletY: 0.1);

      _run(game, 1);

      expect(game.puck.x, closeTo(AirHockeyGame.tableWidth / 2, 1e-9));
      expect(game.puck.y, closeTo(AirHockeyGame.tableHeight / 2, 1e-9));
      expect(game.puck.isMoving, isFalse);
      expect(game.isPaused, isTrue);
      expect(game.pauseRemaining, greaterThan(0));

      // Nothing stirs while the hold runs.
      final heldY = game.puck.y;
      _run(game, 0.4);
      expect(game.puck.y, closeTo(heldY, 1e-9));

      _run(game, AirHockeyGame.goalPauseSeconds);
      expect(game.isPaused, isFalse);
    });

    test('a puck past the line but wide of the mouth is no goal', () {
      // Nothing could ever travel here -- only being shoved can put it
      // there -- so it is put back on the table instead of counted.
      final game = AirHockeyGame()
        ..debugConfigure(
          puckX: 0.06,
          puckY: -0.02,
          blueMalletX: 0.5,
          blueMalletY: 1.9,
          redMalletX: 0.5,
          redMalletY: 0.1,
        );

      _run(game, 0.2);

      expect(game.blueScore, 0);
      expect(game.redScore, 0);
      expect(game.puck.y, greaterThanOrEqualTo(0));
      expect(game.puck.y, lessThanOrEqualTo(AirHockeyGame.tableHeight));
    });

    test('a striker pinning the puck in a corner does not score', () {
      // Blue drives its striker into its own bottom-left corner with
      // the puck trapped against the walls.
      final game = AirHockeyGame()
        ..debugConfigure(
          puckX: 0.08,
          puckY: 1.93,
          blueMalletX: 0.22,
          blueMalletY: 1.82,
          redMalletX: 0.5,
          redMalletY: 0.3,
        );

      game.steerMallet(_blue, 0, AirHockeyGame.tableHeight);
      _run(game, 2);

      expect(game.redScore, 0, reason: 'the corner is not a goal mouth');
      expect(game.blueScore, 0);
      expect(game.puck.x, greaterThanOrEqualTo(-1e-6));
      expect(game.puck.y, lessThanOrEqualTo(AirHockeyGame.tableHeight + 1e-6));
    });

    test('a striker can still shove the puck through the mouth', () {
      final game = AirHockeyGame()
        ..debugConfigure(
          puckX: 0.5,
          puckY: 1.86,
          blueMalletX: 0.5,
          blueMalletY: 1.6,
          redMalletX: 0.1,
          redMalletY: 0.1,
        );

      game.steerMallet(_blue, 0.5, AirHockeyGame.tableHeight);
      _run(game, 2);

      expect(game.redScore, 1,
          reason: 'pushing it in off the mouth is a real goal');
    });

    test('three goals takes the match', () {
      final game = AirHockeyGame()
        ..debugConfigure(
          blueScore: 2,
          puckX: 0.5,
          puckY: 0.6,
          puckVy: -1.5,
          blueMalletX: 0.1,
          blueMalletY: 1.9,
          redMalletX: 0.1,
          redMalletY: 0.1,
        );
      _run(game, 1);

      expect(game.blueScore, 3);
      expect(game.status, AirHockeyGameStatus.won);
      expect(game.winner, _blue);
      expect(game.isGameOver, isTrue);
    });

    test('a finished match ignores everything after it', () {
      final game = AirHockeyGame()
        ..debugConfigure(
          redScore: 2,
          puckX: 0.5,
          puckY: 1.4,
          puckVy: 1.5,
          blueMalletX: 0.1,
          blueMalletY: 1.9,
          redMalletX: 0.1,
          redMalletY: 0.1,
        );

      _run(game, 1);
      expect(game.winner, _red);

      final restingX = game.malletFor(_blue).x;
      game.steerMallet(_blue, 0.1, 1.9);
      _run(game, 1);

      expect(game.malletFor(_blue).x, closeTo(restingX, 1e-9),
          reason: 'steering does nothing once it is over');
      expect(game.redScore, 3, reason: 'and no more goals land');
    });
  });

  group('Keeping the simulation sane', () {
    test('the puck speed is capped however hard it is hit', () {
      final game = AirHockeyGame()
        ..debugConfigure(puckX: 0.5, puckY: 1.0, puckVx: 40, puckVy: 40);

      game.advance(1 / 60);

      expect(game.puck.speed,
          lessThanOrEqualTo(AirHockeyGame.maxPuckSpeed + 1e-6));
    });

    test('the puck eventually settles rather than creeping forever', () {
      final game = AirHockeyGame()
        ..debugConfigure(puckX: 0.5, puckY: 1.0, puckVx: 0.9);

      _run(game, 25);

      expect(game.puck.isMoving, isFalse);
    });

    test('a long stall is not replayed as a burst of catch-up steps', () {
      final game = AirHockeyGame()
        ..debugConfigure(puckX: 0.5, puckY: 1.0, puckVx: 0.5);

      // The app was backgrounded for five seconds.
      game.advance(5);

      expect(game.puck.x, lessThan(0.5 + (0.5 * 0.2)),
          reason: 'at most a tenth of a second of motion was applied');
    });

    test('reset clears the score and puts the table back', () {
      final game = AirHockeyGame()
        ..debugConfigure(blueScore: 2, redScore: 1, puckX: 0.2, puckY: 0.3)
        ..reset();

      expect(game.blueScore, 0);
      expect(game.redScore, 0);
      expect(game.goalCount, 0);
      expect(game.lastScorer, isNull);
      expect(game.status, AirHockeyGameStatus.playing);
      expect(game.puck.x, closeTo(AirHockeyGame.tableWidth / 2, 1e-9));
      expect(game.puck.y, closeTo(AirHockeyGame.tableHeight / 2, 1e-9));
    });
  });
}
