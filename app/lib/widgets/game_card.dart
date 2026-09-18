import 'package:flutter/material.dart';
import '../models/game_definition.dart';

/// Renders a single [GameDefinition] as a lobby card.
///
/// [featured] — when true renders the wide hero variant (for the top
/// featured section). Defaults to the compact grid variant.
///
/// Navigation is the caller's responsibility via [onTap] so this widget
/// stays pure and reusable.
class GameCard extends StatelessWidget {
  final GameDefinition game;
  final VoidCallback? onTap;
  final bool featured;

  const GameCard({
    super.key,
    required this.game,
    this.onTap,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    return featured
        ? _FeaturedCard(game: game, onTap: onTap)
        : _GridCard(game: game, onTap: onTap);
  }
}

// ---------------------------------------------------------------------------
// Featured (hero) variant
// ---------------------------------------------------------------------------

class _FeaturedCard extends StatelessWidget {
  final GameDefinition game;
  final VoidCallback? onTap;

  const _FeaturedCard({required this.game, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isAvailable = game.status == GameStatus.available;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: isAvailable ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PlayerCountBadge(
                      count: game.playerCount,
                      foreground: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      game.name,
                      style: textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      game.description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    if (isAvailable)
                      FilledButton(
                        onPressed: onTap,
                        child: const Text('Play Now'),
                      )
                    else
                      const _ComingSoonChip(),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                game.icon,
                size: 72,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact grid variant
// ---------------------------------------------------------------------------

class _GridCard extends StatelessWidget {
  final GameDefinition game;
  final VoidCallback? onTap;

  const _GridCard({required this.game, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isAvailable = game.status == GameStatus.available;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: isAvailable ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    game.icon,
                    size: 36,
                    color: isAvailable
                        ? colorScheme.primary
                        : colorScheme.outline,
                  ),
                  const Spacer(),
                  if (!isAvailable) const _ComingSoonChip(),
                ],
              ),
              const Spacer(),
              Text(
                game.name,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isAvailable
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              _PlayerCountBadge(
                count: game.playerCount,
                foreground: isAvailable
                    ? colorScheme.primary
                    : colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

class _PlayerCountBadge extends StatelessWidget {
  final int count;
  final Color foreground;

  const _PlayerCountBadge({required this.count, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.people_outline_rounded, size: 14, color: foreground),
        const SizedBox(width: 4),
        Text(
          '$count Players',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _ComingSoonChip extends StatelessWidget {
  const _ComingSoonChip();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Soon',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
