import 'package:flutter/material.dart';
import '../data/games_registry.dart';
import '../models/game_definition.dart';
import '../widgets/game_card.dart';
import 'game_details_screen.dart';

/// Game Lobby — displays all available and upcoming games.
///
/// UI is completely data-driven by [kGames] in [games_registry.dart].
/// Tapping an available game opens the generic [GameDetailsScreen].
class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  void _navigateToDetails(BuildContext context, GameDefinition game) {
    if (game.status != GameStatus.available) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameDetailsScreen(game: game),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        // ── App bar ────────────────────────────────────────────────
        SliverAppBar(
          pinned: true,
          backgroundColor: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          title: Text(
            'Games',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),

        // ── Games grid ─────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemCount: kGames.length,
            itemBuilder: (context, index) {
              final game = kGames[index];
              return GameCard(
                game: game,
                onTap: game.status == GameStatus.available
                    ? () => _navigateToDetails(context, game)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
