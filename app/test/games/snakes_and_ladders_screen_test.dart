import 'package:app/games/snakes_and_ladders/logic/snakes_and_ladders_game.dart';
import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/snakes_and_ladders/snakes_and_ladders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Walks the clock past the die spin and the token's walk. Never
/// `pumpAndSettle`: the die spins on a repeating timer.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _pumpGameScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    const MaterialApp(home: SnakesAndLaddersScreen(mode: GameMode.local)),
  );
  await _settle(tester);
}

Finder _board() => find.byKey(const ValueKey('snakes_and_ladders_board'));
Finder _die() => find.byKey(const ValueKey('snakes_and_ladders_die'));
Finder _token(String side) =>
    find.byKey(ValueKey('snakes_and_ladders_token_$side'));

double _opacityOfLabel(WidgetTester tester, String label) {
  final opacity = tester.widget<AnimatedOpacity>(
    find.ancestor(of: find.text(label), matching: find.byType(AnimatedOpacity)),
  );
  return opacity.opacity;
}

void main() {
  testWidgets('renders the board, the die and both tokens',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(_board(), findsOneWidget);
    expect(_die(), findsOneWidget);
    expect(_token('blue'), findsOneWidget);
    expect(_token('red'), findsOneWidget);
  });

  testWidgets('the board is square and fits the screen',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final board = tester.getRect(_board());

    expect(board.width, closeTo(board.height, 0.5));
    expect(board.right, lessThanOrEqualTo(390.5));
    expect(board.bottom, lessThanOrEqualTo(844.5));
  });

  testWidgets('starts on Blue with both tokens waiting off the board',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(_opacityOfLabel(tester, 'BLUE'), 1.0);
    expect(_opacityOfLabel(tester, 'RED'), 0.0);

    // Both are parked below the bottom row until a six brings them on.
    final board = tester.getRect(_board());
    expect(tester.getCenter(_token('blue')).dy,
        greaterThan(board.bottom - (board.height * 0.1)));
  });

  testWidgets('rolling the die moves a token or passes the turn',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final before = tester.getCenter(_token('blue'));

    await tester.tap(_die());
    await _settle(tester);

    // Either Blue rolled a six and came on, or it did not and the turn
    // went to Red. The die is random, so both are correct -- but one of
    // them must have happened.
    final moved = tester.getCenter(_token('blue')) != before;
    final passedOn = _opacityOfLabel(tester, 'RED') == 1.0;
    expect(moved || passedOn, isTrue);
  });

  testWidgets('the die is held shut while a roll is still playing out',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    double dieScale() =>
        tester.widget<AnimatedScale>(
          find.descendant(of: _die(), matching: find.byType(AnimatedScale)),
        ).scale;

    expect(dieScale(), 1.0, reason: 'ready to be rolled');

    await tester.tap(_die());
    await tester.pump(const Duration(milliseconds: 120));
    expect(dieScale(), lessThan(1.0),
        reason: 'shut while the die spins and the token walks');

    await _settle(tester);
    expect(dieScale(), 1.0, reason: 'open again once it has settled');
  });

  testWidgets('options menu offers Restart and Exit, never Revert',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await _settle(tester);

    expect(find.text('Revert'), findsNothing,
        reason: 'taking back a roll is a second go at the die');
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Exit Game'), findsOneWidget);
  });

  testWidgets('Restart puts the tokens back and returns the turn to Blue',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final home = tester.getCenter(_token('blue'));

    // Roll a few times so something has definitely happened.
    for (var i = 0; i < 6; i++) {
      await tester.tap(_die());
      await _settle(tester);
    }

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await _settle(tester);
    await tester.tap(find.text('Restart'));
    await _settle(tester);

    expect(tester.getCenter(_token('blue')), home);
    expect(_opacityOfLabel(tester, 'BLUE'), 1.0);
  });

  testWidgets('the board carries every square', (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(SnakesAndLaddersGame.lastSquare, 100);
    expect(SnakesAndLaddersGame.columns, 10);

    final board = tester.getRect(_board());
    // A hundred squares inside a frame: each one wants a usable chunk
    // of a phone screen, not a sliver.
    expect(board.width / SnakesAndLaddersGame.columns, greaterThan(24));
  });
}
