import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/main.dart';
import 'package:app/widgets/game_result_dialog.dart';

void main() {
  testWidgets('Complete Flow: Lobby -> Details -> Landscape Gameplay with Options Menu & Revert',
      (WidgetTester tester) async {
    // Set landscape window size for test environment
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const PartnerGameApp());
    await tester.pumpAndSettle();

    // 1. Verify Lobby
    expect(find.text('Games'), findsWidgets);
    expect(find.text('Four in a Row'), findsOneWidget);

    // 2. Tap Four in a Row in Lobby -> Opens Game Details
    await tester.tap(find.text('Four in a Row'));
    await tester.pumpAndSettle();

    expect(find.text('Game Details'), findsOneWidget);
    expect(find.text('How to Play'), findsOneWidget);
    expect(find.text('Play with Local'), findsOneWidget);
    expect(find.text('Play with Bot'), findsOneWidget);
    expect(find.text('Play Online'), findsOneWidget);

    // 3. Test Favorite Toggle
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    // 4. Tap "Play with Local" -> Enters Landscape Gameplay Screen
    await tester.ensureVisible(find.text('Play with Local'));
    await tester.tap(find.text('Play with Local'));
    await tester.pumpAndSettle();

    // 5. Verify Landscape Gameplay UI: Player 1 (Blue) & Player 2 (Red) & Semicircle Turn Indicators
    expect(find.text('Player 1'), findsOneWidget);
    expect(find.text('Player 2'), findsOneWidget);
    expect(find.text('BLUE TURN'), findsOneWidget);
    expect(find.text('RED TURN'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

    // 6. Test Options Menu (Revert, Restart, Exit Game)
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Revert'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Exit Game'), findsOneWidget);

    // Tap outside to dismiss options menu
    await tester.tapAt(const Offset(100, 100));
    await tester.pumpAndSettle();

    // 7. Test Exit Game via Options Menu -> Returns to Game Details
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit Game'));
    await tester.pumpAndSettle();
    expect(find.text('Game Details'), findsOneWidget);

    // 8. Back to Lobby
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Games'), findsWidgets);
    expect(find.text('Four in a Row'), findsOneWidget);
  });

  testWidgets('GameResultDialog displays winner, countdown, and triggers Play Again',
      (WidgetTester tester) async {
    bool playAgainCalled = false;
    bool exitCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  GameResultDialog.show(
                    context,
                    title: 'BLUE PLAYER WIN',
                    themeColor: const Color(0xFF00ACF8),
                    icon: Icons.emoji_events_rounded,
                    onPlayAgain: () => playAgainCalled = true,
                    onExit: () => exitCalled = true,
                    autoExitSeconds: 3,
                  );
                },
                child: const Text('Show Result'),
              ),
            ),
          ),
        ),
      ),
    );

    // Open result dialog
    await tester.tap(find.text('Show Result'));
    await tester.pumpAndSettle();

    expect(find.text('BLUE PLAYER WIN'), findsOneWidget);
    expect(find.text('Auto exit in 3'), findsOneWidget);
    expect(find.text('Play Again'), findsOneWidget);
    expect(find.text('Exit'), findsOneWidget);

    // Advance 1 second -> Auto exit in 2
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Auto exit in 2'), findsOneWidget);

    // Tap Play Again
    await tester.tap(find.text('Play Again'));
    await tester.pumpAndSettle();

    expect(playAgainCalled, isTrue);
    expect(exitCalled, isFalse);
    expect(find.text('BLUE PLAYER WIN'), findsNothing);
  });
}
