import 'package:flutter/material.dart';
import '../data/favourite_games.dart';
import '../models/game_definition.dart';
import '../navigation/game_launcher.dart';

/// A generic, data-driven Game Details screen.
///
/// Renders game information, rules, and supported game modes dynamically
/// from the provided [game] definition without game-specific hardcoding.
class GameDetailsScreen extends StatefulWidget {
  final GameDefinition game;

  const GameDetailsScreen({
    super.key,
    required this.game,
  });

  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  final FavouriteGames _favourites = FavouriteGames.instance;

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

  void _showHowToPlay(BuildContext context) {
    final rules = widget.game.howToPlayRules;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.help_outline_rounded, color: colorScheme.primary, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'How to Play',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (rules.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Rules for this game will be available soon.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ...List.generate(
                    rules.length,
                    (index) => _buildRuleItem(
                      step: '${index + 1}',
                      description: rules[index],
                      colorScheme: colorScheme,
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Got it!'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRuleItem({
    required String step,
    required String description,
    required ColorScheme colorScheme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(fontSize: 14, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final game = widget.game;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Details'),
        actions: [
          // The same star the lobby card carries, backed by the same
          // set -- starring here pins the game at the top of the lobby.
          IconButton(
            icon: Icon(
              _favourites.contains(game.id)
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color:
                  _favourites.contains(game.id) ? const Color(0xFFFFC42E) : null,
            ),
            tooltip: _favourites.contains(game.id)
                ? 'Remove from favourites'
                : 'Add to favourites',
            onPressed: () => _favourites.toggle(game.id),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Game Banner ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      game.icon,
                      size: 40,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    game.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    game.description,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (game.tags.isNotEmpty)
                        ...game.tags.map((tag) => _buildChip(tag, colorScheme))
                      else
                        _buildChip('${game.playerCount} Players', colorScheme),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── How to Play Action ─────────────────────────────────────────
            InkWell(
              onTap: () => _showHowToPlay(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.help_outline_rounded, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'How to Play',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 16, color: colorScheme.outline),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Play Modes Section ─────────────────────────────────────────
            if (game.supportedModes.isNotEmpty) ...[
              Text(
                'CHOOSE GAME MODE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...game.supportedModes.map(
                (mode) {
                  final isAvailable = GameLauncher.isModeAvailable(game, mode);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildModeCard(
                      context: context,
                      mode: mode,
                      isAvailable: isAvailable,
                      onTap: () => GameLauncher.launch(context, game, mode),
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required GameMode mode,
    required bool isAvailable,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: isAvailable
          ? colorScheme.secondaryContainer.withValues(alpha: 0.4)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isAvailable ? colorScheme.primary.withValues(alpha: 0.3) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? colorScheme.primary
                      : colorScheme.outline.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  mode.icon,
                  color: isAvailable ? colorScheme.onPrimary : colorScheme.outline,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            mode.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isAvailable ? colorScheme.onSurface : colorScheme.outline,
                            ),
                          ),
                        ),
                        if (!isAvailable) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Soon',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.outline,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mode.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isAvailable
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.outline.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isAvailable ? colorScheme.primary : colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
