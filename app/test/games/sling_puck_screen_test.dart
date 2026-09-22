import 'package:app/games/sling_puck/logic/game_tuning.dart';
import 'package:app/games/sling_puck/logic/sling_puck_game.dart';
import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/sling_puck/sling_puck_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _t = GameTuning();

Future<void> _pumpGameScreen(
  WidgetTester tester, {
  GameMode mode = GameMode.local,
}) async {
  // A genuinely portrait device -- fixedPortrait's normal, unrotated case.
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: SlingPuckScreen(mode: mode)));
  // A Bot match never settles -- its clock runs so the bot's hand can move
  // -- so only a local match can be pumped to a standstill.
  if (mode == GameMode.local) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// The board's inner content rect -- inside the frame, which is the
/// coordinate space the pointer handling itself measures in.
Rect _fieldRect(WidgetTester tester) =>
    tester.getRect(find.byKey(const ValueKey('sling_puck_board'))).deflate(9);

/// Converts a point in field units (1.0 wide, 2.0 tall) to screen pixels.
Offset _fieldPoint(WidgetTester tester, double x, double y) {
  final rect = _fieldRect(tester);
  return rect.topLeft + Offset(x * rect.width, y * rect.width);
}

/// Where a piece is drawn right now, read off the widget tree by its key.
Offset _pieceCentre(WidgetTester tester, int id) =>
    tester.getRect(find.byKey(ValueKey('sling_puck_$id'))).center;

/// The id of some piece currently on [player]'s half, found from what is on
/// screen: anything past the halfway line belongs to that half.
int _pieceIdOn(WidgetTester tester, SlingPuckPlayerSide side) {
  final halfway = _fieldPoint(tester, 0, _t.barCentreY).dy;
  for (var id = 0; id < SlingPuckGame.totalPieces; id++) {
    final finder = find.byKey(ValueKey('sling_puck_$id'));
    if (finder.evaluate().isEmpty) continue;
    final isNear = tester.getRect(finder).center.dy > halfway;
    if (isNear == (side == SlingPuckPlayerSide.near)) return id;
  }
  throw StateError('no piece on the $side half');
}

enum SlingPuckPlayerSide { near, far }

void main() {
  testWidgets('renders the field with every piece on it',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(find.byKey(const ValueKey('sling_puck_board')), findsOneWidget);
    expect(find.byKey(const ValueKey('sling_puck_field')), findsOneWidget);
    for (var id = 0; id < SlingPuckGame.totalPieces; id++) {
      expect(find.byKey(ValueKey('sling_puck_$id')), findsOneWidget);
    }
  });

  testWidgets('shows no running score -- the board is the score',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(find.textContaining('LEFT'), findsNothing);
  });

  testWidgets('the field is rendered exactly 1:2', (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final rect = tester.getRect(find.byKey(const ValueKey('sling_puck_board')));
    expect(rect.height / rect.width, closeTo(2.0, 0.001));
  });

  testWidgets('shows no turn indicator -- both players play at once',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(find.text('BLUE TURN'), findsNothing);
    expect(find.text('RED TURN'), findsNothing);
  });

  testWidgets('a piece follows the finger exactly and never snaps',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final id = _pieceIdOn(tester, SlingPuckPlayerSide.near);
    final start = _pieceCentre(tester, id);
    // A clear patch of the near half, well away from the other pieces.
    final target = _fieldPoint(tester, 0.16, 1.28);

    final gesture = await tester.startGesture(start);
    await gesture.moveTo(target);
    await tester.pump();

    expect(_pieceCentre(tester, id), within(distance: 1.5, from: target));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a flick throws the piece rather than dropping it',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final id = _pieceIdOn(tester, SlingPuckPlayerSide.near);
    final start = _pieceCentre(tester, id);

    // Several quick moves so the velocity tracker sees a real flick.
    final gesture = await tester.startGesture(start);
    for (var i = 1; i <= 5; i++) {
      await gesture.moveBy(
        const Offset(0, -14),
        timeStamp: Duration(milliseconds: 8 * i),
      );
    }
    final released = _pieceCentre(tester, id);
    await gesture.up();

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final travelled = (_pieceCentre(tester, id) - released).distance;
    expect(travelled, greaterThan(20),
        reason: 'the flick has to carry it well past where it was let go');

    // Deliberately not pumpAndSettle: a piece launched hard enough to reach
    // the far band is catapulted straight back, so the field can stay in
    // motion indefinitely. That is the game, not a stuck frame.
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('letting go without a flick just puts the piece down',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final id = _pieceIdOn(tester, SlingPuckPlayerSide.near);
    final target = _fieldPoint(tester, 0.16, 1.28);

    final gesture = await tester.startGesture(_pieceCentre(tester, id));
    await gesture.moveTo(target);
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(_pieceCentre(tester, id), within(distance: 3, from: target));
  });

  testWidgets('both players can carry a piece at the same moment',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final blue = _pieceIdOn(tester, SlingPuckPlayerSide.near);
    final red = _pieceIdOn(tester, SlingPuckPlayerSide.far);
    final blueTarget = _fieldPoint(tester, 0.16, 1.28);
    final redTarget = _fieldPoint(tester, 0.84, 0.72);

    final blueFinger =
        await tester.startGesture(_pieceCentre(tester, blue), pointer: 11);
    final redFinger =
        await tester.startGesture(_pieceCentre(tester, red), pointer: 12);

    await blueFinger.moveTo(blueTarget);
    await redFinger.moveTo(redTarget);
    await tester.pump();

    expect(_pieceCentre(tester, blue), within(distance: 1.5, from: blueTarget));
    expect(_pieceCentre(tester, red), within(distance: 1.5, from: redTarget));

    await blueFinger.up();
    await redFinger.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a cancelled touch does not lock that player out',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final id = _pieceIdOn(tester, SlingPuckPlayerSide.near);
    final gesture = await tester.startGesture(_pieceCentre(tester, id));
    await gesture.moveTo(_fieldPoint(tester, 0.16, 1.28));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();

    final again = _pieceIdOn(tester, SlingPuckPlayerSide.near);
    final target = _fieldPoint(tester, 0.82, 1.28);
    final second = await tester.startGesture(_pieceCentre(tester, again));
    await second.moveTo(target);
    await tester.pump();

    expect(_pieceCentre(tester, again), within(distance: 1.5, from: target));

    await second.up();
    await tester.pumpAndSettle();
  });

  testWidgets('touching empty space does nothing', (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final before = [
      for (var id = 0; id < SlingPuckGame.totalPieces; id++)
        _pieceCentre(tester, id),
    ];

    final gesture = await tester.startGesture(_fieldPoint(tester, 0.5, 1.0));
    await gesture.moveTo(_fieldPoint(tester, 0.5, 1.7));
    await gesture.up();
    await tester.pumpAndSettle();

    for (var id = 0; id < SlingPuckGame.totalPieces; id++) {
      expect(_pieceCentre(tester, id), within(distance: 0.5, from: before[id]),
          reason: 'nothing was under that finger, so nothing should move');
    }
  });

  testWidgets('options menu offers Restart, debug and Exit -- never Revert',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Debug overlay'), findsOneWidget);
    expect(find.text('Exit Game'), findsOneWidget);
    expect(find.text('Revert'), findsNothing,
        reason: 'continuous play has no discrete move to take back');
  });

  testWidgets('the debug overlay can be switched on and off',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);
    expect(find.text('V_LAUNCH'), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Debug overlay'));
    await tester.pumpAndSettle();

    expect(find.text('V_LAUNCH'), findsOneWidget);
    expect(find.text('D_MAX'), findsOneWidget);
    expect(find.byType(Slider), findsWidgets);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide debug'));
    await tester.pumpAndSettle();

    expect(find.text('V_LAUNCH'), findsNothing);
  });

  testWidgets('Restart from the options menu resets the field',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final id = _pieceIdOn(tester, SlingPuckPlayerSide.near);
    final moved = _fieldPoint(tester, 0.16, 1.28);
    final gesture = await tester.startGesture(_pieceCentre(tester, id));
    await gesture.moveTo(moved);
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_pieceCentre(tester, id), within(distance: 3, from: moved));

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();

    expect(_pieceCentre(tester, id), isNot(within(distance: 3, from: moved)),
        reason: 'restart put it back where it started');
  });

  group('Bot mode', () {
    testWidgets('renders and starts the bot playing the far half',
        (WidgetTester tester) async {
      await _pumpGameScreen(tester, mode: GameMode.bot);

      // Real frames, not one giant jump: the bot's hand moves per frame,
      // so a single huge pump would not represent it at all.
      final halfway = _fieldPoint(tester, 0, _t.barCentreY).dy;
      var fewestOnFarHalf = SlingPuckGame.piecesPerPlayer;

      for (var i = 0; i < 420; i++) {
        await tester.pump(const Duration(milliseconds: 16));

        var onFarHalf = 0;
        for (var id = 0; id < SlingPuckGame.totalPieces; id++) {
          final finder = find.byKey(ValueKey('sling_puck_$id'));
          if (finder.evaluate().isEmpty) continue;
          if (tester.getRect(finder).center.dy < halfway) onFarHalf++;
        }
        fewestOnFarHalf = onFarHalf < fewestOnFarHalf ? onFarHalf : fewestOnFarHalf;
      }

      // Sampled every frame rather than read once at the end: a piece can
      // bounce off the near band and come back through the gap, so the
      // count at any single instant is not the point -- getting one across
      // under its own steam is.
      expect(fewestOnFarHalf, lessThan(SlingPuckGame.piecesPerPlayer));

      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('a finger on the bot\'s half does nothing',
        (WidgetTester tester) async {
      await _pumpGameScreen(tester, mode: GameMode.bot);

      final far = _pieceIdOn(tester, SlingPuckPlayerSide.far);
      final start = _pieceCentre(tester, far);
      final target = _fieldPoint(tester, 0.16, 0.72);

      final gesture = await tester.startGesture(start);
      await gesture.moveTo(target);
      await tester.pump();

      expect(_pieceCentre(tester, far), isNot(within(distance: 3, from: target)),
          reason: 'that half belongs to the bot');

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('the human still controls the near half',
        (WidgetTester tester) async {
      await _pumpGameScreen(tester, mode: GameMode.bot);

      final near = _pieceIdOn(tester, SlingPuckPlayerSide.near);
      final target = _fieldPoint(tester, 0.16, 1.28);

      final gesture = await tester.startGesture(_pieceCentre(tester, near));
      await gesture.moveTo(target);
      await tester.pump();

      expect(_pieceCentre(tester, near), within(distance: 1.5, from: target));

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
