import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/main.dart';
import 'package:app/screens/game_result_screen.dart';
import 'package:app/screens/games/four_in_a_row/four_in_a_row_screen.dart';

void main() {
  testWidgets('Complete Flow: Lobby -> Details -> Landscape Gameplay with Single Active Indicator',
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

    // 3. Tap "Play with Local" -> Enters Landscape Gameplay Screen
    await tester.ensureVisible(find.text('Play with Local'));
    await tester.tap(find.text('Play with Local'));
    await tester.pumpAndSettle();

    // 4. Verify Landscape Gameplay UI: Blue's turn is active initially
    expect(find.text('BLUE TURN'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

    // 5. Test Options Menu (Revert, Restart, Exit Game)
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Revert'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Exit Game'), findsOneWidget);

    // Tap outside to dismiss options menu
    await tester.tapAt(const Offset(100, 100));
    await tester.pumpAndSettle();

    // 6. Test Exit Game via Options Menu -> Returns to Game Details
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit Game'));
    await tester.pumpAndSettle();
    expect(find.text('Game Details'), findsOneWidget);

    // 7. Back to Lobby
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Games'), findsWidgets);
    expect(find.text('Four in a Row'), findsOneWidget);
  });

  testWidgets('GameResultScreen displays winner, countdown, and triggers Play Again',
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
                  GameResultScreen.show(
                    context,
                    resultData: GameResultData.blueWin(label: 'BLUE PLAYER\nWINS!'),
                    onPlayAgain: () => playAgainCalled = true,
                    onExit: () => exitCalled = true,
                  );
                },
                child: const Text('Show Result'),
              ),
            ),
          ),
        ),
      ),
    );

    // Open result screen
    await tester.tap(find.text('Show Result'));
    await tester.pumpAndSettle();

    expect(find.text('BLUE PLAYER\nWINS!'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('PLAY AGAIN'), findsOneWidget);
    expect(find.text('EXIT'), findsOneWidget);

    // Advance 1 second -> Countdown becomes 2
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2'), findsOneWidget);

    // Tap Play Again
    await tester.tap(find.text('PLAY AGAIN'));
    await tester.pumpAndSettle();

    expect(playAgainCalled, isTrue);
    expect(exitCalled, isFalse);
    expect(find.text('BLUE PLAYER\nWINS!'), findsNothing);
  });

  testWidgets('Bot mode opens the shared gameplay screen without Revert',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const PartnerGameApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Four in a Row'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Play with Bot'));
    await tester.tap(find.text('Play with Bot'));
    await tester.pumpAndSettle();

    expect(find.byType(FourInARowScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Exit Game'), findsOneWidget);
    expect(find.text('Revert'), findsNothing);
  });
}
