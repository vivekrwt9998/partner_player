import 'package:flutter/material.dart';
import '../models/game_definition.dart';
import 'game_artwork.dart';
import 'lobby_palette.dart';

/// Renders a single [GameDefinition] as a lobby card: its own board drawn
/// as a cartoon scene, with the game's name across the bottom.
///
/// Navigation is the caller's responsibility via [onTap] so this widget
/// stays pure and reusable. The favourite star is the same deal: the card
/// only reports the tap, the lobby decides what it means.
class GameCard extends StatefulWidget {
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
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final isAvailable = game.status == GameStatus.available;

    return Semantics(
      button: isAvailable,
      label: isAvailable ? game.name : '${game.name}, coming soon',
      // The whole card is one tap target, handled above the artwork rather
      // than by an InkWell laid over it: a ripple would have to sit on top
      // of the name to be visible, which puts a transparent widget between
      // the name and the finger. A squash on press reads better here
      // anyway, and keeps the card's own content hit-testable.
      child: GestureDetector(
        onTap: isAvailable ? widget.onTap : null,
        onTapDown: isAvailable ? (_) => _setPressed(true) : null,
        onTapUp: isAvailable ? (_) => _setPressed(false) : null,
        onTapCancel: isAvailable ? () => _setPressed(false) : null,
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: LobbyPalette.ink, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4014325C),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              // Inside the border, so the artwork never bleeds over it.
              borderRadius: BorderRadius.circular(17),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GameArtwork(gameId: game.id),
                  if (!isAvailable) const ColoredBox(color: Color(0x66102340)),

                  // A scrim so the name stays readable over whatever the
                  // artwork happens to put behind it.
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x0014325C), Color(0xCC14325C)],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 8,
                    child: _CardTitle(game.name),
                  ),

                  if (widget.onToggleFavourite != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _FavouriteStar(
                        isOn: widget.isFavourite,
                        onTap: widget.onToggleFavourite!,
                      ),
                    ),

                  if (!isAvailable)
                    const Positioned(top: 8, left: 8, child: _SoonChip()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces of the card
// ---------------------------------------------------------------------------

/// The game's name in the chunky, dark-outlined lettering the rest of the
/// lobby uses.
///
/// The outline is four hard offset shadows rather than a second stroked
/// [Text] behind this one: stacking two copies would put the game's name in
/// the widget tree twice, which makes every `find.text` in a test -- and
/// every screen reader -- see it twice.
class _CardTitle extends StatelessWidget {
  final String name;

  const _CardTitle(this.name);

  static const List<Shadow> _outline = [
    Shadow(color: LobbyPalette.ink, offset: Offset(-1.6, -1.6)),
    Shadow(color: LobbyPalette.ink, offset: Offset(1.6, -1.6)),
    Shadow(color: LobbyPalette.ink, offset: Offset(-1.6, 1.6)),
    Shadow(color: LobbyPalette.ink, offset: Offset(1.6, 1.6)),
    Shadow(color: Color(0x8014325C), offset: Offset(0, 3), blurRadius: 4),
  ];

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        height: 1.05,
        letterSpacing: 0.2,
        color: Colors.white,
        shadows: _outline,
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
    return Semantics(
      button: true,
      label: isOn ? 'Remove from favourites' : 'Add to favourites',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: LobbyPalette.navy,
            shape: BoxShape.circle,
            border: Border.all(color: LobbyPalette.ink, width: 2),
          ),
          child: Icon(
            isOn ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 19,
            color: isOn ? LobbyPalette.sun : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _SoonChip extends StatelessWidget {
  const _SoonChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: LobbyPalette.sun,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LobbyPalette.ink, width: 2),
      ),
      child: const Text(
        'Soon',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: LobbyPalette.ink,
        ),
      ),
    );
  }
}
