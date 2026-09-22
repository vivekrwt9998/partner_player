import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/checkers/checkers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Color _bluePlayerColor = Color(0xFF00ACF8);
const Color _redPlayerColor = Color(0xFFFF5E57);

/// A bounded stand-in for `pumpAndSettle()`: the board's "you can move
/// this" sparkle ring animates forever by design (see
/// `_CheckersScreenState._glowController`), so `pumpAndSettle()` itself
/// would never see the frame queue go idle and would time out. Several
/// separate 400ms pumps -- rather than one big one -- so a chain of
/// animations that only starts partway through an earlier pump (e.g. a Bot
/// move's think-delay firing, which then kicks off its own move-slide
/// animation) still gets a full, fresh window to finish in a later one.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _pumpGameScreen(WidgetTester tester, {GameMode mode = GameMode.local}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(home: CheckersScreen(mode: mode)),
  );
  await _settle(tester);
}

Finder _cell(int row, int col) => find.byKey(ValueKey('checkers_cell_${row}_$col'));

/// The color of the piece drawn at [row]/[col], or `null` if the square is
/// empty. Distinguishes the piece body (a `Container`) from the smaller
/// King-ring indicator nested inside it (a plain `DecoratedBox`).
Color? _pieceColorAt(WidgetTester tester, int row, int col) {
  final finder = find.descendant(
    of: _cell(row, col),
    matching: find.byWidgetPredicate(
      (w) => w is Container && w.decoration is BoxDecoration,
    ),
  );
  if (finder.evaluate().isEmpty) return null;
  final widget = tester.widget<Container>(finder.first);
  return (widget.decoration as BoxDecoration).color;
}

double _opacityOfLabel(WidgetTester tester, String label) {
  final opacity = tester.widget<AnimatedOpacity>(
    find.ancestor(of: find.text(label), matching: find.byType(AnimatedOpacity)),
  );
  return opacity.opacity;
}

void main() {
  testWidgets('renders the standard starting position', (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(_pieceColorAt(tester, 5, 0), _bluePlayerColor);
    expect(_pieceColorAt(tester, 7, 6), _bluePlayerColor);
    expect(_pieceColorAt(tester, 2, 1), _redPlayerColor);
    expect(_pieceColorAt(tester, 0, 3), _redPlayerColor);
    expect(_pieceColorAt(tester, 3, 0), isNull);
    expect(_pieceColorAt(tester, 4, 5), isNull);

    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
    expect(_opacityOfLabel(tester, 'RED TURN'), 0.0);
  });

  testWidgets('selecting a piece then a highlighted square moves it and switches turns',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_cell(5, 0));
    await _settle(tester);
    await tester.tap(_cell(4, 1));
    await _settle(tester);

    expect(_pieceColorAt(tester, 4, 1), _bluePlayerColor);
    expect(_pieceColorAt(tester, 5, 0), isNull);
    expect(_opacityOfLabel(tester, 'RED TURN'), 1.0);
    expect(_opacityOfLabel(tester, 'BLUE TURN'), 0.0);
  });

  testWidgets("tapping the opponent's piece on your turn does nothing",
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_cell(2, 1)); // Red piece, but it's Blue's turn
    await _settle(tester);
    await tester.tap(_cell(3, 0)); // where it would move if it were selected
    await _settle(tester);

    expect(_pieceColorAt(tester, 2, 1), _redPlayerColor);
    expect(_pieceColorAt(tester, 3, 0), isNull);
    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
  });

  testWidgets('options menu lists Revert, Restart and Exit in order',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await _settle(tester);

    expect(find.text('Revert'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Exit Game'), findsOneWidget);

    final revertY = tester.getRect(find.text('Revert')).top;
    final restartY = tester.getRect(find.text('Restart')).top;
    final exitY = tester.getRect(find.text('Exit Game')).top;
    expect(revertY, lessThan(restartY));
    expect(restartY, lessThan(exitY));
  });

  testWidgets('tapping outside the open options menu dismisses it without acting',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await _settle(tester);
    expect(find.text('Restart'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await _settle(tester);

    expect(find.text('Restart'), findsNothing);
    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
  });

  testWidgets('Restart from the options menu resets the board',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_cell(5, 0));
    await _settle(tester);
    await tester.tap(_cell(4, 1));
    await _settle(tester);
    expect(_opacityOfLabel(tester, 'RED TURN'), 1.0);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await _settle(tester);
    await tester.tap(find.text('Restart'));
    await _settle(tester);

    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
    expect(_pieceColorAt(tester, 5, 0), _bluePlayerColor);
    expect(_pieceColorAt(tester, 4, 1), isNull);
  });

  testWidgets('Revert from the options menu undoes the last move',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_cell(5, 0));
    await _settle(tester);
    await tester.tap(_cell(4, 1));
    await _settle(tester);
    expect(_opacityOfLabel(tester, 'RED TURN'), 1.0);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await _settle(tester);
    await tester.tap(find.text('Revert'));
    await _settle(tester);

    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
    expect(_pieceColorAt(tester, 5, 0), _bluePlayerColor);
    expect(_pieceColorAt(tester, 4, 1), isNull);
  });

  testWidgets('Bot mode opens the shared gameplay screen without Revert',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester, mode: GameMode.bot);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await _settle(tester);
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Exit Game'), findsOneWidget);
    expect(find.text('Revert'), findsNothing);
  });

  testWidgets('Bot mode: a human move is automatically followed by a Bot reply',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester, mode: GameMode.bot);

    await tester.tap(_cell(5, 0));
    await _settle(tester);
    await tester.tap(_cell(4, 1));
    await _settle(tester);

    // The Bot's reply has landed and play is back with Blue, without any
    // further input from the test. Neither side has captured anything yet
    // this early, so both start-of-game piece counts are unchanged.
    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
    var blueCount = 0;
    var redCount = 0;
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final color = _pieceColorAt(tester, row, col);
        if (color == _bluePlayerColor) blueCount++;
        if (color == _redPlayerColor) redCount++;
      }
    }
    expect(blueCount, 12);
    expect(redCount, 12);
  });
}
