import 'dart:math';

import 'package:flutter/material.dart';
import '../data/favourite_games.dart';
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
  /// Shared with the Game Details screen, so a game starred from either
  /// place is pinned in both.
  final FavouriteGames _favourites = FavouriteGames.instance;

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _favourites.addListener(_onFavouritesChanged);
  }

  @override
  void dispose() {
    _favourites.removeListener(_onFavouritesChanged);
    super.dispose();
  }

  void _onFavouritesChanged() {
    if (mounted) setState(() {});
  }

  void _openDetails(GameDefinition game) {
    if (game.status != GameStatus.available) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameDetailsScreen(game: game)),
    );
  }

  void _openRandomGame() {
    final playable =
        kGames.where((g) => g.status == GameStatus.available).toList();
    if (playable.isEmpty) return;
    _openDetails(playable[_random.nextInt(playable.length)]);
  }

  @override
  Widget build(BuildContext context) {
    final games = _favourites.pinnedFirst(kGames, (game) => game.id);

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
                  //
                  // A card carries only the game's name, so it wants to be
                  // wide and short rather than square.
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: games.length,
                  itemBuilder: (context, index) {
                    final game = games[index];
                    return GameCard(
                      game: game,
                      isFavourite: _favourites.contains(game.id),
                      onToggleFavourite: () => _favourites.toggle(game.id),
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
