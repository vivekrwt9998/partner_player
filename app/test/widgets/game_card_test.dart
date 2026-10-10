import 'package:app/models/game_definition.dart';
import 'package:app/widgets/game_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A game that exists in the catalogue but has no gameplay screen yet.
///
/// Built here rather than taken from `kGames`: every entry in the
/// catalogue is playable today, and the card still has to handle the
/// coming-soon case for whenever the next placeholder is added.
const _comingSoon = GameDefinition(
  id: 'not_built_yet',
  name: 'Not Built Yet',
  description: 'A placeholder with no screen behind it.',
  icon: Icons.construction_rounded,
  playerCount: 2,
  status: GameStatus.comingSoon,
  orientationBehavior: GameOrientationBehavior.adaptive,
);

const _available = GameDefinition(
  id: 'ready_to_play',
  name: 'Ready To Play',
  description: 'A game with a screen behind it.',
  icon: Icons.videogame_asset_rounded,
  playerCount: 2,
  status: GameStatus.available,
  orientationBehavior: GameOrientationBehavior.fixedPortrait,
);

Future<void> _pumpCard(
  WidgetTester tester,
  GameDefinition game, {
  VoidCallback? onTap,
  bool withStar = false,
  bool isFavourite = false,
  VoidCallback? onToggleFavourite,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 200,
            height: 140,
            child: GameCard(
              game: game,
              onTap: onTap,
              isFavourite: isFavourite,
              onToggleFavourite: withStar ? (onToggleFavourite ?? () {}) : null,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the game name, once', (WidgetTester tester) async {
    await _pumpCard(tester, _available);

    expect(find.text('Ready To Play'), findsOneWidget);
    expect(find.text('Soon'), findsNothing);
  });

  testWidgets('an available game reports its tap', (WidgetTester tester) async {
    var taps = 0;
    await _pumpCard(tester, _available, onTap: () => taps++);

    await tester.tap(find.text('Ready To Play'));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('a coming-soon game is marked and cannot be opened',
      (WidgetTester tester) async {
    var taps = 0;
    await _pumpCard(tester, _comingSoon, onTap: () => taps++);

    expect(find.text('Not Built Yet'), findsOneWidget);
    expect(find.text('Soon'), findsOneWidget);

    await tester.tap(find.text('Not Built Yet'));
    await tester.pumpAndSettle();

    expect(taps, 0, reason: 'there is nothing to open');
  });

  testWidgets('the star only appears when the lobby wants one',
      (WidgetTester tester) async {
    await _pumpCard(tester, _available);
    expect(find.byIcon(Icons.star_outline_rounded), findsNothing);

    await _pumpCard(tester, _available, withStar: true);
    expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);

    await _pumpCard(tester, _available, withStar: true, isFavourite: true);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('tapping the star does not open the game',
      (WidgetTester tester) async {
    var taps = 0;
    var stars = 0;
    await _pumpCard(
      tester,
      _available,
      onTap: () => taps++,
      withStar: true,
      onToggleFavourite: () => stars++,
    );

    await tester.tap(find.byIcon(Icons.star_outline_rounded));
    await tester.pumpAndSettle();

    expect(stars, 1);
    expect(taps, 0, reason: 'the star is its own tap target');
  });
}
