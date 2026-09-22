import 'package:app/data/games_registry.dart';
import 'package:app/models/game_definition.dart';
import 'package:app/screens/games_screen.dart';
import 'package:app/widgets/game_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpLobby(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: GamesScreen())),
  );
  await tester.pumpAndSettle();
}

List<String> _cardOrder(WidgetTester tester) => tester
    .widgetList<GameCard>(find.byType(GameCard))
    .map((card) => card.game.id)
    .toList();

Finder _starOn(String gameId) => find.descendant(
      of: find.byWidgetPredicate(
          (widget) => widget is GameCard && widget.game.id == gameId),
      matching: find.byIcon(Icons.star_outline_rounded),
    );

void main() {
  testWidgets('shows a card for every game in the catalogue',
      (WidgetTester tester) async {
    await _pumpLobby(tester);

    expect(find.byType(GameCard), findsNWidgets(kGames.length));
    for (final game in kGames) {
      expect(find.text(game.name), findsOneWidget);
    }
  });

  testWidgets('tapping a card opens that game\'s details',
      (WidgetTester tester) async {
    await _pumpLobby(tester);

    await tester.tap(find.text('Tic Tac Toe'));
    await tester.pumpAndSettle();

    expect(find.text('Game Details'), findsOneWidget);
    expect(find.text('Tic Tac Toe'), findsWidgets);
  });

  testWidgets('a coming-soon game is marked and cannot be opened',
      (WidgetTester tester) async {
    await _pumpLobby(tester);

    expect(find.text('Soon'), findsOneWidget);

    // The catalogue is long enough that the last card can start below the
    // fold on a phone.
    await tester.ensureVisible(find.text('Battleship'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Battleship'));
    await tester.pumpAndSettle();

    expect(find.text('Game Details'), findsNothing);
  });

  testWidgets('starring a game pulls it to the front without opening it',
      (WidgetTester tester) async {
    await _pumpLobby(tester);

    final firstBefore = _cardOrder(tester).first;
    expect(firstBefore, isNot('sling_puck'));

    await tester.tap(_starOn('sling_puck'));
    await tester.pumpAndSettle();

    expect(find.text('Game Details'), findsNothing,
        reason: 'the star is its own tap target, not the card');
    expect(_cardOrder(tester).first, 'sling_puck');
    expect(_cardOrder(tester).length, kGames.length);

    // And starring it again puts it back where it came from.
    await tester.tap(find.descendant(
      of: find.byWidgetPredicate(
          (widget) => widget is GameCard && widget.game.id == 'sling_puck'),
      matching: find.byIcon(Icons.star_rounded),
    ));
    await tester.pumpAndSettle();

    expect(_cardOrder(tester).first, firstBefore);
  });

  testWidgets('Random Play opens one of the playable games',
      (WidgetTester tester) async {
    await _pumpLobby(tester);

    await tester.tap(find.text('Random Play'));
    await tester.pumpAndSettle();

    expect(find.text('Game Details'), findsOneWidget);
    final playable = kGames
        .where((game) => game.status == GameStatus.available)
        .map((game) => game.name);
    expect(playable.where((name) => find.text(name).evaluate().isNotEmpty),
        isNotEmpty);
  });
}
