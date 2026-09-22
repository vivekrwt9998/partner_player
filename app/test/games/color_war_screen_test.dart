import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/color_war/color_war_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpGameScreen(
  WidgetTester tester, {
  GameMode mode = GameMode.local,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: ColorWarScreen(mode: mode)));
  await tester.pumpAndSettle();
}

/// Runs out everything a move can set off.
///
/// A chain reaction schedules one timer per wave, each from inside the
/// previous one, and a Bot reply is a timer of its own. `pumpAndSettle`
/// alone stops as soon as no frame is scheduled, which can be before the
/// next wave's timer was even due, so the clock is walked forward in steps
/// instead.
Future<void> _settleMove(WidgetTester tester) async {
  for (var step = 0; step < 20; step++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pumpAndSettle();
}

Future<void> _tapCell(WidgetTester tester, int row, int col) async {
  await tester.tap(find.byKey(ValueKey('cw_cell_${row}_$col')));
  await _settleMove(tester);
}

/// Both turn labels stay in the tree at all times (the face-to-face badges
/// slide/fade the inactive one out rather than removing it), so "whose turn
/// is it" is verified through the active badge's opacity, not presence.
double _opacityOfLabel(WidgetTester tester, String label) {
  final opacity = tester.widget<AnimatedOpacity>(
    find.ancestor(of: find.text(label), matching: find.byType(AnimatedOpacity)),
  );
  return opacity.opacity;
}

/// The two numbers on the score pill: tiles held by Blue, then by Red.
(String, String) _score(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(find.descendant(
        of: find.byKey(const ValueKey('color_war_score')),
        matching: find.byType(Text),
      ))
      .map((text) => text.data!)
      .toList();
  return (texts.first, texts.last);
}

void main() {
  testWidgets('renders a square board of tappable cells',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final board = tester.getRect(find.byKey(const ValueKey('color_war_board')));
    expect(board.width, closeTo(board.height, 0.5));
    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < 5; col++) {
        expect(find.byKey(ValueKey('cw_cell_${row}_$col')), findsOneWidget);
      }
    }
  });

  testWidgets('starts on Blue\'s turn with an empty scoreboard',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
    expect(_opacityOfLabel(tester, 'RED TURN'), 0.0);
    expect(_score(tester), ('0', '0'));
  });

  testWidgets('dropping an orb claims the tile and passes the turn',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await _tapCell(tester, 2, 2);

    expect(_score(tester), ('1', '0'));
    expect(_opacityOfLabel(tester, 'RED TURN'), 1.0);
    expect(_opacityOfLabel(tester, 'BLUE TURN'), 0.0);
  });

  testWidgets('a tile the opponent holds cannot be taken by tapping it',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await _tapCell(tester, 2, 2);
    await _tapCell(tester, 2, 2);

    expect(_score(tester), ('1', '0'), reason: 'the tap was refused');
    expect(_opacityOfLabel(tester, 'RED TURN'), 1.0);
  });

  testWidgets('a full corner bursts and paints both its neighbours',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await _tapCell(tester, 0, 0); // Blue, 1 orb
    await _tapCell(tester, 4, 4); // Red, out of the way
    await _tapCell(tester, 0, 0); // Blue, bursts

    // The corner empties into (0,1) and (1,0), so Blue ends up with two
    // tiles instead of one.
    expect(_score(tester), ('2', '1'));
    expect(_opacityOfLabel(tester, 'RED TURN'), 1.0,
        reason: 'the turn passes once the reaction has settled');
  });

  testWidgets('options menu offers Revert, Restart and Exit in a local match',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Revert'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Exit Game'), findsOneWidget);
  });

  testWidgets('Restart clears the board', (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await _tapCell(tester, 2, 2);
    expect(_score(tester), ('1', '0'));

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();

    expect(_score(tester), ('0', '0'));
    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
  });

  testWidgets('Revert takes the last orb back', (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await _tapCell(tester, 2, 2);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revert'));
    await tester.pumpAndSettle();

    expect(_score(tester), ('0', '0'));
    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
  });

  group('Bot mode', () {
    testWidgets('never offers Revert', (WidgetTester tester) async {
      await _pumpGameScreen(tester, mode: GameMode.bot);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Revert'), findsNothing);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Exit Game'), findsOneWidget);
    });

    testWidgets('the bot answers a human move on its own',
        (WidgetTester tester) async {
      await _pumpGameScreen(tester, mode: GameMode.bot);

      await _tapCell(tester, 2, 2);

      final (blue, red) = _score(tester);
      expect(blue, '1');
      expect(red, '1', reason: 'the bot took a tile of its own');
      expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
    });
  });
}
