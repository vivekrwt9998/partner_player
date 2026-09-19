import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../data/games_registry.dart';
import '../../../models/game_definition.dart';
import '../../../games/tic_tac_toe/logic/tic_tac_toe_game.dart';
import '../../../games/tic_tac_toe/models/tic_tac_toe_models.dart';
import '../../../games/tic_tac_toe/presentation/tic_tac_toe_match_controller.dart';
import '../../../widgets/turn_indicator.dart';
import '../../game_result_screen.dart';

/// Shared board metrics used by every board layer.
///
/// The board is always a square grid, so a single [cellSize] (derived from
/// whichever side the board is given) positions every cell and mark.
class _BoardGeometry {
  /// Inset from the board's own bounding box to where the grid lines start;
  /// also leaves room for their rounded-cap overshoot past the grid edges.
  static const double framePadding = 14.0;

  final Size size;
  final double cellSize;

  const _BoardGeometry._({required this.size, required this.cellSize});

  factory _BoardGeometry.fromSize(Size size) {
    final cellSize = (size.width - (framePadding * 2)) / TicTacToeGame.cols;
    return _BoardGeometry._(size: size, cellSize: cellSize > 0 ? cellSize : 0);
  }

  /// Center of the cell at [row]/[col], in board-local coordinates.
  Offset centerOf(int row, int col) {
    return Offset(
      framePadding + (col * cellSize) + (cellSize / 2),
      framePadding + (row * cellSize) + (cellSize / 2),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BoardGeometry && size == other.size && cellSize == other.cellSize;

  @override
  int get hashCode => Object.hash(size, cellSize);
}

/// Visual Specifications:
/// - Dynamic background: soft blue on Blue turn, soft coral on Red turn
/// - Classic hash-style grid: thick, rounded-cap black lines directly on the
///   background (no board panel), matching a hand-drawn tic-tac-toe board
/// - Face-to-face turn indicators: near/Blue player at the bottom, far/Red
///   player at the top (AGENTS.md §10.1.2 portrait fixed-side positioning)
/// - 3-dot options menu in top right (Revert, Restart, Exit Game)
/// - Marks pop in with a light scale animation; winning line glows in white
/// - Seamless transition to full-screen celebratory GameResultScreen
class TicTacToeScreen extends StatefulWidget {
  final GameMode mode;

  const TicTacToeScreen({
    super.key,
    this.mode = GameMode.local,
  });

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen>
    with TickerProviderStateMixin {
  late final TicTacToeMatchController _matchController;

  /// This game's metadata, looked up once so the turn indicator layout and
  /// orientation contract are driven by configuration rather than hardcoded
  /// in this screen (AGENTS.md §10.1.6).
  static final GameDefinition _definition =
      kGames.firstWhere((g) => g.id == 'tic_tac_toe');

  // Color Palette matching Four in a Row's design specification.
  static const Color _bluePlayerColor = Color(0xFF00ACF8); // Blue Player (O)
  static const Color _redPlayerColor = Color(0xFFFF5E57); // Red Player (X)
  static const Color _blueBgColor = Color(0xFF63C5F0); // Blue Turn Background
  static const Color _redBgColor = Color(0xFFF28D88); // Red Turn Background
  static const Color _boardColor = Color(0xFF303943); // Options Button Fill

  late final AnimationController _winningLineController;
  late final Animation<double> _winningLineAnimation;
  bool _isTransitioningToResult = false;
  bool _isOptionsMenuOpen = false;
  Timer? _resultTransitionTimer;

  @override
  void initState() {
    super.initState();
    _matchController = TicTacToeMatchController(mode: widget.mode)
      ..addListener(_onMatchStateChanged);

    _winningLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _winningLineAnimation = CurvedAnimation(
      parent: _winningLineController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _resultTransitionTimer?.cancel();
    _matchController
      ..removeListener(_onMatchStateChanged)
      ..dispose();
    _winningLineController.dispose();
    super.dispose();
  }

  void _onMatchStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onCellTap(int row, int col) {
    if (_isTransitioningToResult) return;

    final game = _matchController.game;
    final applied = _matchController.submitLocalCell(row, col);
    if (!applied) return;

    if (game.status == TicTacToeGameStatus.won) {
      _winningLineController.forward(from: 0.0);
    }
    if (game.isGameOver) {
      _scheduleResultTransition();
    }
  }

  void _revertMove() {
    if (!_matchController.canRevert || _isTransitioningToResult) return;
    _matchController.revert();
    setState(() {
      _winningLineController.reset();
    });
  }

  void _restartGame() {
    _resultTransitionTimer?.cancel();
    _resultTransitionTimer = null;
    _matchController.restart();
    setState(() {
      _isTransitioningToResult = false;
      _winningLineController.reset();
    });
  }

  void _exitGame() {
    Navigator.of(context).pop();
  }

  void _navigateToResultScreen() {
    final game = _matchController.game;
    final isBlueWinner = game.winner == TicTacToePlayer.player1;
    final isRedWinner = game.winner == TicTacToePlayer.player2;

    GameResultData resultData;
    if (isBlueWinner) {
      resultData = GameResultData.blueWin(label: 'BLUE PLAYER\nWINS!');
    } else if (isRedWinner) {
      resultData = GameResultData.redWin(label: 'RED PLAYER\nWINS!');
    } else {
      resultData = GameResultData.draw(label: 'DRAW');
    }

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
    final delay = _matchController.game.status == TicTacToeGameStatus.won
        ? const Duration(milliseconds: 700)
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
    // how to compose itself as fixedPortrait, and says so explicitly rather
    // than silently rendering something else if that ever stops being true
    // (AGENTS.md §8).
    final gameBody = switch (_definition.orientationBehavior) {
      GameOrientationBehavior.fixedPortrait => _buildFixedPortraitComposition(),
      GameOrientationBehavior.fixedLandscape ||
      GameOrientationBehavior.adaptive =>
        throw UnsupportedError(
          'TicTacToeScreen only implements '
          'GameOrientationBehavior.fixedPortrait, but tic_tac_toe is '
          'declared as ${_definition.orientationBehavior}.',
        ),
    };

    return PopScope(
      canPop: true,
      child: Scaffold(body: gameBody),
    );
  }

  /// The screen's one and only supported composition: a square board stacked
  /// vertically between the two face-to-face turn indicators. Unlike Four in
  /// a Row's landscape-shaped board, a square board reads the same whether
  /// the device is held portrait or landscape, so this composition simply
  /// fits itself to whichever of the available width/height is more
  /// constraining — it never needs to rotate its pixels (AGENTS.md §8.1-8.4).
  Widget _buildFixedPortraitComposition() {
    final game = _matchController.game;
    final isBlueTurn = game.currentPlayer == TicTacToePlayer.player1;
    final currentBgColor = isBlueTurn ? _blueBgColor : _redBgColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      color: currentBgColor,
      child: SafeArea(
        child: Stack(
          children: [
            // ── Centered Square Board with Surrounding Background ───────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 110, 28, 110),
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side =
                        math.min(constraints.maxWidth, constraints.maxHeight);
                    return SizedBox(
                      key: const ValueKey('ttt_board'),
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

  /// Classic hash-grid 3x3 board: thick rounded black lines drawn directly
  /// on the turn background (no board panel), each cell showing an empty
  /// tap target or the occupying player's mark, with the winning line
  /// glowing on top once the game has been won.
  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = _BoardGeometry.fromSize(constraints.biggest);
        final game = _matchController.game;

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _GridPainter(geometry: geometry)),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(_BoardGeometry.framePadding),
                child: Column(
                  children: List.generate(
                    TicTacToeGame.rows,
                    (rowIndex) => Expanded(
                      child: Row(
                        children: List.generate(
                          TicTacToeGame.cols,
                          (colIndex) => Expanded(
                            child: GestureDetector(
                              key: ValueKey('ttt_cell_${rowIndex}_$colIndex'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _onCellTap(rowIndex, colIndex),
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
            if (game.status == TicTacToeGameStatus.won &&
                game.winningPositions.length >= TicTacToeGame.connectCount)
              Positioned.fill(
                child: IgnorePointer(
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
              ),
          ],
        );
      },
    );
  }

  /// Builds a single cell's tap target: empty, or the occupying player's
  /// mark popping in with a light scale animation.
  Widget _buildCell(int row, int col) {
    final occupant = _matchController.game.getCell(row, col);

    return Center(
      child: AnimatedScale(
        scale: occupant == null ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: FractionallySizedBox(
          widthFactor: 0.55,
          heightFactor: 0.55,
          child: _buildMark(occupant),
        ),
      ),
    );
  }

  Widget _buildMark(TicTacToePlayer? occupant) {
    if (occupant == null) return const SizedBox.shrink();

    return CustomPaint(
      painter: occupant == TicTacToePlayer.player1
          ? const _OMarkPainter(color: _bluePlayerColor)
          : const _XMarkPainter(color: _redPlayerColor),
      child: const SizedBox.expand(),
    );
  }
}

/// Draws the classic tic-tac-toe "hash" grid: two vertical and two
/// horizontal thick black lines with rounded caps, each overshooting
/// slightly past the grid's own edges — matching a hand-drawn board.
class _GridPainter extends CustomPainter {
  final _BoardGeometry geometry;

  const _GridPainter({required this.geometry});

  @override
  void paint(Canvas canvas, Size size) {
    final cell = geometry.cellSize;
    if (cell <= 0) return;

    const inset = _BoardGeometry.framePadding;
    final overshoot = cell * 0.14;
    final gridStart = inset - overshoot;
    final gridEnd = inset + (cell * TicTacToeGame.cols) + overshoot;

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = cell * 0.14
      ..strokeCap = StrokeCap.round;

    for (var i = 1; i < TicTacToeGame.cols; i++) {
      final x = inset + (cell * i);
      canvas.drawLine(Offset(x, gridStart), Offset(x, gridEnd), paint);
    }
    for (var i = 1; i < TicTacToeGame.rows; i++) {
      final y = inset + (cell * i);
      canvas.drawLine(Offset(gridStart, y), Offset(gridEnd, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.geometry != geometry;
}

/// Draws a thick, rounded-cap "X" mark filling its bounds (Red player), with
/// a black outline so it reads clearly against any background color.
class _XMarkPainter extends CustomPainter {
  final Color color;

  const _XMarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.shortestSide * 0.18;
    final diagonalA = (Offset.zero, Offset(size.width, size.height));
    final diagonalB = (Offset(size.width, 0), Offset(0, size.height));

    // Both black outlines first, then both colored fills on top, so the
    // crossing point stays a clean color instead of a black patch.
    final borderPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = strokeWidth * 1.9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(diagonalA.$1, diagonalA.$2, borderPaint);
    canvas.drawLine(diagonalB.$1, diagonalB.$2, borderPaint);

    final fillPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(diagonalA.$1, diagonalA.$2, fillPaint);
    canvas.drawLine(diagonalB.$1, diagonalB.$2, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _XMarkPainter oldDelegate) => oldDelegate.color != color;
}

/// Draws a thick, hollow "O" mark filling its bounds (Blue player), with a
/// black outline on both edges of the ring so it reads clearly against any
/// background color.
class _OMarkPainter extends CustomPainter {
  final Color color;

  const _OMarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.shortestSide * 0.18;
    final radius = (size.shortestSide / 2) - (strokeWidth / 2);
    final center = size.center(Offset.zero);

    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 1.9;
    canvas.drawCircle(center, radius, borderPaint);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _OMarkPainter oldDelegate) => oldDelegate.color != color;
}

/// Custom painter that draws an animated glowing white winning line with
/// node dots at each connected cell center.
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
    if (winningPositions.length < TicTacToeGame.connectCount || progress <= 0.0) {
      return;
    }

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

    // 3. Node circles at each connected winning mark's center
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

      final totalDist = (fullEndOffset - startOffset).distance;
      final pointDist = (center - startOffset).distance;
      if (totalDist == 0 || (pointDist / totalDist) <= progress + 0.1) {
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
