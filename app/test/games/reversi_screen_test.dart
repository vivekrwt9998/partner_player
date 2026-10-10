import 'package:app/games/reversi/logic/reversi_game.dart';
import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/reversi/reversi_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Color _blueDisc = Color(0xFF00ACF8);
const Color _redDisc = Color(0xFFFF5E57);

/// Walks the clock past the flip animation and the pass notice. The same
/// bounded-pump shape the other board screens use, so the suite stays
/// uniform even though Reversi has no forever-repeating animation.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 400));
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

  await tester.pumpWidget(MaterialApp(home: ReversiScreen(mode: mode)));
  await _settle(tester);
}

Finder _cell(int row, int col) =>
    find.byKey(ValueKey('reversi_cell_${row}_$col'));

/// The colour of the disc sitting on a square, or `null` when it is
/// empty. A disc is the `DecoratedBox` carrying one of the two player
/// colours; the bevel layer nested inside it has a gradient and no
/// colour, and a hint is a smaller circle in a translucent shade, so
/// matching on the exact opaque colours tells all three apart.
Color? _discColourAt(WidgetTester tester, int row, int col) {
  final boxes = tester.widgetList<DecoratedBox>(
    find.descendant(of: _cell(row, col), matching: find.byType(DecoratedBox)),
  );
  for (final box in boxes) {
    final colour = (box.decoration as BoxDecoration).color;
    if (colour == _blueDisc || colour == _redDisc) return colour;
  }
  return null;
}

double _opacityOfLabel(WidgetTester tester, String label) {
  final opacity = tester.widget<AnimatedOpacity>(
    find.ancestor(of: find.text(label), matching: find.byType(AnimatedOpacity)),
  );
  return opacity.opacity;
}

String _score(WidgetTester tester, String side) =>
    tester.widget<Text>(find.byKey(ValueKey('reversi_score_$side'))).data!;

int _hintCount(WidgetTester tester) => find
    .byWidgetPredicate((widget) =>
        widget is SizedBox &&
        widget.key is ValueKey<String> &&
        (widget.key as ValueKey<String>).value.startsWith('reversi_hint_'))
    .evaluate()
    .length;

void main() {
  testWidgets('renders a square board with all 64 squares',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final board = tester.getRect(find.byKey(const ValueKey('reversi_board')));
    expect(board.width, closeTo(board.height, 0.5));
    for (var row = 0; row < ReversiGame.size; row++) {
      for (var col = 0; col < ReversiGame.size; col++) {
        expect(_cell(row, col), findsOneWidget);
      }
    }
  });

  testWidgets('opens with the four centre discs and Blue to move',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(_discColourAt(tester, 3, 4), _blueDisc);
    expect(_discColourAt(tester, 4, 3), _blueDisc);
    expect(_discColourAt(tester, 3, 3), _redDisc);
    expect(_discColourAt(tester, 4, 4), _redDisc);
    expect(_discColourAt(tester, 0, 0), isNull);

    expect(_opacityOfLabel(tester, 'BLUE'), 1.0);
    expect(_opacityOfLabel(tester, 'RED'), 0.0);
    expect(_score(tester, 'blue'), '2');
    expect(_score(tester, 'red'), '2');
  });

  testWidgets('marks exactly the squares that can be played',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(_hintCount(tester), 4, reason: 'Blue has four opening moves');
    for (final square in const [(2, 3), (3, 2), (4, 5), (5, 4)]) {
      expect(
        find.descendant(
          of: _cell(square.$1, square.$2),
          matching: find.byWidgetPredicate((widget) =>
              widget is SizedBox &&
              widget.key is ValueKey<String> &&
              (widget.key as ValueKey<String>)
                  .value
                  .startsWith('reversi_hint_')),
        ),
        findsOneWidget,
        reason: 'square $square is legal',
      );
    }
  });

  testWidgets('playing a disc turns the trapped one over',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);
    expect(_discColourAt(tester, 3, 3), _redDisc);

    await tester.tap(_cell(2, 3));
    await _settle(tester);

    expect(_discColourAt(tester, 2, 3), _blueDisc, reason: 'the new disc');
    expect(_discColourAt(tester, 3, 3), _blueDisc, reason: 'it flipped');
    expect(_score(tester, 'blue'), '4');
    expect(_score(tester, 'red'), '1');
    expect(_opacityOfLabel(tester, 'RED'), 1.0);
    expect(_opacityOfLabel(tester, 'BLUE'), 0.0);
  });

  testWidgets('the flip is animated rather than instant',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_cell(2, 3));
    // Part-way through: the captured disc is mid-turn, so it is still
    // showing the face it started with.
    await tester.pump(const Duration(milliseconds: 160));

    expect(_discColourAt(tester, 3, 3), _redDisc,
        reason: 'it has not passed edge-on yet');

    await _settle(tester);
    expect(_discColourAt(tester, 3, 3), _blueDisc);
  });

  testWidgets('the other player cannot move while the flip is still playing',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_cell(2, 3));
    await tester.pump(const Duration(milliseconds: 200));

    // (2,2) is a legal reply for Red, but the board is still turning
    // over -- taking it now would stack one capture on top of another.
    await tester.tap(_cell(2, 2));
    await _settle(tester);

    expect(_discColourAt(tester, 2, 2), isNull);
    expect(_score(tester, 'blue'), '4');
    expect(_score(tester, 'red'), '1');
    expect(_opacityOfLabel(tester, 'RED'), 1.0, reason: 'still Red to play');
  });

  testWidgets('a square that captures nothing does nothing',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_cell(0, 0));
    await _settle(tester);

    expect(_discColourAt(tester, 0, 0), isNull);
    expect(_opacityOfLabel(tester, 'BLUE'), 1.0, reason: 'still Blue\'s turn');
    expect(_score(tester, 'blue'), '2');
  });

  testWidgets('options menu offers Revert, Restart and Exit',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Revert'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Exit Game'), findsOneWidget);
  });

  testWidgets('Revert takes back the disc and the flip',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_cell(2, 3));
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revert'));
    await _settle(tester);

    expect(_discColourAt(tester, 2, 3), isNull);
    expect(_discColourAt(tester, 3, 3), _redDisc);
    expect(_score(tester, 'blue'), '2');
    expect(_score(tester, 'red'), '2');
    expect(_opacityOfLabel(tester, 'BLUE'), 1.0);
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

    testWidgets('the bot holds off until the flip has finished',
        (WidgetTester tester) async {
      await _pumpGameScreen(tester, mode: GameMode.bot);

      await tester.tap(_cell(2, 3));
      // Long enough for the bot's think delay to have elapsed, but well
      // short of the flip: the board must still be mid-turn and still
      // show only the human's move.
      await tester.pump(const Duration(milliseconds: 500));

      expect(_discColourAt(tester, 3, 3), _redDisc,
          reason: 'the captured disc has not passed edge-on yet');
      expect(_score(tester, 'red'), '1',
          reason: 'a bot reply here would be the flicker');

      await _settle(tester);
      expect(_score(tester, 'red'), isNot('1'),
          reason: 'once it settles the bot does answer');
    });

    testWidgets('the bot answers a human disc on its own',
        (WidgetTester tester) async {
      await _pumpGameScreen(tester, mode: GameMode.bot);

      await tester.tap(_cell(2, 3));
      await _settle(tester);

      // Blue's disc plus its capture, then Red's reply and its own.
      expect(_discColourAt(tester, 2, 3), _blueDisc);
      expect(_score(tester, 'red'), isNot('1'),
          reason: 'the bot took a square back');
      expect(_opacityOfLabel(tester, 'BLUE'), 1.0,
          reason: 'the board is handed back to the human');
    });
  });

  testWidgets('Restart puts the opening position back',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(_cell(2, 3));
    await _settle(tester);
    expect(_score(tester, 'blue'), '4');

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restart'));
    await _settle(tester);

    expect(_score(tester, 'blue'), '2');
    expect(_score(tester, 'red'), '2');
    expect(_discColourAt(tester, 2, 3), isNull);
    expect(_hintCount(tester), 4);
  });
}
