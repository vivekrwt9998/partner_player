import 'package:flutter/material.dart';
import '../models/game_definition.dart';

/// Renders a single [GameDefinition] as a lobby card: the game's name,
/// and a star to keep it near the top.
///
/// Navigation is the caller's responsibility via [onTap] so this widget
/// stays pure and reusable. The star is the same deal: the card only
/// reports the tap, the lobby decides what it means.
class GameCard extends StatelessWidget {
  final GameDefinition game;
  final VoidCallback? onTap;

  /// Whether the star in the corner is filled in.
  final bool isFavourite;

  /// Tapping the star. When null the star is not drawn at all.
  final VoidCallback? onToggleFavourite;

  const GameCard({
    super.key,
    required this.game,
    this.onTap,
    this.isFavourite = false,
    this.onToggleFavourite,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isAvailable = game.status == GameStatus.available;

    return Semantics(
      button: isAvailable,
      label: isAvailable ? game.name : '${game.name}, coming soon',
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          children: [
            Positioned.fill(
              child: InkWell(
                onTap: isAvailable ? onTap : null,
                child: Padding(
                  // Extra room on the right so a long name never runs
                  // under the star.
                  padding: const EdgeInsets.fromLTRB(14, 12, 36, 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        game.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: isAvailable
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (!isAvailable) ...[
                        const SizedBox(height: 8),
                        const _SoonChip(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (onToggleFavourite != null)
              Positioned(
                top: 2,
                right: 2,
                child: _FavouriteStar(
                  isOn: isFavourite,
                  onTap: onToggleFavourite!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FavouriteStar extends StatelessWidget {
  final bool isOn;
  final VoidCallback onTap;

  const _FavouriteStar({required this.isOn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: isOn ? 'Remove from favourites' : 'Add to favourites',
      child: IconButton(
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        iconSize: 20,
        icon: Icon(
          isOn ? Icons.star_rounded : Icons.star_outline_rounded,
          color: isOn ? const Color(0xFFFFC42E) : colorScheme.outline,
        ),
      ),
    );
  }
}

/// Marks a game that is in the catalogue but has no gameplay screen yet.
class _SoonChip extends StatelessWidget {
  const _SoonChip();

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
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
