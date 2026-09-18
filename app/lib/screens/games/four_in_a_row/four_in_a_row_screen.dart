import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/game_definition.dart';
import '../../../games/four_in_a_row/logic/four_in_a_row_game.dart';
import '../../../games/four_in_a_row/models/four_in_a_row_models.dart';
import '../../../games/four_in_a_row/presentation/four_in_a_row_match_controller.dart';
import '../../game_result_screen.dart';

/// Four in a Row landscape gameplay screen matching the exact reference design.
///
class _BoardInnerClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(5, 5, size.width - 10, size.height - 10);
  }

  @override
  bool shouldReclip(covariant _BoardInnerClipper oldClipper) => false;
}

class _HoleRimPainter extends CustomPainter {
  final int row;
  final int col;
  final double horizontalPadding;
  final double verticalPadding;
  final double bottomPadding;

  const _HoleRimPainter({
    required this.row,
    required this.col,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.bottomPadding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const rows = FourInARowGame.rows;
    const cols = FourInARowGame.cols;
    final cellWidth = (size.width - horizontalPadding * 2) / cols;
    final cellHeight =
        (size.height - verticalPadding - bottomPadding) / rows;
    final radius = (cellWidth < cellHeight ? cellWidth : cellHeight) / 2 - 3.5;
    final rimPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(
      Offset(
        horizontalPadding + (col * cellWidth) + cellWidth / 2,
        verticalPadding + (row * cellHeight) + cellHeight / 2,
      ),
      radius,
      rimPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HoleRimPainter oldDelegate) {
    return oldDelegate.row != row ||
      oldDelegate.col != col ||
        oldDelegate.horizontalPadding != horizontalPadding ||
        oldDelegate.verticalPadding != verticalPadding ||
        oldDelegate.bottomPadding != bottomPadding;
  }
}

/// Custom painter that draws a quarter-circle corner arc with a smooth curved white border.
class _CornerArcPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final bool isLeft;

  _CornerArcPainter({
    required this.fillColor,
    required this.borderColor,
    required this.borderWidth,
    required this.isLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final borderPath = Path();

    if (isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.quadraticBezierTo(size.width * 0.75, 0, size.width, size.height);
      path.close();

      borderPath.moveTo(0, 0);
      borderPath.quadraticBezierTo(size.width * 0.75, 0, size.width, size.height);
    } else {
      path.moveTo(size.width, size.height);
      path.lineTo(size.width, 0);
      path.quadraticBezierTo(size.width * 0.25, 0, 0, size.height);
      path.close();

      borderPath.moveTo(size.width, 0);
      borderPath.quadraticBezierTo(size.width * 0.25, 0, 0, size.height);
    }

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(borderPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _CornerArcPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.isLeft != isLeft;
  }
}

/// Visual Specifications:
/// - Dynamic background: soft blue on Blue turn, soft coral on Red turn
/// - Centered Dark Navy Blue board (#0D2F62) with intentional surrounding background spacing
/// - Floating turn indicators near the bottom corners
/// - 3-dot options menu in top right (Exit Game, Restart, Revert)
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
  Timer? _resultTransitionTimer;

  @override
  void initState() {
    super.initState();
    _matchController = FourInARowMatchController(mode: widget.mode)
      ..addListener(_onMatchStateChanged);
    // Lock to landscape for Four in a Row
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

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
          setState(() {
            _fallingDisc = null;
          });
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
    // Restore all orientations when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
      if (activeMove.status == FourInARowGameStatus.won) {
        _winningLineController.forward(from: 0.0);
      }
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
    final game = _matchController.game;
    final isBlueTurn = game.currentPlayer == FourInARowPlayer.player1;
    final currentBgColor = isBlueTurn ? _blueBgColor : _redBgColor;

    return PopScope(
      canPop: true,
      child: Scaffold(
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          color: currentBgColor,
          child: SafeArea(
            child: Stack(
              children: [
                // ── Centered Navy Board with Surrounding Background ──────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxBoardHeight = constraints.maxHeight * 0.97;
                        final maxBoardWidth = maxBoardHeight *
                            (FourInARowGame.cols / FourInARowGame.rows);

                        return SizedBox(
                          height: maxBoardHeight,
                          width: maxBoardWidth,
                          child: _buildBoard(),
                        );
                      },
                    ),
                  ),
                ),

                // ── Bottom-Left Quarter-Circle Turn Indicator (Blue) ────────
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: _buildCornerTurnIndicator(
                    color: _bluePlayerColor,
                    label: 'BLUE TURN',
                    isVisible: !game.isGameOver && isBlueTurn,
                    isLeft: true,
                  ),
                ),

                // ── Bottom-Right Quarter-Circle Turn Indicator (Red) ─────────
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _buildCornerTurnIndicator(
                    color: _redPlayerColor,
                    label: 'RED TURN',
                    isVisible: !game.isGameOver && !isBlueTurn,
                    isLeft: false,
                  ),
                ),

                // ── Top-Right 3-Dot Options Button ─────────────────────────
                Positioned(
                  top: 10,
                  right: 14,
                  child: _buildOptionsMenu(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the 3-dot options menu (Exit Game, Restart, Revert).
  Widget _buildOptionsMenu() {
    return PopupMenuButton<String>(
      icon: Container(
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
      tooltip: 'Options',
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        switch (value) {
          case 'revert':
            _revertMove();
            break;
          case 'restart':
            _restartGame();
            break;
          case 'exit':
            _exitGame();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'exit',
          child: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Colors.black87, size: 20),
              SizedBox(width: 12),
              Text(
                'Exit Game',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'restart',
          child: Row(
            children: [
              Icon(Icons.refresh_rounded, color: Colors.black87, size: 20),
              SizedBox(width: 12),
              Text(
                'Restart',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (_matchController.supportsRevert)
          PopupMenuItem<String>(
            value: 'revert',
            enabled: _matchController.canRevert,
            child: Row(
              children: [
                Icon(
                  Icons.undo_rounded,
                  color: _matchController.canRevert
                      ? Colors.black87
                      : Colors.grey.shade400,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Revert',
                  style: TextStyle(
                    color: _matchController.canRevert
                        ? Colors.black87
                        : Colors.grey.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Builds the edge-attached quarter-circle turn indicator with curved white border.
  Widget _buildCornerTurnIndicator({
    required Color color,
    required String label,
    required bool isVisible,
    required bool isLeft,
  }) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutBack,
      offset: isVisible
          ? Offset.zero
          : (isLeft ? const Offset(-1.2, 0) : const Offset(1.2, 0)),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isVisible ? 1.0 : 0.0,
        child: CustomPaint(
          painter: _CornerArcPainter(
            fillColor: color,
            borderColor: Colors.white,
            borderWidth: 3.0,
            isLeft: isLeft,
          ),
          child: Container(
            width: 150,
            height: 78,
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Deep Navy 7x6 board with disc slots and animated glowing winning line overlay.
  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gridHorizontalPadding = 12.0;
        const gridTopPadding = 12.0;
        const gridBottomPadding = 8.0;
        final cellWidth = (constraints.maxWidth -
            (gridHorizontalPadding * 2)) /
          FourInARowGame.cols;
        final cellHeight = (constraints.maxHeight -
            gridTopPadding -
            gridBottomPadding) /
          FourInARowGame.rows;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Board frame. The grid is a separate layer so the falling disc can
            // sit behind the target slot's rim.
            Container(
              decoration: BoxDecoration(
                color: _boardColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.black, width: 5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),

            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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

            if (_fallingDisc == null && !_matchController.game.isGameOver)
              _buildPreviewDiscOverlay(constraints),

            // Animated Glowing White Winning Line Overlay with Nodes
            if (_matchController.game.status == FourInARowGameStatus.won &&
                _matchController.game.winningPositions.length >=
                    FourInARowGame.connectCount)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _winningLineAnimation,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _GlowingWinningLinePainter(
                        winningPositions: _matchController.game.winningPositions,
                        cellWidth: cellWidth,
                        cellHeight: cellHeight,
                        gridLeft: gridHorizontalPadding,
                        gridTop: gridTopPadding,
                        progress: _winningLineAnimation.value,
                      ),
                    );
                  },
                ),
              ),

            if (_fallingDisc != null)
              _buildFallingDiscOverlay(
                constraints,
              ),

            if (_fallingDisc != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: _HoleRimPainter(
                    row: _fallingDisc!.row,
                    col: _fallingDisc!.column,
                    horizontalPadding: 12,
                    verticalPadding: 12,
                    bottomPadding: 8,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewDiscOverlay(BoxConstraints constraints) {
    const frameHorizontalPadding = 17.0;
    final gridCellWidth =
        (constraints.maxWidth - frameHorizontalPadding * 2) /
            FourInARowGame.cols;
    final gridCellHeight =
        (constraints.maxHeight - 17 - 13) / FourInARowGame.rows;
    final discSize = (gridCellWidth < gridCellHeight
            ? gridCellWidth
            : gridCellHeight) -
        7;
    final discColor =
        _matchController.game.currentPlayer == FourInARowPlayer.player1
        ? _bluePlayerColor
        : _redPlayerColor;

    return Positioned(
      left: frameHorizontalPadding + (_previewColumn * gridCellWidth) +
          ((gridCellWidth - discSize) / 2),
      top: -discSize - 8,
      width: discSize,
      height: discSize,
      child: _buildDisc(discColor),
    );
  }

  Widget _buildFallingDiscOverlay(
    BoxConstraints constraints,
  ) {
    final move = _fallingDisc!;
    final frameHorizontalPadding = 17.0;
    final frameVerticalPadding = 17.0;
    final gridCellWidth =
        (constraints.maxWidth - frameHorizontalPadding * 2) /
            FourInARowGame.cols;
    final gridCellHeight =
      (constraints.maxHeight - frameVerticalPadding - 13) /
        FourInARowGame.rows;
    final discSize = (gridCellWidth < gridCellHeight
            ? gridCellWidth
            : gridCellHeight) -
        7;

    final discColor = move.player == FourInARowPlayer.player1
        ? _bluePlayerColor
        : _redPlayerColor;

    return Positioned.fill(
      child: ClipRect(
        clipper: _BoardInnerClipper(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
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
                final startTop = -gridCellHeight * 1.15;
                final targetTop =
                    frameVerticalPadding + (move.row * gridCellHeight) +
                        ((gridCellHeight - discSize) / 2);
                final top = startTop + ((targetTop - startTop) * progress);
                final left = frameHorizontalPadding +
                    (move.column * gridCellWidth) +
                    ((gridCellWidth - discSize) / 2);

                return Positioned(
                  left: left,
                  top: top,
                  width: discSize,
                  height: discSize,
                  child: child!,
                );
              },
              child: _buildDisc(discColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisc(Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 4),
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

  /// Builds a single cell disc with standard appearance (no star icons).
  Widget _buildCell(int row, int col) {
    final isFallingTarget =
        _fallingDisc?.row == row && _fallingDisc?.column == col;
    final cell =
        isFallingTarget ? null : _matchController.game.getCell(row, col);

    Color discColor;
    if (cell == FourInARowPlayer.player1) {
      discColor = _bluePlayerColor;
    } else if (cell == FourInARowPlayer.player2) {
      discColor = _redPlayerColor;
    } else {
      discColor = _holeColor;
    }

    return Padding(
      padding: const EdgeInsets.all(3.5),
      child: Container(
        decoration: BoxDecoration(
            color: isFallingTarget ? Colors.transparent : discColor,
          shape: BoxShape.circle,
            border: isFallingTarget
              ? null
              : Border.all(color: Colors.black, width: 4),
          boxShadow: cell != null
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 2.5,
                    offset: const Offset(0, 1.5),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 1.5,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
      ),
    );
  }
}

/// Custom painter that draws an animated glowing white winning line with node dots at each cell center.
class _GlowingWinningLinePainter extends CustomPainter {
  final List<BoardPosition> winningPositions;
  final double cellWidth;
  final double cellHeight;
  final double gridLeft;
  final double gridTop;
  final double progress;

  _GlowingWinningLinePainter({
    required this.winningPositions,
    required this.cellWidth,
    required this.cellHeight,
    required this.gridLeft,
    required this.gridTop,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (winningPositions.length < 4 || progress <= 0.0) return;

    final first = winningPositions.first;
    final last = winningPositions.last;

    final startOffset = Offset(
      gridLeft + (first.col * cellWidth) + (cellWidth / 2),
      gridTop + (first.row * cellHeight) + (cellHeight / 2),
    );

    final fullEndOffset = Offset(
      gridLeft + (last.col * cellWidth) + (cellWidth / 2),
      gridTop + (last.row * cellHeight) + (cellHeight / 2),
    );

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
      final center = Offset(
        gridLeft + (pos.col * cellWidth) + (cellWidth / 2),
        gridTop + (pos.row * cellHeight) + (cellHeight / 2),
      );

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
        oldDelegate.cellWidth != cellWidth ||
        oldDelegate.cellHeight != cellHeight ||
        oldDelegate.gridLeft != gridLeft ||
        oldDelegate.gridTop != gridTop;
  }
}
