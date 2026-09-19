import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/four_in_a_row/four_in_a_row_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for AGENTS.md §8 and Four in a Row's `fixedLandscape`
/// composition.
///
/// Final, deliberate design (see product discussion): the physical device is
/// *never* forced to rotate (no `SystemChrome.setPreferredOrientations`,
/// ever). When the device is genuinely landscape, the board renders exactly
/// as it always has: wide (7:6), disc falls straight down. When the device
/// is portrait, the screen shows a *software-rotated* "please turn your
/// phone" composition — the same, unmodified board/animation code, just
/// displayed rotated 90° — so the board appears taller than wide and the
/// falling disc visibly slides sideways in that state. This is intentional:
/// nobody is expected to actually play while holding the phone portrait; the
/// moment they rotate their phone, the view snaps to the normal landscape
/// composition with zero restart.
void main() {
  Future<void> pumpScreen(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: FourInARowScreen(mode: GameMode.local)),
    );
    await tester.pumpAndSettle();
  }

  Rect boardScreenRect(WidgetTester tester) {
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

  /// The circular preview disc waiting to be dropped, or `null` if not
  /// currently shown.
  Rect? previewDiscRect(WidgetTester tester) {
    final finder = find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.shape == BoxShape.circle &&
          decoration.color == const Color(0xFF00ACF8);
    });
    if (finder.evaluate().isEmpty) return null;
    return tester.getRect(finder);
  }

  testWidgets(
      'opening and leaving Four in a Row never calls setPreferredOrientations',
      (WidgetTester tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    // Portrait device: the case most likely to tempt a game-level rotation.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const FourInARowScreen(mode: GameMode.local),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(FourInARowScreen), findsOneWidget);

    // Leave the game the same way its own Exit control does (there is no
    // AppBar back button on this full-bleed gameplay screen).
    Navigator.of(tester.element(find.byType(FourInARowScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(FourInARowScreen), findsNothing);

    final orientationCalls = calls
        .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
        .toList();
    expect(
      orientationCalls,
      isEmpty,
      reason:
          'Four in a Row must not force a physical device rotation; the '
          'portrait "please rotate" view is a software pixel transform, '
          'never a device orientation lock.',
    );
  });

  group('genuinely landscape device: normal, unrotated composition', () {
    testWidgets('the board is landscape-shaped and fits the screen',
        (WidgetTester tester) async {
      await pumpScreen(tester, const Size(1280, 720));

      expect(tester.takeException(), isNull);
      final rect = boardScreenRect(tester);
      expect(rect.width, greaterThan(rect.height));
      expect(rect.width / rect.height, closeTo(7 / 6, 0.01));
      expect(rect.right, lessThanOrEqualTo(1280.5));
      expect(rect.bottom, lessThanOrEqualTo(720.5));
    });

    testWidgets(
        'the board is landscape-shaped on a real phone-sized landscape too',
        (WidgetTester tester) async {
      await pumpScreen(tester, const Size(844, 390));

      expect(tester.takeException(), isNull);
      final rect = boardScreenRect(tester);
      expect(rect.width, greaterThan(rect.height));
      expect(rect.width / rect.height, closeTo(7 / 6, 0.01));
      expect(rect.right, lessThanOrEqualTo(844.5));
      expect(rect.bottom, lessThanOrEqualTo(390.5));
    });

    testWidgets('a disc falls straight down (dx fixed, dy increases)',
        (WidgetTester tester) async {
      await pumpScreen(tester, const Size(1280, 720));

      final board = boardScreenRect(tester);
      final cellWidth = (board.width - 24) / 7;
      final columnX = board.left + 12 + (3 * cellWidth) + (cellWidth / 2);

      await tester.tapAt(Offset(columnX, board.center.dy));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final midFlightRect = previewDiscRect(tester) ??
          tester.getRect(find.byWidgetPredicate((widget) {
            if (widget is! DecoratedBox) return false;
            final decoration = widget.decoration;
            return decoration is BoxDecoration &&
                decoration.shape == BoxShape.circle &&
                decoration.color == const Color(0xFF00ACF8);
          }));

      await tester.pump(const Duration(milliseconds: 200));
      final laterRect = tester.getRect(find.byWidgetPredicate((widget) {
        if (widget is! DecoratedBox) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            decoration.color == const Color(0xFF00ACF8);
      }));

      expect(laterRect.center.dx, closeTo(midFlightRect.center.dx, 1.0));
      expect(laterRect.center.dy, greaterThan(midFlightRect.center.dy));
    });

    testWidgets(
        'the preview disc is never clipped, at a real phone landscape size',
        (WidgetTester tester) async {
      // Regression test for a real, pre-existing bug: on a short landscape
      // screen, the preview disc used to be clipped by the top edge because
      // the board's aspect-fit didn't reserve headroom for it.
      await pumpScreen(tester, const Size(844, 390));

      final disc = previewDiscRect(tester)!;
      expect(disc.top, greaterThanOrEqualTo(0));
      expect(disc.height, closeTo(disc.width, 0.5));
    });
  });

  group('portrait device: rotated "please turn your phone" composition', () {
    testWidgets('renders without error and fits the physical screen',
        (WidgetTester tester) async {
      await pumpScreen(tester, const Size(390, 844));
      expect(tester.takeException(), isNull);

      final rect = boardScreenRect(tester);
      expect(rect.right, lessThanOrEqualTo(390.5));
      expect(rect.bottom, lessThanOrEqualTo(844.5));
    });

    testWidgets(
        'the board visibly reads as rotated (taller than wide), signalling '
        'the player to turn their phone', (WidgetTester tester) async {
      // This is the deliberate visual cue: a landscape-shaped board, when
      // rotated as a rigid whole to fit a portrait screen, necessarily
      // becomes taller than wide on screen (rotating any rectangle 90°
      // swaps its width and height). That inversion is what the player
      // actually sees and recognizes as "turn your phone".
      await pumpScreen(tester, const Size(390, 844));

      final rect = boardScreenRect(tester);
      expect(
        rect.height,
        greaterThan(rect.width),
        reason: 'The rotated hint composition should look visibly '
            'different from the normal landscape board.',
      );
    });

    testWidgets('the preview disc is fully visible, not clipped',
        (WidgetTester tester) async {
      await pumpScreen(tester, const Size(390, 844));

      final disc = previewDiscRect(tester)!;
      expect(disc.right, lessThanOrEqualTo(390.5));
      expect(disc.left, greaterThanOrEqualTo(-0.5));
      expect(disc.width, closeTo(disc.height, 0.5));
    });

    testWidgets(
        'a disc slides sideways instead of falling down while the hint is showing',
        (WidgetTester tester) async {
      // The falling-disc code itself is completely unmodified; it always
      // animates along the board's own local "down" axis. What changes here
      // is only that the whole composition is rotated 90° for display, so
      // that same local motion appears horizontal on the physical screen.
      await pumpScreen(tester, const Size(390, 844));

      final board = boardScreenRect(tester);
      await tester.tapAt(board.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final discFinder = find.byWidgetPredicate((widget) {
        if (widget is! DecoratedBox) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            decoration.color == const Color(0xFF00ACF8);
      });
      final rect1 = tester.getRect(discFinder.first);

      await tester.pump(const Duration(milliseconds: 150));
      final rect2 = tester.getRect(discFinder.first);

      expect(
        (rect2.center.dx - rect1.center.dx).abs(),
        greaterThan(20),
        reason: 'The disc should move noticeably sideways.',
      );
      expect(rect2.center.dy, closeTo(rect1.center.dy, 1.0));
    });
  });

  group('rotating the phone mid-game switches live, with no restart', () {
    testWidgets(
        'portrait hint -> landscape: board snaps from rotated to normal',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: FourInARowScreen(mode: GameMode.local)),
      );
      await tester.pumpAndSettle();

      final portraitRect = boardScreenRect(tester);
      expect(portraitRect.height, greaterThan(portraitRect.width));

      // The user physically turns the phone sideways.
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();

      final landscapeRect = boardScreenRect(tester);
      expect(landscapeRect.width, greaterThan(landscapeRect.height));
      expect(landscapeRect.width / landscapeRect.height, closeTo(7 / 6, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('board grows live when rotated further into landscape',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: FourInARowScreen(mode: GameMode.local)),
      );
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(1280, 720);
      await tester.pumpAndSettle();
      final rect1280 = boardScreenRect(tester);

      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      final rect844 = boardScreenRect(tester);

      // Both landscape sizes render the same normal, un-rotated shape.
      expect(rect1280.width, greaterThan(rect1280.height));
      expect(rect844.width, greaterThan(rect844.height));
    });
  });
}
