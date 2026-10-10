import 'package:app/games/air_hockey/logic/air_hockey_game.dart';
import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/air_hockey/air_hockey_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Walks the simulation clock on in frame-sized slices. Air Hockey's
/// ticker never stops while a match is live, so `pumpAndSettle` would
/// never settle.
Future<void> _run(WidgetTester tester, {int frames = 40}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _pumpGameScreen(
  WidgetTester tester, {
  GameMode mode = GameMode.local,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: AirHockeyScreen(mode: mode)));
  await _run(tester, frames: 3);
}

Finder _deck() => find.byKey(const ValueKey('air_hockey_deck'));
Finder _blueMallet() => find.byKey(const ValueKey('air_hockey_mallet_blue'));
Finder _redMallet() => find.byKey(const ValueKey('air_hockey_mallet_red'));

void main() {
  testWidgets('renders the table, both mallets and the puck',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(_deck(), findsOneWidget);
    expect(_blueMallet(), findsOneWidget);
    expect(_redMallet(), findsOneWidget);
    expect(find.byKey(const ValueKey('air_hockey_puck')), findsOneWidget);
  });

  testWidgets('the table keeps its 1:2 shape and fits the screen',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final table = tester.getRect(_deck());

    expect(table.height / table.width, closeTo(2, 0.01));
    expect(table.left, greaterThanOrEqualTo(-0.5));
    expect(table.right, lessThanOrEqualTo(390.5));
    expect(table.bottom, lessThanOrEqualTo(844.5));
  });

  testWidgets('each mallet starts in its own half',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final table = tester.getRect(_deck());
    final centreLine = table.center.dy;

    expect(tester.getCenter(_blueMallet()).dy, greaterThan(centreLine));
    expect(tester.getCenter(_redMallet()).dy, lessThan(centreLine));
  });

  testWidgets('both players can steer at the same time',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final table = tester.getRect(_deck());
    final blueStart = tester.getCenter(_blueMallet());
    final redStart = tester.getCenter(_redMallet());

    // One finger low on the left for Blue, one high on the right for Red,
    // both down at once.
    final blueFinger = await tester.startGesture(
      Offset(table.left + (table.width * 0.2), table.center.dy + 120),
      pointer: 1,
    );
    final redFinger = await tester.startGesture(
      Offset(table.left + (table.width * 0.8), table.center.dy - 120),
      pointer: 2,
    );
    await _run(tester);

    final blueNow = tester.getCenter(_blueMallet());
    final redNow = tester.getCenter(_redMallet());

    expect(blueNow.dx, lessThan(blueStart.dx), reason: 'Blue went left');
    expect(redNow.dx, greaterThan(redStart.dx), reason: 'Red went right');

    await blueFinger.up();
    await redFinger.up();
    await _run(tester, frames: 5);
  });

  testWidgets('a finger in your own half cannot drag your mallet past '
      'the centre line', (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final table = tester.getRect(_deck());

    final finger = await tester.startGesture(
      Offset(table.center.dx, table.center.dy + 100),
      pointer: 1,
    );
    // Blue reaches deep into Red's half.
    await finger.moveTo(Offset(table.center.dx, table.top + 40));
    await _run(tester);

    expect(tester.getCenter(_blueMallet()).dy,
        greaterThan(table.center.dy),
        reason: 'it stopped at the halfway line');

    await finger.up();
    await _run(tester, frames: 5);
  });

  testWidgets('a finger that comes down in one half does not steal the '
      'other mallet', (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final table = tester.getRect(_deck());
    final redStart = tester.getCenter(_redMallet());

    final finger = await tester.startGesture(
      Offset(table.center.dx, table.center.dy + 100),
      pointer: 1,
    );
    await finger.moveTo(Offset(table.left + 30, table.top + 40));
    await _run(tester);

    expect(tester.getCenter(_redMallet()), redStart,
        reason: 'Red belongs to a finger that came down in Red half');

    await finger.up();
    await _run(tester, frames: 5);
  });

  testWidgets('the score chip starts at nothing each',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    String read(String side) => tester
        .widget<Text>(find.byKey(ValueKey('air_hockey_score_$side')))
        .data!;

    expect(read('blue'), '0');
    expect(read('red'), '0');
    expect(find.byKey(const ValueKey('air_hockey_goal_flash')), findsNothing);
  });

  testWidgets('a struck puck drags a streak behind it, a resting one does not',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final table = tester.getRect(_deck());
    expect(find.byKey(const ValueKey('air_hockey_puck_trail')), findsNothing,
        reason: 'nothing is moving yet');

    // Drive the blue striker up through the centre spot.
    final finger = await tester.startGesture(
      Offset(table.center.dx, table.center.dy + (table.height * 0.2)),
      pointer: 1,
    );
    await _run(tester, frames: 12);
    await finger.moveTo(Offset(table.center.dx, table.center.dy));
    await _run(tester, frames: 12);

    expect(find.byKey(const ValueKey('air_hockey_puck_trail')), findsOneWidget,
        reason: 'the puck was knocked away and is travelling');

    await finger.up();
    await _run(tester, frames: 5);
  });

  testWidgets('options menu offers Restart and Exit, never Revert',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await _run(tester, frames: 5);

    expect(find.text('Revert'), findsNothing,
        reason: 'nothing here happens in discrete moves to undo');
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Exit Game'), findsOneWidget);
  });

  testWidgets('Restart puts the mallets back home',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final table = tester.getRect(_deck());
    final blueStart = tester.getCenter(_blueMallet());

    final finger = await tester.startGesture(
      Offset(table.left + (table.width * 0.2), table.center.dy + 120),
      pointer: 1,
    );
    await _run(tester);
    await finger.up();
    expect(tester.getCenter(_blueMallet()).dx, lessThan(blueStart.dx));

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await _run(tester, frames: 5);
    await tester.tap(find.text('Restart'));
    await _run(tester, frames: 5);

    expect(tester.getCenter(_blueMallet()).dx, closeTo(blueStart.dx, 0.5));
  });

  group('Bot mode', () {
    testWidgets('the far striker moves on its own, and a finger there does '
        'nothing', (WidgetTester tester) async {
      await _pumpGameScreen(tester, mode: GameMode.bot);

      final table = tester.getRect(_deck());
      final redStart = tester.getCenter(_redMallet());

      // A finger parked deep in the bot's half.
      final finger = await tester.startGesture(
        Offset(table.left + 20, table.top + 20),
        pointer: 1,
      );
      await _run(tester, frames: 40);

      final redNow = tester.getCenter(_redMallet());
      expect(redNow, isNot(redStart), reason: 'the bot is playing');
      expect((redNow - Offset(table.left + 20, table.top + 20)).distance,
          greaterThan(20),
          reason: 'but it did not follow the finger');

      await finger.up();
      await _run(tester, frames: 5);
    });

    testWidgets('the options menu still offers no Revert',
        (WidgetTester tester) async {
      await _pumpGameScreen(tester, mode: GameMode.bot);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await _run(tester, frames: 5);

      expect(find.text('Revert'), findsNothing);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Exit Game'), findsOneWidget);
    });
  });

  testWidgets('the first to three goals ends the match',
      (WidgetTester tester) async {
    // Driving three real goals with fingers would be a flaky way to ask
    // a very simple question, so the engine is handed the position and
    // the screen is asked what it does with it.
    expect(AirHockeyGame.goalsToWin, 3);

    final game = AirHockeyGame()
      ..debugConfigure(
        blueScore: 2,
        puckX: 0.5,
        puckY: 0.4,
        puckVy: -1.5,
        blueMalletX: 0.1,
        blueMalletY: 1.9,
        redMalletX: 0.1,
        redMalletY: 0.1,
      );

    for (var i = 0; i < 90; i++) {
      game.advance(1 / 60);
    }

    expect(game.blueScore, 3);
    expect(game.isGameOver, isTrue);
  });
}
