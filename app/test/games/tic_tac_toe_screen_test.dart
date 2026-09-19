import 'package:app/games/tic_tac_toe/logic/tic_tac_toe_game.dart';
import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/tic_tac_toe/tic_tac_toe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpGameScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    const MaterialApp(home: TicTacToeScreen(mode: GameMode.local)),
  );
  await tester.pumpAndSettle();
}

Finder _cell(int row, int col) => find.byKey(ValueKey('ttt_cell_${row}_$col'));

double _scaleOf(WidgetTester tester, int row, int col) {
  final animatedScale = tester.widget<AnimatedScale>(
    find.descendant(of: _cell(row, col), matching: find.byType(AnimatedScale)),
  );
  return animatedScale.scale;
}

/// The runtime type name of the mark painter drawn at [row]/[col], or an
/// empty string if the cell is still empty.
String _markPainterName(WidgetTester tester, int row, int col) {
  final finder = find.descendant(
    of: _cell(row, col),
    matching: find.byType(CustomPaint),
  );
  if (finder.evaluate().isEmpty) return '';
  final widget = tester.widget<CustomPaint>(finder.first);
  return widget.painter?.runtimeType.toString() ?? '';
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

void main() {
  testWidgets("renders an empty board and starts with Blue's turn",
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
    expect(_opacityOfLabel(tester, 'RED TURN'), 0.0);
    for (var row = 0; row < TicTacToeGame.rows; row++) {
      for (var col = 0; col < TicTacToeGame.cols; col++) {
        expect(_scaleOf(tester, row, col), 0.0);
      }
    }
  });

  testWidgets('tapping an empty cell places the current mark and switches turns',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_cell(1, 1));
    await tester.pumpAndSettle();

    expect(_scaleOf(tester, 1, 1), 1.0);
    expect(_markPainterName(tester, 1, 1), contains('OMarkPainter'));
    expect(_opacityOfLabel(tester, 'RED TURN'), 1.0);
    expect(_opacityOfLabel(tester, 'BLUE TURN'), 0.0);

    await tester.tap(_cell(0, 0));
    await tester.pumpAndSettle();

    expect(_scaleOf(tester, 0, 0), 1.0);
    expect(_markPainterName(tester, 0, 0), contains('XMarkPainter'));
    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
    expect(_opacityOfLabel(tester, 'RED TURN'), 0.0);
  });

  testWidgets('tapping an already occupied cell does not change the board or turn',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_cell(1, 1));
    await tester.pumpAndSettle();
    expect(_opacityOfLabel(tester, 'RED TURN'), 1.0);

    await tester.tap(_cell(1, 1));
    await tester.pumpAndSettle();

    expect(_markPainterName(tester, 1, 1), contains('OMarkPainter'));
    expect(_opacityOfLabel(tester, 'RED TURN'), 1.0);
  });

  testWidgets('options menu lists Revert, Restart and Exit in order',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();
    expect(find.text('Restart'), findsOneWidget);

    // Tap a point clearly outside the panel (top-left corner of the screen).
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('Restart'), findsNothing);
    // The board must be completely unaffected: still Blue's first move.
    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
  });

  testWidgets('Restart from the options menu clears the board',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_cell(1, 1));
    await tester.pumpAndSettle();
    expect(_opacityOfLabel(tester, 'RED TURN'), 1.0);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();

    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
    expect(_scaleOf(tester, 1, 1), 0.0);
  });

  testWidgets('Revert from the options menu undoes the last move',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_cell(1, 1));
    await tester.pumpAndSettle();
    expect(_opacityOfLabel(tester, 'RED TURN'), 1.0);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revert'));
    await tester.pumpAndSettle();

    expect(_opacityOfLabel(tester, 'BLUE TURN'), 1.0);
    expect(_scaleOf(tester, 1, 1), 0.0);
  });
}
