import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:app/games/four_in_a_row/logic/four_in_a_row_game.dart';
import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/four_in_a_row/four_in_a_row_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const Color _holeColor = Color(0xFF58636F);
const Color _bluePlayerColor = Color(0xFF00ACF8);

const int _totalHoles = FourInARowGame.rows * FourInARowGame.cols;

/// Number of board sockets currently drawn in their empty state.
int _emptySocketCount(WidgetTester tester) => _countFills(tester, _holeColor);

/// Number of discs currently drawn in the Blue player color.
int _blueDiscCount(WidgetTester tester) => _countFills(tester, _bluePlayerColor);

int _countFills(WidgetTester tester, Color color) {
  return tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .where((box) {
        final decoration = box.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            decoration.color == color;
      })
      .length;
}

final GlobalKey _captureKey = GlobalKey();

Future<void> _pumpGameScreen(WidgetTester tester, {GameMode mode = GameMode.local}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: MaterialApp(home: FourInARowScreen(mode: mode)),
    ),
  );
  await tester.pumpAndSettle();
}

/// The board frame rect, found by its rounded charcoal body.
Rect _boardRect(WidgetTester tester) {
  return tester.getRect(
    find.byWidgetPredicate((widget) {
      if (widget is! DecoratedBox) return false;
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.borderRadius != null &&
          decoration.color == const Color(0xFF303943);
    }),
  );
}

/// A snapshot of the rendered frame, queryable per pixel.
class _Frame {
  _Frame(this._pixels, this._width, this._height);

  final ByteData _pixels;
  final int _width;
  final int _height;

  static Future<_Frame> capture(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    // Rasterizing needs real async work, so it has to run outside fake async.
    final frame = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final captured = _Frame(data!, image.width, image.height);
      image.dispose();
      return captured;
    });
    return frame!;
  }

  /// The 8 bit RGB channels rendered at [position], or `null` when off screen.
  ({int r, int g, int b})? rgbAt(Offset position) {
    final x = position.dx.round();
    final y = position.dy.round();
    if (x < 0 || y < 0 || x >= _width || y >= _height) return null;
    final offset = ((y * _width) + x) * 4;
    return (
      r: _pixels.getUint8(offset),
      g: _pixels.getUint8(offset + 1),
      b: _pixels.getUint8(offset + 2),
    );
  }

  bool isBlueDiscAt(Offset position) {
    final pixel = rgbAt(position);
    if (pixel == null) return false;
    // Blue disc (0, 172, 248); board (48, 57, 67); socket (88, 99, 111).
    return pixel.b > 200 && pixel.r < 120 && pixel.g > 120;
  }

  bool isEmptySocketAt(Offset position) {
    final pixel = rgbAt(position);
    // Empty socket grey (88, 99, 111).
    return pixel != null && pixel.r == 88 && pixel.g == 99 && pixel.b == 111;
  }

  int blueDiscPixelsIn(Rect area) {
    var count = 0;
    for (var y = area.top.round(); y < area.bottom.round(); y++) {
      for (var x = area.left.round(); x < area.right.round(); x++) {
        if (isBlueDiscAt(Offset(x.toDouble(), y.toDouble()))) count++;
      }
    }
    return count;
  }
}

void main() {
  testWidgets('destination hole stays empty until the falling disc lands',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    expect(_emptySocketCount(tester), _totalHoles);

    // Drop into the middle column by tapping the center of the board.
    await tester.tapAt(const Offset(640, 400));
    await tester.pump();

    // Mid-flight: the destination must still look empty and exactly one Blue
    // disc may be visible (the one that is falling).
    await tester.pump(const Duration(milliseconds: 300));
    expect(_emptySocketCount(tester), _totalHoles);
    expect(_blueDiscCount(tester), 1);

    // After the animation the destination takes its occupied state.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(_emptySocketCount(tester), _totalHoles - 1);
    expect(_blueDiscCount(tester), 1);
  });

  testWidgets('the falling disc is never painted on top of the board surface',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final board = _boardRect(tester);
    const framePadding = 12.0;
    const frameBottomPadding = 8.0;
    const cellInset = 3.5;
    final cellWidth =
        (board.width - (framePadding * 2)) / FourInARowGame.cols;
    final cellHeight =
        (board.height - framePadding - frameBottomPadding) / FourInARowGame.rows;
    final discRadius = (math.min(cellWidth, cellHeight) - (cellInset * 2)) / 2;

    Offset holeCenter(int row, int col) => Offset(
          board.left + framePadding + (col * cellWidth) + (cellWidth / 2),
          board.top + framePadding + (row * cellHeight) + (cellHeight / 2),
        );

    const column = 3;
    // Points on the solid board surface between two holes of the drop column.
    final surfacePoints = <Offset>[
      for (var row = 0; row < FourInARowGame.rows - 1; row++)
        Offset(
          holeCenter(row, column).dx,
          (holeCenter(row, column).dy + holeCenter(row + 1, column).dy) / 2,
        ),
    ];
    // The sample points must really be board surface, not hole.
    expect(cellHeight / 2, greaterThan(discRadius));

    // Every empty socket is visible through its hole, and the board surface
    // between the holes is solid.
    final initial = await _Frame.capture(tester);
    for (var row = 0; row < FourInARowGame.rows; row++) {
      expect(initial.isEmptySocketAt(holeCenter(row, column)), isTrue);
    }
    for (final point in surfacePoints) {
      expect(initial.isEmptySocketAt(point), isFalse);
    }

    await tester.tapAt(holeCenter(2, column));
    await tester.pump();

    var blueSeenInsideBoard = 0;
    for (var elapsed = 50; elapsed <= 600; elapsed += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      final frame = await _Frame.capture(tester);
      for (final point in surfacePoints) {
        expect(
          frame.isBlueDiscAt(point),
          isFalse,
          reason: 'disc painted over the board surface at $point after ${elapsed}ms',
        );
      }
      blueSeenInsideBoard += frame.blueDiscPixelsIn(
        Rect.fromLTRB(
          holeCenter(0, column).dx - discRadius,
          board.top,
          holeCenter(0, column).dx + discRadius,
          board.bottom,
        ),
      );
    }

    // The disc really was travelling inside the board, seen through the holes.
    expect(blueSeenInsideBoard, greaterThan(0));

    await tester.pumpAndSettle();
    final settled = await _Frame.capture(tester);
    // It settled inside the bottom hole of the column it was dropped into.
    expect(settled.isBlueDiscAt(holeCenter(FourInARowGame.rows - 1, column)), isTrue);
    for (final point in surfacePoints) {
      expect(settled.isBlueDiscAt(point), isFalse);
    }
  });

  testWidgets('options menu lists Revert, Restart and Exit in order',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    // The menu is a local panel inside the game's own Stack (not a
    // PopupMenuButton route), so it stays visually consistent with the
    // portrait "please rotate" composition. Order is verified by vertical
    // position, since the panel lays its items out top to bottom.
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
    expect(find.text('BLUE TURN'), findsOneWidget);
  });

  testWidgets('turn indicators are mirrored and keep their text inside the arc',
      (WidgetTester tester) async {
    await _pumpGameScreen(tester);

    final blueText = tester.widget<Text>(find.text('BLUE TURN'));
    final redText = tester.widget<Text>(find.text('RED TURN'));
    expect(blueText.textAlign, TextAlign.left);
    expect(redText.textAlign, TextAlign.right);

    final blueBounds = tester.getRect(
      find.ancestor(
        of: find.text('BLUE TURN'),
        matching: find.byType(AnimatedSlide),
      ),
    );
    final blueTextRect = tester.getRect(find.text('BLUE TURN'));

    // The indicator is a square quarter circle anchored at its bottom corner.
    expect(blueBounds.width, closeTo(blueBounds.height, 0.01));
    expect(blueBounds.left, closeTo(0, 0.01));

    // Text is padded away from the left edge and stays inside the quarter arc.
    expect(blueTextRect.left, greaterThan(blueBounds.left));
    final dx = blueTextRect.right - blueBounds.left;
    final dy = blueBounds.bottom - blueTextRect.top;
    expect(math.sqrt((dx * dx) + (dy * dy)), lessThan(blueBounds.width));
  });
}
