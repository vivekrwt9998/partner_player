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

/// How many tiles are holding a disc right now.
///
/// There is no scoreboard on screen -- the board is the score -- so a test
/// reads the board itself. An empty tile keeps its disc scaled to zero,
/// which is what tells the two apart.
int _occupiedTiles(WidgetTester tester) => tester
    .widgetList<AnimatedScale>(find.descendant(
      of: find.byKey(const ValueKey('color_war_board')),
      matching: find.byType(AnimatedScale),
    ))
    .where((scale) => scale.scale == 1.0)
    .length;

bool _isOccupied(WidgetTester tester, int row, int col) =>
    tester
        .widget<AnimatedScale>(find.descendant(
          of: find.byKey(ValueKey('cw_cell_${row}_$col')),
          matching: find.byType(AnimatedScale),
        ))
        .scale ==
    1.0;

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

  testWidgets('starts on Blue\'s turn with an empty board',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
    expect(_opacityOfLabel(tester, 'RED TURN'), 0.0);
    expect(_occupiedTiles(tester), 0);
  });

  testWidgets('dropping an orb claims the tile and passes the turn',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await _tapCell(tester, 2, 2);

    expect(_isOccupied(tester, 2, 2), isTrue);
    expect(_occupiedTiles(tester), 1);
    expect(_opacityOfLabel(tester, 'RED TURN'), 1.0);
    expect(_opacityOfLabel(tester, 'BLUE TURN'), 0.0);
  });

  testWidgets('a tile the opponent holds cannot be taken by tapping it',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await _tapCell(tester, 2, 2);
    await _tapCell(tester, 2, 2);

    expect(_occupiedTiles(tester), 1, reason: 'the second tap was refused');
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
    expect(_isOccupied(tester, 0, 0), isFalse, reason: 'the corner emptied');
    expect(_isOccupied(tester, 0, 1), isTrue);
    expect(_isOccupied(tester, 1, 0), isTrue);
    expect(_occupiedTiles(tester), 3);
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
    expect(_occupiedTiles(tester), 1);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();

    expect(_occupiedTiles(tester), 0);
    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
  });

  testWidgets('Revert takes the last orb back', (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await _tapCell(tester, 2, 2);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revert'));
    await tester.pumpAndSettle();

    expect(_occupiedTiles(tester), 0);
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

      expect(_isOccupied(tester, 2, 2), isTrue);
      expect(_occupiedTiles(tester), 2,
          reason: 'the human tile, plus one the bot took');
      expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
    });
  });
}
