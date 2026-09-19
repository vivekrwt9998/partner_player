import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../data/games_registry.dart';
import '../../../models/game_definition.dart';
import '../../../games/four_in_a_row/logic/four_in_a_row_game.dart';
import '../../../games/four_in_a_row/models/four_in_a_row_models.dart';
import '../../../games/four_in_a_row/presentation/four_in_a_row_match_controller.dart';
import '../../../widgets/turn_indicator.dart';
import '../../game_result_screen.dart';

/// Four in a Row landscape gameplay screen matching the exact reference design.
///
/// Shared board metrics used by every board layer.
///
/// The socket layer, the disc layer, the punched board surface and the winning
/// line all derive their positions from this single source of truth, so a disc
/// always lines up exactly with the hole it belongs to.
class _BoardGeometry {
  /// Grid inset from the board frame (left/right/top).
  static const double framePadding = 12.0;

  /// Grid inset from the bottom of the board frame.
  static const double frameBottomPadding = 8.0;

  /// Gap between a cell box and the disc/hole drawn inside it.
  static const double cellInset = 3.5;

  /// Thickness of the black board frame border.
  static const double frameBorderWidth = 5.0;

  /// Corner radius of the board frame.
  static const double frameRadius = 28.0;

  /// Thickness of the black rim drawn around every hole.
  static const double holeRimWidth = 4.0;

  final Size size;
  final double cellWidth;
  final double cellHeight;
  final double discSize;

  const _BoardGeometry._({
    required this.size,
    required this.cellWidth,
    required this.cellHeight,
    required this.discSize,
  });

  factory _BoardGeometry.fromSize(Size size) {
    final cellWidth = (size.width - (framePadding * 2)) / FourInARowGame.cols;
    final cellHeight =
        (size.height - framePadding - frameBottomPadding) / FourInARowGame.rows;
    final discSize = math.min(cellWidth, cellHeight) - (cellInset * 2);

    return _BoardGeometry._(
      size: size,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      discSize: discSize > 0 ? discSize : 0,
    );
  }

  double get discRadius => discSize / 2;

  /// Center of the hole at [row]/[col], in board-local coordinates.
  Offset centerOf(int row, int col) {
    return Offset(
      framePadding + (col * cellWidth) + (cellWidth / 2),
      framePadding + (row * cellHeight) + (cellHeight / 2),
    );
  }

  /// Top-left corner of the disc that belongs to [row]/[col].
  Offset discOriginOf(int row, int col) {
    final center = centerOf(row, col);
    return Offset(center.dx - discRadius, center.dy - discRadius);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BoardGeometry &&
          size == other.size &&
          cellWidth == other.cellWidth &&
          cellHeight == other.cellHeight &&
          discSize == other.discSize;

  @override
  int get hashCode => Object.hash(size, cellWidth, cellHeight, discSize);
}

/// Paints the physical front surface of the board: the charcoal panel with a
/// hole punched out for every slot, the frame border and the hole rims.
///
/// This layer is painted *above* the disc layer, so a disc is only ever visible
/// through a hole. That is what makes a disc look like it travels inside the
/// board and settles into a hole instead of sliding across the board surface.
class _BoardSurfacePainter extends CustomPainter {
  final _BoardGeometry geometry;
  final Color surfaceColor;

  const _BoardSurfacePainter({
    required this.geometry,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_BoardGeometry.frameRadius),
    );

    final holes = Path();
    for (int row = 0; row < FourInARowGame.rows; row++) {
      for (int col = 0; col < FourInARowGame.cols; col++) {
        holes.addOval(
          Rect.fromCircle(
            center: geometry.centerOf(row, col),
            radius: geometry.discRadius,
          ),
        );
      }
    }

    // Board panel with the holes cut out of it.
    final surface = Path.combine(
      PathOperation.difference,
      Path()..addRRect(outer),
      holes,
    );
    canvas.drawPath(
      surface,
      Paint()
        ..color = surfaceColor
        ..style = PaintingStyle.fill,
    );

    // Frame border, painted here so a disc entering the board is occluded by it.
    canvas.drawRRect(
      outer.deflate(_BoardGeometry.frameBorderWidth / 2),
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = _BoardGeometry.frameBorderWidth,
    );

    // Rim of every hole, painted over the disc so the hole edge always wins.
    final rimRadius = geometry.discRadius - (_BoardGeometry.holeRimWidth / 2);
    if (rimRadius <= 0) return;

    final rimPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = _BoardGeometry.holeRimWidth;
    for (int row = 0; row < FourInARowGame.rows; row++) {
      for (int col = 0; col < FourInARowGame.cols; col++) {
        canvas.drawCircle(geometry.centerOf(row, col), rimRadius, rimPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardSurfacePainter oldDelegate) {
    return oldDelegate.geometry != geometry ||
        oldDelegate.surfaceColor != surfaceColor;
  }
}

/// While the physical device is portrait, rotates [child] 90° so the screen
/// visibly reads as the landscape composition it is — a "please turn your
/// phone" cue, matching how many landscape-only games behave, rather than
/// the game being comfortably playable while held portrait. The moment the
/// device is actually landscape, [child] renders completely normally with
/// no rotation at all: that is the real, played experience, and every bit
/// of board/animation code inside [child] is untouched by this wrapper —
/// it only ever changes how the *already-correct* output is displayed.
///
/// This is a pure software pixel transform. It never calls
/// `SystemChrome.setPreferredOrientations` and never touches the device's
/// actual physical orientation (AGENTS.md §8.2); it is also intentionally
/// local to this one screen, not a reusable/global orientation service
/// (AGENTS.md §54 — no infrastructure beyond what this game needs today).
class _PortraitRotationHint extends StatelessWidget {
  final Widget child;

  const _PortraitRotationHint({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final physicalSize = constraints.biggest;
        final isPortrait = physicalSize.height > physicalSize.width;
        if (!isPortrait) return child;

        final mq = MediaQuery.of(context);

        return OverflowBox(
          alignment: Alignment.center,
          minWidth: physicalSize.height,
          maxWidth: physicalSize.height,
          minHeight: physicalSize.width,
          maxHeight: physicalSize.width,
          child: Transform.rotate(
            angle: math.pi / 2,
            child: MediaQuery(
              data: mq.copyWith(
                size: Size(physicalSize.height, physicalSize.width),
                padding: _rotateClockwise(mq.padding),
                viewPadding: _rotateClockwise(mq.viewPadding),
                viewInsets: _rotateClockwise(mq.viewInsets),
              ),
              child: SizedBox(
                width: physicalSize.height,
                height: physicalSize.width,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Remaps [insets] the way its edges land after the content is rotated
  /// 90° clockwise to fill the physical portrait screen: the content's left
  /// edge ends up at the physical top, its top edge at the physical right,
  /// its right edge at the physical bottom, and its bottom edge at the
  /// physical left.
  static EdgeInsets _rotateClockwise(EdgeInsets insets) {
    return EdgeInsets.fromLTRB(
      insets.top,
      insets.right,
      insets.bottom,
      insets.left,
    );
  }
}

/// Visual Specifications:
/// - Dynamic background: soft blue on Blue turn, soft coral on Red turn
/// - Centered Dark Navy Blue board (#0D2F62) with intentional surrounding background spacing
/// - Floating turn indicators near the bottom corners
/// - 3-dot options menu in top right (Revert, Restart, Exit Game)
/// - Normal discs with animated glowing white winning line & node dots
/// - Seamless transition to full-screen celebratory GameResultScreen
class FourInARowScreen extends StatefulWidget {
  final GameMode mode;

  const FourInARowScreen({
    super.key,
    this.mode = GameMode.local,
  });

  @override
  State<FourInARowScreen> createState() => _FourInARowScreenState();
}

class _FourInARowScreenState extends State<FourInARowScreen>
  with TickerProviderStateMixin {
  late final FourInARowMatchController _matchController;

  /// This game's metadata, looked up once so the turn indicator layout is
  /// driven by configuration rather than hardcoded in this screen (AGENTS.md
  /// §10.1.6).
  static final GameDefinition _definition =
      kGames.firstWhere((g) => g.id == 'four_in_a_row');

  // Color Palette matching design specification
  static const Color _bluePlayerColor = Color(0xFF00ACF8); // Blue Player Disc
  static const Color _redPlayerColor = Color(0xFFFF5E57); // Red Player Disc
  static const Color _blueBgColor = Color(0xFF63C5F0); // Blue Turn Background
  static const Color _redBgColor = Color(0xFFF28D88); // Red Turn Background
  static const Color _boardColor = Color(0xFF303943); // Charcoal Board
  static const Color _holeColor = Color(0xFF58636F); // Grey Empty Slot

  late final AnimationController _winningLineController;
  late final Animation<double> _winningLineAnimation;
  late final AnimationController _fallingDiscController;
  FourInARowMove? _fallingDisc;
  int _previewColumn = FourInARowGame.cols ~/ 2;
  bool _isTransitioningToResult = false;
  bool _isOptionsMenuOpen = false;
  Timer? _resultTransitionTimer;

  @override
  void initState() {
    super.initState();
    _matchController = FourInARowMatchController(mode: widget.mode)
      ..addListener(_onMatchStateChanged);
    // Four in a Row's board is landscape-*style*, but that is a layout
    // choice, not a physical device rotation (AGENTS.md §8). The board below
    // adapts to whatever orientation the device is already in.

    _winningLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _winningLineAnimation = CurvedAnimation(
      parent: _winningLineController,
      curve: Curves.easeInOutCubic,
    );

    _fallingDiscController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          // The disc has visually landed: only now may the destination cell
          // take its occupied state and the winning line appear.
          final landedMove = _fallingDisc;
          setState(() {
            _fallingDisc = null;
          });
          if (landedMove?.status == FourInARowGameStatus.won) {
            _winningLineController.forward(from: 0.0);
          }
          _matchController.onMoveAnimationCompleted();
          if (_matchController.isResultReady) {
            _scheduleResultTransition();
          }
        }
      });
  }

  @override
  void dispose() {
    _resultTransitionTimer?.cancel();
    _matchController
      ..removeListener(_onMatchStateChanged)
      ..dispose();
    _winningLineController.dispose();
    _fallingDiscController.dispose();
    super.dispose();
  }

  void _onColumnTap(int col) {
    if (_isTransitioningToResult) return;
    _matchController.submitLocalColumn(col);
  }

  void _revertMove() {
    if (!_matchController.canRevert || _isTransitioningToResult) return;
    _matchController.revert();
    setState(() {
      _winningLineController.reset();
      _fallingDiscController.reset();
      _fallingDisc = null;
    });
  }

  void _restartGame() {
    _resultTransitionTimer?.cancel();
    _resultTransitionTimer = null;
    _matchController.restart();
    setState(() {
      _isTransitioningToResult = false;
      _winningLineController.reset();
      _fallingDiscController.reset();
      _fallingDisc = null;
      _previewColumn = FourInARowGame.cols ~/ 2;
    });
  }

  void _exitGame() {
    Navigator.of(context).pop();
  }

  void _navigateToResultScreen() {
    final game = _matchController.game;
    final isBlueWinner = game.winner == FourInARowPlayer.player1;
    final isRedWinner = game.winner == FourInARowPlayer.player2;

    GameResultData resultData;
    if (isBlueWinner) {
      resultData = GameResultData.blueWin(label: 'BLUE PLAYER\nWINS!');
    } else if (isRedWinner) {
      resultData = GameResultData.redWin(
        label: _matchController.redWinnerLabel,
      );
    } else {
      resultData = GameResultData.draw(label: 'DRAW');
    }

    GameResultScreen.show(
      context,
      resultData: resultData,
      onPlayAgain: () {
        _restartGame();
      },
      onExit: () {
        _exitGame();
      },
    );
  }

  void _onMatchStateChanged() {
    if (!mounted) return;

    final activeMove = _matchController.activeMove;
    if (activeMove != null && activeMove != _fallingDisc) {
      setState(() {
        _previewColumn = activeMove.column;
        _fallingDisc = activeMove;
      });
      _fallingDiscController.forward(from: 0.0);
      return;
    }

    setState(() {});
  }

  void _scheduleResultTransition() {
    if (_isTransitioningToResult) return;

    setState(() {
      _isTransitioningToResult = true;
    });
    final delay = _matchController.game.status == FourInARowGameStatus.won
        ? const Duration(milliseconds: 800)
        : Duration.zero;
    _resultTransitionTimer = Timer(delay, () {
      if (mounted && _isTransitioningToResult) {
        _navigateToResultScreen();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // The declared orientation behavior is the enforced contract for this
    // screen's composition, not a decorative label: this screen only knows
    // how to compose itself as fixedLandscape, and says so explicitly rather
    // than silently rendering something else if that ever stops being true
    // (e.g. a future edit to the registry, or this screen being reused for a
    // game with different rules). See AGENTS.md §8.
    final gameBody = switch (_definition.orientationBehavior) {
      GameOrientationBehavior.fixedLandscape => _PortraitRotationHint(
          child: _buildFixedLandscapeComposition(),
        ),
      GameOrientationBehavior.fixedPortrait ||
      GameOrientationBehavior.adaptive =>
        throw UnsupportedError(
          'FourInARowScreen only implements '
          'GameOrientationBehavior.fixedLandscape, but four_in_a_row is '
          'declared as ${_definition.orientationBehavior}.',
        ),
    };

    return PopScope(
      canPop: true,
      child: Scaffold(body: gameBody),
    );
  }

  /// The screen's one and only supported composition: a landscape-shaped
  /// (7:6) board, fit to whichever of the available width/height is more
  /// constraining so it is never inverted into a portrait-shaped layout —
  /// on a portrait phone it simply scales down, it never rotates the device
  /// or the rendered pixels (AGENTS.md §8.1–§8.4). This is the literal
  /// meaning of [GameOrientationBehavior.fixedLandscape] for this game, and
  /// its algorithm is unchanged from before this behavior was enforced.
  Widget _buildFixedLandscapeComposition() {
    final game = _matchController.game;
    final isBlueTurn = game.currentPlayer == FourInARowPlayer.player1;
    final currentBgColor = isBlueTurn ? _blueBgColor : _redBgColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      color: currentBgColor,
      child: SafeArea(
        child: Stack(
          children: [
            // ── Centered Navy Board with Surrounding Background ──────────
            //
            // The board keeps its landscape-*style* aspect ratio (7:6)
            // regardless of the device's actual orientation (AGENTS.md
            // §8): it is fit to whichever of the available width/height
            // is more constraining, so it never overflows the canvas it is
            // given.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const aspectRatio =
                        FourInARowGame.cols / FourInARowGame.rows;

                    // Both the preview disc and a freshly-dropped disc start
                    // above the board's own top edge (see
                    // _buildPreviewDiscOverlay and _buildFallingDiscOverlay:
                    // `top: -geometry.cellHeight * 1.15` is the larger of the
                    // two overflow amounts, so it's the one that must fit).
                    // When height is the binding constraint (wide
                    // screens/landscape), reserve exactly that much headroom
                    // before fitting the board, so neither disc is ever
                    // clipped by the top of the available area — a real,
                    // pre-existing overflow bug (AGENTS.md §8.4) that the
                    // previous flat percentage safety margin didn't actually
                    // account for.
                    //
                    // Solving `height = availableHeight - headroom` where
                    // `headroom = cellHeight * 1.15` and
                    // `cellHeight = (height - framePadding -
                    //     frameBottomPadding) / rows`
                    // for `height` gives this closed form (a small constant
                    // buffer is subtracted from the available height first).
                    const rows = FourInARowGame.rows;
                    const frameInset = _BoardGeometry.framePadding +
                        _BoardGeometry.frameBottomPadding;
                    const startOffsetFactor = 1.15;
                    final availableHeight = constraints.maxHeight - 4;
                    final heightConstrainedHeight = (rows * availableHeight +
                            startOffsetFactor * frameInset) /
                        (rows + startOffsetFactor);
                    final widthAtHeightConstrained =
                        heightConstrainedHeight * aspectRatio;

                    double boardWidth;
                    double boardHeight;
                    if (widthAtHeightConstrained <= constraints.maxWidth) {
                      boardWidth = widthAtHeightConstrained;
                      boardHeight = heightConstrainedHeight;
                    } else {
                      boardWidth = constraints.maxWidth;
                      boardHeight = boardWidth / aspectRatio;
                    }

                    return SizedBox(
                      height: boardHeight,
                      width: boardWidth,
                      child: _buildBoard(),
                    );
                  },
                ),
              ),
            ),

            // ── Reusable Turn Indicator (layout from game metadata) ─────
            Positioned.fill(
              child: TurnIndicatorOverlay(
                layout: _definition.turnIndicatorLayout,
                first: TurnIndicatorSpec(
                  color: _bluePlayerColor,
                  label: 'BLUE TURN',
                  isActive: isBlueTurn,
                ),
                second: TurnIndicatorSpec(
                  color: _redPlayerColor,
                  label: 'RED TURN',
                  isActive: !isBlueTurn,
                ),
                isGameOver: game.isGameOver,
              ),
            ),

            // ── Options Menu Scrim + Panel (only while open) ────────────
            //
            // Deliberately not a PopupMenuButton: that widget shows its
            // panel through the app's root Navigator/Overlay, which sits
            // outside this screen's own widget subtree and therefore
            // ignores the portrait "please rotate" composition's Transform
            // (see _PortraitRotationHint) — it would pop up unrotated while
            // everything else on screen is rotated. This panel is a normal
            // Stack child instead, so it is always subject to the exact
            // same rotation as the board and stays visually consistent.
            if (_isOptionsMenuOpen) ...[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _isOptionsMenuOpen = false),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                top: 54,
                right: 14,
                child: _buildOptionsMenuPanel(),
              ),
            ],

            // ── Top-Right 3-Dot Options Button ─────────────────────────
            Positioned(
              top: 10,
              right: 14,
              child: _buildOptionsButton(),
            ),
          ],
        ),
      ),
    );
  }

  /// The compact 3-dot button that opens/closes [_buildOptionsMenuPanel].
  Widget _buildOptionsButton() {
    return GestureDetector(
      onTap: () => setState(() => _isOptionsMenuOpen = !_isOptionsMenuOpen),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _boardColor.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.more_vert_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  /// The options dropdown panel (Revert, Restart, Exit Game), in that order.
  Widget _buildOptionsMenuPanel() {
    void select(VoidCallback action) {
      setState(() => _isOptionsMenuOpen = false);
      action();
    }

    return Material(
      color: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_matchController.supportsRevert)
              _buildOptionsMenuItem(
                icon: Icons.undo_rounded,
                label: 'Revert',
                enabled: _matchController.canRevert,
                onTap: () => select(_revertMove),
              ),
            _buildOptionsMenuItem(
              icon: Icons.refresh_rounded,
              label: 'Restart',
              enabled: true,
              onTap: () => select(_restartGame),
            ),
            _buildOptionsMenuItem(
              icon: Icons.logout_rounded,
              label: 'Exit Game',
              enabled: true,
              onTap: () => select(_exitGame),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsMenuItem({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final color = enabled ? Colors.black87 : Colors.grey.shade400;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  /// Charcoal 7x6 board built as physical layers: sockets sit behind the board
  /// surface, discs travel between them, and the punched surface is painted on
  /// top so a disc is only ever visible through a hole.
  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = _BoardGeometry.fromSize(constraints.biggest);
        final game = _matchController.game;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Board body. Only the fill and the drop shadow live here; the
            //    frame border belongs to the surface layer above the discs.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _boardColor,
                  borderRadius:
                      BorderRadius.circular(_BoardGeometry.frameRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Socket layer: empty sockets and settled discs, behind the
            //    board surface. Also owns the per-column tap targets.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _BoardGeometry.framePadding,
                  _BoardGeometry.framePadding,
                  _BoardGeometry.framePadding,
                  _BoardGeometry.frameBottomPadding,
                ),
                child: Row(
                  children: List.generate(
                    FourInARowGame.cols,
                    (colIndex) => Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _onColumnTap(colIndex),
                        child: Column(
                          children: List.generate(
                            FourInARowGame.rows,
                            (rowIndex) => Expanded(
                              child: _buildCell(rowIndex, colIndex),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 3. Disc layer: the disc waiting above the board and the disc that
            //    is currently travelling inside it. Still behind the surface.
            if (_fallingDisc == null && !game.isGameOver)
              _buildPreviewDiscOverlay(geometry),

            if (_fallingDisc != null) _buildFallingDiscOverlay(geometry),

            // 4. Board surface: charcoal panel with the holes punched out. It
            //    occludes the disc layer everywhere except inside a hole.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BoardSurfacePainter(
                    geometry: geometry,
                    surfaceColor: _boardColor,
                  ),
                ),
              ),
            ),

            // 5. Animated Glowing White Winning Line Overlay with Nodes. Shown
            //    only once the winning disc has actually landed.
            if (game.status == FourInARowGameStatus.won &&
                _fallingDisc == null &&
                game.winningPositions.length >= FourInARowGame.connectCount)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _winningLineAnimation,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _GlowingWinningLinePainter(
                        winningPositions: game.winningPositions,
                        geometry: geometry,
                        progress: _winningLineAnimation.value,
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  /// The next disc, resting just above the board opening.
  Widget _buildPreviewDiscOverlay(_BoardGeometry geometry) {
    final discColor =
        _matchController.game.currentPlayer == FourInARowPlayer.player1
        ? _bluePlayerColor
        : _redPlayerColor;

    return Positioned(
      left: geometry.discOriginOf(0, _previewColumn).dx,
      top: -geometry.discSize - 8,
      width: geometry.discSize,
      height: geometry.discSize,
      child: _buildDisc(discColor),
    );
  }

  /// The single disc that is currently falling towards its destination hole.
  Widget _buildFallingDiscOverlay(_BoardGeometry geometry) {
    final move = _fallingDisc!;
    final target = geometry.discOriginOf(move.row, move.column);
    final startTop = -geometry.cellHeight * 1.15;
    final discColor = move.player == FourInARowPlayer.player1
        ? _bluePlayerColor
        : _redPlayerColor;

    return AnimatedBuilder(
      animation: _fallingDiscController,
      builder: (context, child) {
        final progress = TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: Curves.easeIn)),
            weight: 34,
          ),
          TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 0.90)
                .chain(CurveTween(curve: Curves.easeOutCubic)),
            weight: 33,
          ),
          TweenSequenceItem(
            tween: Tween(begin: 0.90, end: 1.0)
                .chain(CurveTween(curve: Curves.easeInOut)),
            weight: 33,
          ),
        ]).evaluate(_fallingDiscController);
        final top = startTop + ((target.dy - startTop) * progress);

        return Positioned(
          left: target.dx,
          top: top,
          width: geometry.discSize,
          height: geometry.discSize,
          child: child!,
        );
      },
      child: _buildDisc(discColor),
    );
  }

  Widget _buildDisc(Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.black,
          width: _BoardGeometry.holeRimWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 2.5,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
    );
  }

  /// Builds a single socket. It paints only the fill that is seen through the
  /// hole; the rim and the surrounding board come from [_BoardSurfacePainter].
  Widget _buildCell(int row, int col) {
    // The engine applies a move as soon as it is made, but the destination must
    // stay visually empty until the falling disc has actually landed in it.
    final isFallingTarget =
        _fallingDisc?.row == row && _fallingDisc?.column == col;
    final occupant =
        isFallingTarget ? null : _matchController.game.getCell(row, col);

    Color fillColor;
    if (occupant == FourInARowPlayer.player1) {
      fillColor = _bluePlayerColor;
    } else if (occupant == FourInARowPlayer.player2) {
      fillColor = _redPlayerColor;
    } else {
      fillColor = _holeColor;
    }

    return Padding(
      padding: const EdgeInsets.all(_BoardGeometry.cellInset),
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fillColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Custom painter that draws an animated glowing white winning line with node dots at each cell center.
class _GlowingWinningLinePainter extends CustomPainter {
  final List<BoardPosition> winningPositions;
  final _BoardGeometry geometry;
  final double progress;

  _GlowingWinningLinePainter({
    required this.winningPositions,
    required this.geometry,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (winningPositions.length < 4 || progress <= 0.0) return;

    final first = winningPositions.first;
    final last = winningPositions.last;

    final startOffset = geometry.centerOf(first.row, first.col);
    final fullEndOffset = geometry.centerOf(last.row, last.col);

    final currentEndOffset = Offset.lerp(startOffset, fullEndOffset, progress)!;

    // 1. Soft glowing aura around the line
    final glowPaint = Paint()
      ..color = const Color(0xFF00ACF8).withValues(alpha: 0.45)
      ..strokeWidth = 16.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(startOffset, currentEndOffset, glowPaint);

    // 2. Crisp main white line
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(startOffset, currentEndOffset, linePaint);

    // 3. Node circles at each connected winning disc center
    final nodeRadius = 8.0 * progress;
    final nodeFillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final nodeBorderPaint = Paint()
      ..color = const Color(0xFF00ACF8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (final pos in winningPositions) {
      final center = geometry.centerOf(pos.row, pos.col);

      // Only draw node if the animated line has reached or passed this point
      final totalDist = (fullEndOffset - startOffset).distance;
      final pointDist = (center - startOffset).distance;
      if (totalDist > 0 && (pointDist / totalDist) <= progress + 0.1) {
        canvas.drawCircle(center, nodeRadius, nodeFillPaint);
        canvas.drawCircle(center, nodeRadius, nodeBorderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GlowingWinningLinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.winningPositions != winningPositions ||
        oldDelegate.geometry != geometry;
  }
}
