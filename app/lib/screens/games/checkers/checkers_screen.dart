import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../data/games_registry.dart';
import '../../../models/game_definition.dart';
import '../../../games/checkers/logic/checkers_game.dart';
import '../../../games/checkers/models/checkers_models.dart';
import '../../../games/checkers/presentation/checkers_match_controller.dart';
import '../../../widgets/turn_indicator.dart';
import '../../game_result_screen.dart';

/// Visual Specifications (matching Four in a Row / Tic Tac Toe's design):
/// - Dynamic background: soft blue on Blue turn, soft coral on Red turn
/// - Classic 8x8 checkerboard (warm cream / charcoal squares) framed like
///   the other games' boards
/// - Face-to-face turn indicators: near/Blue player at the bottom, far/Red
///   player at the top (AGENTS.md §10.1.2 portrait fixed-side positioning)
/// - 3-dot options menu in top right (Revert, Restart, Exit Game)
/// - Tap a piece to see its legal moves highlighted; a highlighted capture
///   also rings the piece it would eat. A piece slides to its destination
///   when moved, and a captured piece shrinks and fades out.
/// - Seamless transition to full-screen celebratory GameResultScreen
class CheckersScreen extends StatefulWidget {
  final GameMode mode;

  const CheckersScreen({
    super.key,
    this.mode = GameMode.local,
  });

  @override
  State<CheckersScreen> createState() => _CheckersScreenState();
}

class _CheckersScreenState extends State<CheckersScreen>
    with TickerProviderStateMixin {
  late final CheckersMatchController _matchController;
  late final AnimationController _moveAnimController;

  /// Drives the slow rotation of the "you can move this" sparkle ring
  /// shown around every piece the current player is allowed to play right
  /// now, before they've picked one -- see [_shouldShowEligibilityGlow].
  late final AnimationController _glowController;

  /// This game's metadata, looked up once so the turn indicator layout and
  /// orientation contract are driven by configuration rather than hardcoded
  /// in this screen (AGENTS.md §10.1.6).
  static final GameDefinition _definition =
      kGames.firstWhere((g) => g.id == 'checkers');

  // Color Palette matching Four in a Row / Tic Tac Toe's design specification.
  static const Color _bluePlayerColor = Color(0xFF00ACF8); // Blue Player
  static const Color _redPlayerColor = Color(0xFFFF5E57); // Red Player
  static const Color _blueBgColor = Color(0xFF63C5F0); // Blue Turn Background
  static const Color _redBgColor = Color(0xFFF28D88); // Red Turn Background
  static const Color _boardColor = Color(0xFF303943); // Options Button Fill / Frame
  static const Color _darkSquareColor = Color(0xFF3B4759); // Charcoal-navy dark square
  static const Color _lightSquareColor = Color(0xFFF2E9DC); // Warm cream light square

  bool _isTransitioningToResult = false;
  bool _isOptionsMenuOpen = false;
  Timer? _resultTransitionTimer;
  int _lastHandledMoveCount = 0;

  BoardPosition? _selectedCell;
  List<BoardPosition> _legalDestinations = const [];

  /// The opponent piece(s) each highlighted capture destination would eat,
  /// so that square can be ringed as a warning before the player commits.
  List<BoardPosition> _captureTargets = const [];

  /// The most recently applied move, while its slide/fade animation is
  /// still playing. `null` once settled, or during a revert/restart snap.
  CheckersMove? _animatingMove;

  @override
  void initState() {
    super.initState();
    _matchController = CheckersMatchController(mode: widget.mode)
      ..addListener(_onMatchStateChanged);

    _moveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _animatingMove = null);
        }
      });

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _resultTransitionTimer?.cancel();
    _matchController
      ..removeListener(_onMatchStateChanged)
      ..dispose();
    _moveAnimController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  /// Reacts to every controller change (any applied move, revert, or
  /// restart) in one place, mirroring Tic Tac Toe's screen. Only a genuine
  /// new move (the count going *up*) triggers the slide/fade animation --
  /// a revert or restart snaps the board back instead.
  void _onMatchStateChanged() {
    if (!mounted) return;

    final game = _matchController.game;
    final isNewMove = game.moveCount > _lastHandledMoveCount;
    _lastHandledMoveCount = game.moveCount;

    if (isNewMove) {
      final move = _matchController.lastMove;
      if (move != null) {
        _animatingMove = move;
        _moveAnimController.forward(from: 0);
      }
      if (game.isGameOver) {
        _scheduleResultTransition();
      }
    }
    setState(() {});
  }

  void _onCellTap(int row, int col) {
    if (_isTransitioningToResult || _animatingMove != null) return;

    final game = _matchController.game;
    final tapped = BoardPosition(row, col);
    final selected = _selectedCell;

    if (selected != null && _legalDestinations.contains(tapped)) {
      final applied = _matchController.submitLocalMove(
        selected.row,
        selected.col,
        row,
        col,
      );
      if (applied) {
        final continueFrom = game.mustContinueFrom;
        setState(() {
          if (continueFrom != null) {
            final destinations = _matchController.game.legalMovesFrom(
              continueFrom.row,
              continueFrom.col,
            );
            _selectedCell = continueFrom;
            _legalDestinations = destinations;
            _captureTargets = _captureTargetsFor(continueFrom, destinations);
          } else {
            _clearSelection();
          }
        });
      }
      return;
    }

    final destinations = _matchController.game.legalMovesFrom(row, col);
    setState(() {
      if (destinations.isNotEmpty) {
        _selectedCell = tapped;
        _legalDestinations = destinations;
        _captureTargets = _captureTargetsFor(tapped, destinations);
      } else {
        _clearSelection();
      }
    });
  }

  /// The square of the opponent piece each capturing destination in
  /// [destinations] (a jump 2 rows away from [from]) would remove.
  List<BoardPosition> _captureTargetsFor(
    BoardPosition from,
    List<BoardPosition> destinations,
  ) {
    final targets = <BoardPosition>[];
    for (final destination in destinations) {
      if ((destination.row - from.row).abs() == 2) {
        targets.add(BoardPosition(
          (from.row + destination.row) ~/ 2,
          (from.col + destination.col) ~/ 2,
        ));
      }
    }
    return targets;
  }

  /// Whether the piece at [row]/[col] should show the rotating "you can
  /// eliminate something" blade ring: it belongs to whoever's turn it is,
  /// it has an actual capture available right now (not just any legal
  /// move -- a normal, non-capturing turn shows no ring at all), no piece
  /// is selected yet, and there's nothing else going on (mid-animation,
  /// Bot thinking, game ending) that would make it misleading.
  bool _shouldShowEligibilityGlow(int row, int col) {
    if (_selectedCell != null ||
        _animatingMove != null ||
        _isTransitioningToResult ||
        !_matchController.canAcceptLocalInput) {
      return false;
    }

    final game = _matchController.game;
    final piece = game.getCell(row, col);
    if (piece == null || piece.player != game.currentPlayer) return false;

    return game
        .legalMovesFrom(row, col)
        .any((destination) => (destination.row - row).abs() == 2);
  }

  void _clearSelection() {
    _selectedCell = null;
    _legalDestinations = const [];
    _captureTargets = const [];
  }

  void _resetAnimation() {
    _animatingMove = null;
    _moveAnimController.stop();
    _moveAnimController.reset();
  }

  void _revertMove() {
    if (!_matchController.canRevert || _isTransitioningToResult) return;
    _matchController.revert();
    setState(() {
      _clearSelection();
      _resetAnimation();
    });
  }

  void _restartGame() {
    _resultTransitionTimer?.cancel();
    _resultTransitionTimer = null;
    _matchController.restart();
    setState(() {
      _isTransitioningToResult = false;
      _clearSelection();
      _resetAnimation();
    });
  }

  void _exitGame() {
    Navigator.of(context).pop();
  }

  void _navigateToResultScreen() {
    final game = _matchController.game;
    final isBlueWinner = game.winner == CheckersPlayer.player1;

    final resultData = isBlueWinner
        ? GameResultData.blueWin(label: 'BLUE PLAYER\nWINS!')
        : GameResultData.redWin(label: _matchController.redWinnerLabel);

    GameResultScreen.show(
      context,
      resultData: resultData,
      onPlayAgain: _restartGame,
      onExit: _exitGame,
    );
  }

  void _scheduleResultTransition() {
    if (_isTransitioningToResult) return;

    setState(() {
      _isTransitioningToResult = true;
    });
    _resultTransitionTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted && _isTransitioningToResult) {
        _navigateToResultScreen();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // The declared orientation behavior is the enforced contract for this
    // screen's composition, not a decorative label: this screen only knows
    // how to compose itself as fixedPortrait, and says so explicitly rather
    // than silently rendering something else if that ever stops being true
    // (AGENTS.md §8).
    final gameBody = switch (_definition.orientationBehavior) {
      GameOrientationBehavior.fixedPortrait => _buildFixedPortraitComposition(),
      GameOrientationBehavior.fixedLandscape ||
      GameOrientationBehavior.adaptive =>
        throw UnsupportedError(
          'CheckersScreen only implements '
          'GameOrientationBehavior.fixedPortrait, but checkers is '
          'declared as ${_definition.orientationBehavior}.',
        ),
    };

    return PopScope(
      canPop: true,
      child: Scaffold(body: gameBody),
    );
  }

  /// The screen's one and only supported composition: a square board
  /// stacked vertically between the two face-to-face turn indicators. Like
  /// Tic Tac Toe's board, an 8x8 checkerboard is square, so it reads the
  /// same whether the device is portrait or landscape -- this composition
  /// simply fits itself to whichever of the available width/height is more
  /// constraining, never needing to rotate its pixels (AGENTS.md §8.1-8.4).
  Widget _buildFixedPortraitComposition() {
    final game = _matchController.game;
    final isBlueTurn = game.currentPlayer == CheckersPlayer.player1;
    final currentBgColor = isBlueTurn ? _blueBgColor : _redBgColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      color: currentBgColor,
      child: SafeArea(
        child: Stack(
          children: [
            // ── Centered Square Board with Surrounding Background ───────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 110, 20, 110),
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side =
                        math.min(constraints.maxWidth, constraints.maxHeight);
                    return SizedBox(
                      key: const ValueKey('checkers_board'),
                      width: side,
                      height: side,
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

  /// The 8x8 checkerboard: a frame around a grid of alternating dark and
  /// light squares, each a tap target showing the piece (if any), legal-move
  /// highlight, and capture-warning ring. A moving piece is drawn as a
  /// separate overlay sliding between cells (the static grid hides that
  /// piece at both its start and end square while the overlay is playing),
  /// the same layering trick Four in a Row's falling disc uses.
  ///
  /// The squares themselves are painted as one gapless [CustomPaint] layer
  /// rather than 64 individually-colored widgets: laying out that many
  /// flex children can round each one to a slightly different pixel
  /// boundary, leaving hairline seams that show the screen's background
  /// color through them. The interactive grid on top is fully transparent,
  /// so it never has that problem to begin with.
  static const double _boardFrameWidth = 5;

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The frame border is inset from the outer edge (see the `Container`
        // below, which -- unlike a bare `DecoratedBox` -- automatically pads
        // its child by the border's own width so the checkerboard doesn't
        // get painted straight over top of it, hiding it). Cell geometry
        // has to be computed from what's actually left afterwards, or the
        // moving-piece overlay would drift from the real squares.
        final innerSide = constraints.biggest.shortestSide - (_boardFrameWidth * 2);
        final cellSize = innerSide / CheckersGame.size;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: _darkSquareColor, width: _boardFrameWidth),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: const _CheckerboardPainter(
                      darkColor: _darkSquareColor,
                      lightColor: _lightSquareColor,
                    ),
                  ),
                ),
                Column(
                  children: List.generate(
                    CheckersGame.size,
                    (row) => Expanded(
                      child: Row(
                        children: List.generate(
                          CheckersGame.size,
                          (col) => Expanded(child: _buildSquare(row, col)),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_animatingMove != null)
                  _buildMovingPieceOverlay(_animatingMove!, cellSize),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The piece belonging to [move], sliding from its origin to its
  /// destination as [_moveAnimController] runs.
  Widget _buildMovingPieceOverlay(CheckersMove move, double cellSize) {
    // The move has already been applied to the engine by the time this is
    // shown, so the (possibly newly-crowned) piece is already sitting at
    // its destination cell.
    final piece = _matchController.game.getCell(move.to.row, move.to.col)!;

    return AnimatedBuilder(
      animation: _moveAnimController,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_moveAnimController.value);
        final fromCenter = Offset(
          (move.from.col + 0.5) * cellSize,
          (move.from.row + 0.5) * cellSize,
        );
        final toCenter = Offset(
          (move.to.col + 0.5) * cellSize,
          (move.to.row + 0.5) * cellSize,
        );
        final center = Offset.lerp(fromCenter, toCenter, t)!;
        final pieceSize = cellSize * 0.78;

        return Positioned(
          left: center.dx - (pieceSize / 2),
          top: center.dy - (pieceSize / 2),
          width: pieceSize,
          height: pieceSize,
          child: IgnorePointer(child: _buildPiece(piece)),
        );
      },
    );
  }

  Widget _buildSquare(int row, int col) {
    final position = BoardPosition(row, col);
    final isLegalDestination = _legalDestinations.contains(position);
    final isCaptureTarget = _captureTargets.contains(position);
    final showEligibilityGlow = _shouldShowEligibilityGlow(row, col);

    final animatingMove = _animatingMove;
    // Hidden here because the sliding overlay is drawing this piece instead.
    final isAnimatingEndpoint = animatingMove != null &&
        (animatingMove.from == position || animatingMove.to == position);
    final piece = isAnimatingEndpoint ? null : _matchController.game.getCell(row, col);
    final isFadingCapture = animatingMove?.captured == position;

    return GestureDetector(
      key: ValueKey('checkers_cell_${row}_$col'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(row, col),
      child: ColoredBox(
        // Transparent: the checkerboard pattern itself is painted as one
        // gapless layer beneath this whole grid (see _buildBoard).
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (showEligibilityGlow)
              FractionallySizedBox(
                widthFactor: 1.08,
                heightFactor: 1.08,
                child: AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, _) => CustomPaint(
                    painter: _EligibleGlowPainter(
                      angle: _glowController.value * 2 * math.pi,
                    ),
                  ),
                ),
              ),
            if (isFadingCapture)
              AnimatedBuilder(
                animation: _moveAnimController,
                builder: (context, _) {
                  final remaining = (1 - _moveAnimController.value).clamp(0.0, 1.0);
                  return Opacity(
                    opacity: remaining,
                    child: FractionallySizedBox(
                      widthFactor: 0.5 + (0.28 * remaining),
                      heightFactor: 0.5 + (0.28 * remaining),
                      child: _buildPiece(
                        CheckersPiece(
                          player: animatingMove!.player.opponent,
                          isKing: false,
                        ),
                      ),
                    ),
                  );
                },
              ),
            if (piece != null)
              FractionallySizedBox(
                widthFactor: 0.78,
                heightFactor: 0.78,
                child: AnimatedScale(
                  scale: 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: _buildPiece(piece),
                ),
              ),
            // A capture destination also rings the opponent piece it would
            // eat, so the player sees exactly what's at stake before tapping.
            if (isCaptureTarget)
              FractionallySizedBox(
                widthFactor: 0.86,
                heightFactor: 0.86,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 3),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            if (isLegalDestination)
              FractionallySizedBox(
                widthFactor: 0.46,
                heightFactor: 0.46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.6),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPiece(CheckersPiece piece) {
    final color =
        piece.player == CheckersPlayer.player1 ? _bluePlayerColor : _redPlayerColor;

    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: piece.isKing
          ? Center(
              child: FractionallySizedBox(
                widthFactor: 0.6,
                heightFactor: 0.6,
                child: FittedBox(
                  child: Icon(
                    Icons.star_rounded,
                    color: Colors.amber.shade300,
                    shadows: const [
                      Shadow(color: Colors.black45, blurRadius: 2),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

/// Paints the 8x8 checkerboard pattern as a single gapless layer -- see the
/// doc comment on [_CheckersScreenState._buildBoard] for why this isn't 64
/// separately-colored square widgets.
class _CheckerboardPainter extends CustomPainter {
  final Color darkColor;
  final Color lightColor;

  const _CheckerboardPainter({required this.darkColor, required this.lightColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / CheckersGame.size;
    final darkPaint = Paint()
      ..color = darkColor
      ..isAntiAlias = false;
    final lightPaint = Paint()
      ..color = lightColor
      ..isAntiAlias = false;

    for (var row = 0; row < CheckersGame.size; row++) {
      for (var col = 0; col < CheckersGame.size; col++) {
        final rect = Rect.fromLTWH(col * cellSize, row * cellSize, cellSize, cellSize);
        canvas.drawRect(rect, (row + col).isOdd ? darkPaint : lightPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerboardPainter oldDelegate) =>
      oldDelegate.darkColor != darkColor || oldDelegate.lightColor != lightColor;
}

/// A dark, slowly-rotating ring of sharp blade-like points drawn around a
/// piece to say "you can eliminate something with this one right now" --
/// see [_CheckersScreenState._shouldShowEligibilityGlow]. Deliberately dark
/// and neutral (not either player's color) since it's a warning/action
/// marker, not a "belongs to a side" indicator.
class _EligibleGlowPainter extends CustomPainter {
  static const _pointCount = 12;
  static const _bladeColor = Color(0xFF1C1C1C);

  final double angle;

  const _EligibleGlowPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = size.shortestSide / 2;
    final innerRadius = outerRadius * 0.5;
    // Narrow, so each point reads as a sharp blade rather than a soft blob.
    const spread = math.pi / _pointCount * 0.22;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    final bladePaint = Paint()
      ..color = _bladeColor
      ..style = PaintingStyle.fill;

    for (var i = 0; i < _pointCount; i++) {
      final theta = angle + (i * 2 * math.pi / _pointCount);
      final tip = center + Offset(math.cos(theta), math.sin(theta)) * outerRadius;
      final baseA = center +
          Offset(math.cos(theta - spread), math.sin(theta - spread)) * innerRadius;
      final baseB = center +
          Offset(math.cos(theta + spread), math.sin(theta + spread)) * innerRadius;

      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(baseA.dx, baseA.dy)
        ..lineTo(baseB.dx, baseB.dy)
        ..close();
      canvas.drawPath(path, shadowPaint);
      canvas.drawPath(path, bladePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EligibleGlowPainter oldDelegate) =>
      oldDelegate.angle != angle;
}
