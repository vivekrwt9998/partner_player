import 'package:app/games/soccer_pool/logic/soccer_pool_game.dart';
import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/soccer_pool/soccer_pool_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The screen's `_highlightController` repeats forever, so
/// `pumpAndSettle()` would never return; settle with a bounded number of
/// fixed-size pumps instead (same pattern as Checkers' and Sling Puck's own
/// perpetual-animation screens).
Future<void> _settle(WidgetTester tester) async {
  // The engine's own `advance()` clamps each call to at most 35ms of
  // simulated time (SoccerPoolGame._integrate's maxFrameTime), matching a
  // real ~60fps ticker. Pumping in big chunks would waste almost all of
  // each chunk, so step in small increments instead, covering the same
  // up-to-6-simulated-second budget the engine's own tests allow a shot to
  // come to rest (soccer_pool_game_test.dart).
  for (var i = 0; i < 240; i++) {
    await tester.pump(const Duration(milliseconds: 30));
  }
}

Future<void> _pumpGameScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    const MaterialApp(home: SoccerPoolScreen(mode: GameMode.local)),
  );
  await _settle(tester);
}

/// Converts a point in the engine's fixed 1 x 1.58 field-unit pitch into an
/// absolute screen coordinate.
///
/// Measured from the playing surface, not the framed box around it: the
/// white frame is drawn as a border and does not belong to the field, so
/// using the outer box would land every tap slightly off its piece.
Offset _fieldPoint(WidgetTester tester, double fieldX, double fieldY) {
  final pitch = tester.getRect(find.byKey(const ValueKey('soccer_pool_pitch')));
  final scale = pitch.width / SoccerPoolGame.fieldWidth;
  return pitch.topLeft + Offset(fieldX * scale, fieldY * scale);
}

double _opacityOfLabel(WidgetTester tester, String label) {
  final opacity = tester.widget<AnimatedOpacity>(
    find.ancestor(of: find.text(label), matching: find.byType(AnimatedOpacity)),
  );
  return opacity.opacity;
}

void main() {
  testWidgets('renders the pitch with every token and the ball',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    for (var id = 0; id <= 10; id++) {
      expect(find.byKey(ValueKey('soccer_pool_${id == 0 ? 'ball' : id}')),
          findsOneWidget);
    }
    expect(_opacityOfLabel(tester, 'BLUE'), 1.0);
    expect(_opacityOfLabel(tester, 'RED'), 0.0);
  });

  testWidgets(
      'a piece stays put while being pulled back -- only the release fires the shot',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    // Piece 9 (one of Blue's) sits at field point (0.50, 1.03).
    final pieceKey = find.byKey(const ValueKey('soccer_pool_9'));
    final originalCentre = tester.getCenter(pieceKey);

    final from = _fieldPoint(tester, 0.50, 1.03);
    final gesture = await tester.startGesture(from);
    await gesture.moveTo(_fieldPoint(tester, 0.50, 1.20));
    await tester.pump();

    // Still resting exactly where it started -- dragging never carries it.
    expect(tester.getCenter(pieceKey), originalCentre);

    await gesture.up();
    await _settle(tester);

    // The shot fired (and travelled somewhere), and the turn moved on.
    expect(tester.getCenter(pieceKey), isNot(equals(originalCentre)));
    expect(_opacityOfLabel(tester, 'RED'), 1.0);
    expect(_opacityOfLabel(tester, 'BLUE'), 0.0);
  });

  testWidgets('a negligible pull is ignored and does not consume the turn',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final pieceKey = find.byKey(const ValueKey('soccer_pool_9'));
    final originalCentre = tester.getCenter(pieceKey);

    final from = _fieldPoint(tester, 0.50, 1.03);
    final gesture = await tester.startGesture(from);
    await gesture.moveTo(_fieldPoint(tester, 0.505, 1.03));
    await gesture.up();
    await _settle(tester);

    expect(tester.getCenter(pieceKey), originalCentre);
    expect(_opacityOfLabel(tester, 'BLUE'), 1.0);
  });

  testWidgets('touching empty space (no piece underneath) does nothing',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final from = _fieldPoint(tester, 0.1, 0.1); // empty corner, no piece there
    final gesture = await tester.startGesture(from);
    await gesture.moveTo(_fieldPoint(tester, 0.3, 0.3));
    await gesture.up();
    await _settle(tester);

    expect(_opacityOfLabel(tester, 'BLUE'), 1.0);
  });

  testWidgets('the playing surface is exactly 1 : 1.58, frame excluded',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    // Both goal mouths are drawn flush with their own goal line, so the
    // surface has to be the engine's own shape. When the white frame was
    // taken out of the middle of it instead of added around it, the bottom
    // pair of markings ended up short of the line while the top pair sat
    // flush -- the two ends visibly disagreed.
    final pitch = tester.getRect(find.byKey(const ValueKey('soccer_pool_pitch')));
    expect(
      pitch.height / pitch.width,
      closeTo(SoccerPoolGame.fieldHeight / SoccerPoolGame.fieldWidth, 0.005),
    );
  });

  testWidgets('the further you pull back, the further the piece travels',
      (WidgetTester tester) async {
    // Token 7 sits on Blue's left with a clear run up the pitch, so the
    // two shots are compared on the same open lane.
    await _pumpGameScreen(tester);

    Future<double> pullAndMeasure(double pullLength) async {
      final token = find.byKey(const ValueKey('soccer_pool_7'));
      final before = tester.getCenter(token);

      final gesture = await tester.startGesture(_fieldPoint(tester, 0.28, 1.19));
      // Pulling down fires it up the pitch, away from the finger.
      await gesture.moveTo(_fieldPoint(tester, 0.28, 1.19 + pullLength));
      await gesture.up();
      await _settle(tester);

      return (tester.getCenter(token) - before).distance;
    }

    // Pumping the screen again would reuse the same State, leaving the
    // turn with Red, so the board is put back through Restart instead.
    Future<void> restart() async {
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pump();
      await tester.tap(find.text('Restart'));
      await _settle(tester);
    }

    final gentle = await pullAndMeasure(0.06);
    await restart();
    final hard = await pullAndMeasure(0.35);

    expect(gentle, greaterThan(0), reason: 'a real pull still fires');
    expect(hard, greaterThan(gentle * 1.8),
        reason: 'a long draw has to beat a nudge by more than noise');
  });

  testWidgets('options menu offers Restart and Exit, never Revert',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pump();

    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Exit Game'), findsOneWidget);
    expect(find.text('Revert'), findsNothing);
  });

  testWidgets('Restart from the options menu resets the pitch',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final pieceKey = find.byKey(const ValueKey('soccer_pool_9'));
    final originalCentre = tester.getCenter(pieceKey);

    final from = _fieldPoint(tester, 0.50, 1.03);
    final gesture = await tester.startGesture(from);
    await gesture.moveTo(_fieldPoint(tester, 0.50, 1.20));
    await gesture.up();
    await _settle(tester);
    expect(tester.getCenter(pieceKey), isNot(equals(originalCentre)));

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pump();
    await tester.tap(find.text('Restart'));
    await _settle(tester);

    expect(tester.getCenter(pieceKey), originalCentre);
    expect(_opacityOfLabel(tester, 'BLUE'), 1.0);
  });
}
