import 'dart:math';

import 'package:flutter/material.dart';
import '../data/games_registry.dart';
import '../models/game_definition.dart';
import '../widgets/game_card.dart';
import '../widgets/lobby_background.dart';
import '../widgets/lobby_palette.dart';
import 'game_details_screen.dart';

/// Game Lobby — every game in the catalogue, laid out on one painted scene.
///
/// UI is completely data-driven by [kGames] in [games_registry.dart].
/// Tapping an available game opens the generic [GameDetailsScreen].
class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  /// Starred games, by id. Kept for this run of the app only: there is no
  /// per-user storage on the device yet, and favourites are not worth
  /// inventing one for on their own.
  final Set<String> _favourites = {};

  final Random _random = Random();

  /// Favourites float to the front; everything else keeps the catalogue's
  /// own order.
  List<GameDefinition> get _orderedGames {
    final starred = <GameDefinition>[];
    final rest = <GameDefinition>[];
    for (final game in kGames) {
      (_favourites.contains(game.id) ? starred : rest).add(game);
    }
    return [...starred, ...rest];
  }

  void _openDetails(GameDefinition game) {
    if (game.status != GameStatus.available) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameDetailsScreen(game: game)),
    );
  }

  void _toggleFavourite(GameDefinition game) => setState(() {
        if (!_favourites.remove(game.id)) _favourites.add(game.id);
      });

  void _openRandomGame() {
    final playable =
        kGames.where((g) => g.status == GameStatus.available).toList();
    if (playable.isEmpty) return;
    _openDetails(playable[_random.nextInt(playable.length)]);
  }

  @override
  Widget build(BuildContext context) {
    final games = _orderedGames;

    return Stack(
      children: [
        const Positioned.fill(child: LobbyBackground()),
        SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                // Room at the bottom for the Random Play button, which
                // floats over the grid rather than scrolling with it.
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
                sliver: SliverGrid.builder(
                  // Sized by extent rather than a fixed two columns: a
                  // phone still gets two, but a tablet or a landscape
                  // window gets more of them instead of a handful of
                  // enormous cards (AGENTS.md §8.4).
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.88,
                  ),
                  itemCount: games.length,
                  itemBuilder: (context, index) {
                    final game = games[index];
                    return GameCard(
                      game: game,
                      isFavourite: _favourites.contains(game.id),
                      onToggleFavourite: () => _toggleFavourite(game),
                      onTap: () => _openDetails(game),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Center(
            child: _RandomPlayButton(onTap: _openRandomGame),
          ),
        ),
      ],
    );
  }
}

/// Opens one of the playable games at random -- the "just start something"
/// button, for players who do not want to choose.
class _RandomPlayButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RandomPlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LobbyPalette.purple,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: const BorderSide(color: LobbyPalette.ink, width: 3),
      ),
      elevation: 6,
      shadowColor: const Color(0x8014325C),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.casino_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Random Play',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
