import 'package:app/models/game_definition.dart';
import 'package:app/widgets/turn_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the reusable, game-agnostic turn indicator system (AGENTS.md
/// §10.1.4 / §10.1.6). Each layout is exercised directly through
/// [TurnIndicatorOverlay] so any game can rely on this contract without a
/// game-specific reimplementation.
void main() {
  const blue = TurnIndicatorSpec(
    color: Color(0xFF00ACF8),
    label: 'BLUE TURN',
    isActive: true,
  );
  const red = TurnIndicatorSpec(
    color: Color(0xFFFF5E57),
    label: 'RED TURN',
    isActive: false,
  );

  Future<void> pumpOverlay(
    WidgetTester tester, {
    required TurnIndicatorLayout layout,
    required TurnIndicatorSpec first,
    required TurnIndicatorSpec second,
    bool isGameOver = false,
    Size size = const Size(400, 800),
    VoidCallback? onTapUnderneath,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              if (onTapUnderneath != null)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTapUnderneath,
                  ),
                ),
              Positioned.fill(
                child: TurnIndicatorOverlay(
                  layout: layout,
                  first: first,
                  second: second,
                  isGameOver: isGameOver,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('sideBySide layout', () {
    testWidgets('only the active player badge is visible', (tester) async {
      await pumpOverlay(
        tester,
        layout: TurnIndicatorLayout.sideBySide,
        first: blue,
        second: red,
      );

      final blueOpacity =
          tester.widget<AnimatedOpacity>(find.ancestor(
        of: find.text('BLUE TURN'),
        matching: find.byType(AnimatedOpacity),
      ));
      final redOpacity = tester.widget<AnimatedOpacity>(find.ancestor(
        of: find.text('RED TURN'),
        matching: find.byType(AnimatedOpacity),
      ));

      expect(blueOpacity.opacity, 1.0);
      expect(redOpacity.opacity, 0.0);
    });

    testWidgets('left badge sits at the left edge, right at the right edge',
        (tester) async {
      await pumpOverlay(
        tester,
        layout: TurnIndicatorLayout.sideBySide,
        first: blue,
        second: red,
      );

      final screenWidth = tester.view.physicalSize.width /
          tester.view.devicePixelRatio;
      final blueRect = tester.getRect(
        find.ancestor(
          of: find.text('BLUE TURN'),
          matching: find.byType(AnimatedSlide),
        ),
      );
      final redRect = tester.getRect(
        find.ancestor(
          of: find.text('RED TURN'),
          matching: find.byType(AnimatedSlide),
        ),
      );

      expect(blueRect.left, closeTo(0, 0.01));
      expect(redRect.right, closeTo(screenWidth, 0.01));
      // Mirrored: identical size regardless of which one is active.
      expect(blueRect.width, closeTo(redRect.width, 0.01));
    });

    testWidgets('badge is compact: far smaller than a fixed oversized shape',
        (tester) async {
      // Same viewport the game screen used to render a fixed 168px-radius
      // badge from; the reusable, content-fit version must be meaningfully
      // smaller while keeping the same readable font-size ceiling (22).
      await pumpOverlay(
        tester,
        layout: TurnIndicatorLayout.sideBySide,
        first: blue,
        second: red,
        size: const Size(1280, 720),
      );

      final blueRect = tester.getRect(
        find.ancestor(
          of: find.text('BLUE TURN'),
          matching: find.byType(AnimatedSlide),
        ),
      );

      expect(blueRect.width, lessThan(150));
      expect(blueRect.width, greaterThan(80));

      final blueTextStyle = tester.widget<Text>(find.text('BLUE TURN')).style;
      expect(blueTextStyle?.fontSize, greaterThanOrEqualTo(16.0));
    });

    testWidgets('all indicators are non-interactive and never block taps',
        (tester) async {
      var tapped = false;
      await pumpOverlay(
        tester,
        layout: TurnIndicatorLayout.sideBySide,
        first: blue,
        second: red,
        onTapUnderneath: () => tapped = true,
      );

      // Tap squarely inside the visible blue badge's bounding box.
      final blueRect = tester.getRect(
        find.ancestor(
          of: find.text('BLUE TURN'),
          matching: find.byType(AnimatedSlide),
        ),
      );
      await tester.tapAt(blueRect.center);
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('hides both badges once the game is over', (tester) async {
      await pumpOverlay(
        tester,
        layout: TurnIndicatorLayout.sideBySide,
        first: blue,
        second: red,
        isGameOver: true,
      );

      final blueOpacity = tester.widget<AnimatedOpacity>(find.ancestor(
        of: find.text('BLUE TURN'),
        matching: find.byType(AnimatedOpacity),
      ));
      final redOpacity = tester.widget<AnimatedOpacity>(find.ancestor(
        of: find.text('RED TURN'),
        matching: find.byType(AnimatedOpacity),
      ));
      expect(blueOpacity.opacity, 0.0);
      expect(redOpacity.opacity, 0.0);
    });
  });

  group('faceToFace layout', () {
    testWidgets(
        'first (near/local) player is bottom, second (far/opponent) is top',
        (tester) async {
      await pumpOverlay(
        tester,
        layout: TurnIndicatorLayout.faceToFace,
        first: blue,
        second: red,
      );

      final screenHeight = tester.view.physicalSize.height /
          tester.view.devicePixelRatio;
      final blueRect = tester.getRect(
        find.ancestor(
          of: find.text('BLUE TURN'),
          matching: find.byType(AnimatedSlide),
        ),
      );
      final redRect = tester.getRect(
        find.ancestor(
          of: find.text('RED TURN'),
          matching: find.byType(AnimatedSlide),
        ),
      );

      // Correct player association: first (Blue) hugs the bottom edge,
      // second (Red) hugs the top edge — they never swap sides.
      expect(blueRect.bottom, closeTo(screenHeight, 0.01));
      expect(redRect.top, closeTo(0, 0.01));
      expect(blueRect.center.dy, greaterThan(redRect.center.dy));
    });

    testWidgets('only the active player badge is visible, text stays centered',
        (tester) async {
      await pumpOverlay(
        tester,
        layout: TurnIndicatorLayout.faceToFace,
        first: blue,
        second: red,
      );

      final blueOpacity = tester.widget<AnimatedOpacity>(find.ancestor(
        of: find.text('BLUE TURN'),
        matching: find.byType(AnimatedOpacity),
      ));
      final redOpacity = tester.widget<AnimatedOpacity>(find.ancestor(
        of: find.text('RED TURN'),
        matching: find.byType(AnimatedOpacity),
      ));
      expect(blueOpacity.opacity, 1.0);
      expect(redOpacity.opacity, 0.0);

      final blueText = tester.widget<Text>(find.text('BLUE TURN'));
      expect(blueText.textAlign, TextAlign.center);
    });

    testWidgets('top and bottom badges never overlap', (tester) async {
      // A short, wide viewport is the tightest vertical squeeze for two
      // edge-anchored badges to avoid colliding.
      const activeBlue = TurnIndicatorSpec(
        color: Color(0xFF00ACF8),
        label: 'BLUE TURN',
        isActive: true,
      );
      const activeRed = TurnIndicatorSpec(
        color: Color(0xFFFF5E57),
        label: 'RED TURN',
        isActive: true,
      );

      await pumpOverlay(
        tester,
        layout: TurnIndicatorLayout.faceToFace,
        first: activeBlue,
        second: activeRed,
        size: const Size(800, 360),
      );

      final blueRect = tester.getRect(
        find.ancestor(
          of: find.text('BLUE TURN'),
          matching: find.byType(AnimatedSlide),
        ),
      );
      final redRect = tester.getRect(
        find.ancestor(
          of: find.text('RED TURN'),
          matching: find.byType(AnimatedSlide),
        ),
      );

      expect(blueRect.top, greaterThanOrEqualTo(redRect.bottom));
    });

    testWidgets('hides both badges once the game is over', (tester) async {
      await pumpOverlay(
        tester,
        layout: TurnIndicatorLayout.faceToFace,
        first: blue,
        second: red,
        isGameOver: true,
      );

      final blueOpacity = tester.widget<AnimatedOpacity>(find.ancestor(
        of: find.text('BLUE TURN'),
        matching: find.byType(AnimatedOpacity),
      ));
      final redOpacity = tester.widget<AnimatedOpacity>(find.ancestor(
        of: find.text('RED TURN'),
        matching: find.byType(AnimatedOpacity),
      ));
      expect(blueOpacity.opacity, 0.0);
      expect(redOpacity.opacity, 0.0);
    });
  });

  group('simultaneous layout', () {
    testWidgets('renders nothing at all -- a game with no turns has none to show',
        (tester) async {
      await pumpOverlay(
        tester,
        layout: TurnIndicatorLayout.simultaneous,
        first: blue,
        second: red,
      );

      expect(find.text('BLUE TURN'), findsNothing);
      expect(find.text('RED TURN'), findsNothing);
      expect(find.byType(AnimatedOpacity), findsNothing);
    });
  });

  group('passAndPlay layout', () {
    testWidgets('shows a single bottom-center indicator for the active player',
        (tester) async {
      await pumpOverlay(
        tester,
        layout: TurnIndicatorLayout.passAndPlay,
        first: blue,
        second: red,
      );

      expect(find.text('BLUE TURN'), findsOneWidget);
      expect(find.text('RED TURN'), findsNothing);

      final blueText = tester.widget<Text>(find.text('BLUE TURN'));
      expect(blueText.textAlign, TextAlign.center);

      final screenWidth = tester.view.physicalSize.width /
          tester.view.devicePixelRatio;
      final rect = tester.getRect(find.text('BLUE TURN'));
      expect(rect.center.dx, closeTo(screenWidth / 2, 1.0));
    });

    testWidgets('follows whichever player is active, not a fixed side',
        (tester) async {
      const activeRed = TurnIndicatorSpec(
        color: Color(0xFFFF5E57),
        label: 'RED TURN',
        isActive: true,
      );
      const idleBlue = TurnIndicatorSpec(
        color: Color(0xFF00ACF8),
        label: 'BLUE TURN',
        isActive: false,
      );

      await pumpOverlay(
        tester,
        layout: TurnIndicatorLayout.passAndPlay,
        first: idleBlue,
        second: activeRed,
      );

      expect(find.text('RED TURN'), findsOneWidget);
      expect(find.text('BLUE TURN'), findsNothing);
    });
  });
}
