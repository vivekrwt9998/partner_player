import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../games/four_in_a_row/logic/four_in_a_row_game.dart';
import '../../../games/four_in_a_row/models/four_in_a_row_models.dart';
import '../../game_result_screen.dart';

/// Finalized Four in a Row landscape gameplay screen.
///
/// Features:
/// - Landscape layout with intentional surrounding background spacing (not full-screen)
/// - Dynamic player-family background reaction
/// - Semicircle/curved turn indicators anchored to bottom screen edges (only active visible)
/// - 3-dot options menu (Exit Game, Restart, Revert)
/// - Normal discs with animated floating white winning line overlay
/// - Full-screen celebratory GameResultScreen with 3s auto-exit countdown
class FourInARowScreen extends StatefulWidget {
  const FourInARowScreen({super.key});

  @override
  State<FourInARowScreen> createState() => _FourInARowScreenState();
}

class _FourInARowScreenState extends State<FourInARowScreen>
    with SingleTickerProviderStateMixin {
  final FourInARowGame _game = FourInARowGame();

  // Permanent Player Colors
  static const Color _bluePlayerColor = Color(0xFF00ACF8); // Player 1 / Left
  static const Color _redPlayerColor = Color(0xFFFF5E57); // Player 2 / Right

  // Board Styling
  static const Color _boardColor = Color(0xFF1565C0); // Classic Vivid Blue
  static const Color _holeColor = Color(0xFF0D47A1); // Deep Slot Color

  late final AnimationController _winningLineController;
  late final Animation<double> _winningLineAnimation;
  bool _isTransitioningToResult = false;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _winningLineController.dispose();
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
    if (_game.isGameOver || _isTransitioningToResult) return;
    if (_game.isColumnFull(col)) return;

    setState(() {
      _game.dropDisc(col);
    });

    if (_game.status == FourInARowGameStatus.won) {
      _isTransitioningToResult = true;
      // Start drawing the white line with animation
      _winningLineController.forward(from: 0.0);

      // Transition to full-screen result page after line draws and stays visible briefly
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        _navigateToResultScreen();
      });
    } else if (_game.status == FourInARowGameStatus.draw) {
      _isTransitioningToResult = true;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        _navigateToResultScreen();
      });
    }
  }

  void _revertMove() {
    if (!_game.canRevert || _isTransitioningToResult) return;
    setState(() {
      _winningLineController.reset();
      _game.revert();
    });
  }

  void _restartGame() {
    setState(() {
      _isTransitioningToResult = false;
      _winningLineController.reset();
      _game.reset();
    });
  }

  void _exitGame() {
    Navigator.of(context).pop();
  }

  void _navigateToResultScreen() {
    final isBlueWinner = _game.winner == FourInARowPlayer.player1;
    final isRedWinner = _game.winner == FourInARowPlayer.player2;

    GameResultData resultData;
    if (isBlueWinner) {
      resultData = GameResultData.blueWin(label: 'BLUE PLAYER WINS');
    } else if (isRedWinner) {
      resultData = GameResultData.redWin(label: 'RED PLAYER WINS');
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

  @override
  Widget build(BuildContext context) {
    final isBlueTurn = _game.currentPlayer == FourInARowPlayer.player1;
    final activeColor = isBlueTurn ? _bluePlayerColor : _redPlayerColor;

    // Dynamic background color tint based on active player's color family
    final backgroundColor = isBlueTurn
        ? const Color(0xFFE3F2FD) // Soft Blue Family Tint
        : const Color(0xFFFFEBEE); // Soft Red Family Tint

    return PopScope(
      canPop: true,
      child: Scaffold(
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          color: backgroundColor,
          child: SafeArea(
            child: Stack(
              children: [
                // ── Centered Game Board with Intentional Surrounding Background ──
                Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Constraint board height to ensure clear surrounding background space
                      final maxBoardHeight = constraints.maxHeight * 0.76;
                      final maxBoardWidth = maxBoardHeight * (FourInARowGame.cols / FourInARowGame.rows);

                      return SizedBox(
                        height: maxBoardHeight,
                        width: maxBoardWidth,
                        child: _buildBoard(),
                      );
                    },
                  ),
                ),

                // ── Left Semicircle Turn Indicator (Blue) ───────────────────
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: _buildSemicircleIndicator(
                    color: _bluePlayerColor,
                    label: 'BLUE TURN',
                    isVisible: !_game.isGameOver && isBlueTurn,
                    isLeft: true,
                  ),
                ),

                // ── Right Semicircle Turn Indicator (Red) ────────────────────
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _buildSemicircleIndicator(
                    color: _redPlayerColor,
                    label: 'RED TURN',
                    isVisible: !_game.isGameOver && !isBlueTurn,
                    isLeft: false,
                  ),
                ),

                // ── Top-Right Options 3-Dot Menu ───────────────────────────
                Positioned(
                  top: 8,
                  right: 12,
                  child: _buildOptionsMenu(activeColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the 3-dot options menu containing Exit Game, Restart, and Revert.
  Widget _buildOptionsMenu(Color activeColor) {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.more_vert_rounded,
          color: Colors.black87,
          size: 22,
        ),
      ),
      tooltip: 'Options',
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
          value: 'revert',
          enabled: _game.canRevert,
          child: Row(
            children: [
              Icon(
                Icons.undo_rounded,
                color: _game.canRevert ? Colors.black87 : Colors.grey.shade400,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Revert',
                style: TextStyle(
                  color: _game.canRevert ? Colors.black87 : Colors.grey.shade400,
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
              Text('Restart', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'exit',
          child: Row(
            children: [
              Icon(Icons.exit_to_app_rounded, color: Colors.redAccent, size: 20),
              SizedBox(width: 12),
              Text(
                'Exit Game',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Semicircle/curved turn indicator attached to the bottom screen edge.
  ///
  /// Only the active player's semicircle is visible on screen.
  Widget _buildSemicircleIndicator({
    required Color color,
    required String label,
    required bool isVisible,
    required bool isLeft,
  }) {
    // Semicircle curvature attached to edge and baseline
    final borderRadius = isLeft
        ? const BorderRadius.only(
            topRight: Radius.circular(60),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(60),
          );

    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutBack,
      offset: isVisible
          ? Offset.zero
          : (isLeft ? const Offset(-1.2, 0) : const Offset(1.2, 0)),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isVisible ? 1.0 : 0.0,
        child: Container(
          width: 155,
          height: 62,
          padding: EdgeInsets.only(
            left: isLeft ? 14 : 10,
            right: isLeft ? 10 : 14,
            top: 10,
            bottom: 6,
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLeft) ...[
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.6,
                  ),
                ),
                if (!isLeft) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Interactive 7x6 board with column tap gestures and animated floating white winning line.
  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / FourInARowGame.cols;
        final cellHeight = constraints.maxHeight / FourInARowGame.rows;

        return Stack(
          children: [
            // Blue Board Frame with Disc Slots
            Container(
              decoration: BoxDecoration(
                color: _boardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade900.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
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

            // Animated Floating White Winning Line Overlay
            if (_game.status == FourInARowGameStatus.won &&
                _game.winningPositions.length >= FourInARowGame.connectCount)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _winningLineAnimation,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _AnimatedWinningLinePainter(
                        winningPositions: _game.winningPositions,
                        cellWidth: cellWidth,
                        cellHeight: cellHeight,
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

  /// Builds a single cell disc with standard appearance (no star icons).
  Widget _buildCell(int row, int col) {
    final cell = _game.getCell(row, col);

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
          color: discColor,
          shape: BoxShape.circle,
          boxShadow: cell != null
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 2,
                    offset: const Offset(0, 1.5),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 1.5,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
      ),
    );
  }
}

/// Custom painter that draws a smoothly animated floating white line overlay over the winning 4 discs.
class _AnimatedWinningLinePainter extends CustomPainter {
  final List<BoardPosition> winningPositions;
  final double cellWidth;
  final double cellHeight;
  final double progress;

  _AnimatedWinningLinePainter({
    required this.winningPositions,
    required this.cellWidth,
    required this.cellHeight,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (winningPositions.length < 4 || progress <= 0.0) return;

    final first = winningPositions.first;
    final last = winningPositions.last;

    // Calculate center coordinates of start and end winning discs
    final startOffset = Offset(
      (first.col * cellWidth) + (cellWidth / 2),
      (first.row * cellHeight) + (cellHeight / 2),
    );

    final fullEndOffset = Offset(
      (last.col * cellWidth) + (cellWidth / 2),
      (last.row * cellHeight) + (cellHeight / 2),
    );

    // Interpolate end coordinate based on animation progress
    final currentEndOffset = Offset.lerp(startOffset, fullEndOffset, progress)!;

    // Subtle drop shadow under the line
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      startOffset.translate(0, 2),
      currentEndOffset.translate(0, 2),
      shadowPaint,
    );

    // Main crisp white overlay line
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(startOffset, currentEndOffset, linePaint);
  }

  @override
  bool shouldRepaint(covariant _AnimatedWinningLinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.winningPositions != winningPositions ||
        oldDelegate.cellWidth != cellWidth ||
        oldDelegate.cellHeight != cellHeight;
  }
}
