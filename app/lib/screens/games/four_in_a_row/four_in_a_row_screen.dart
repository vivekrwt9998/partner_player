import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../games/four_in_a_row/logic/four_in_a_row_game.dart';
import '../../../games/four_in_a_row/models/four_in_a_row_models.dart';
import '../../../widgets/game_result_dialog.dart';

/// Four in a Row landscape gameplay screen.
///
/// Implements permanent Blue/Red player identities, anchored semicircle turn
/// indicators, floating white winning line overlay, 3-dot options menu
/// (Exit, Restart, Revert), and integrated result flow.
class FourInARowScreen extends StatefulWidget {
  const FourInARowScreen({super.key});

  @override
  State<FourInARowScreen> createState() => _FourInARowScreenState();
}

class _FourInARowScreenState extends State<FourInARowScreen> {
  final FourInARowGame _game = FourInARowGame();

  // Permanent Player Colors
  static const Color _bluePlayerColor = Color(0xFF00ACF8); // Player 1 / Left
  static const Color _redPlayerColor = Color(0xFFFF5E57); // Player 2 / Right

  // Board Styling
  static const Color _boardColor = Color(0xFF1565C0); // Vivid Classic Blue
  static const Color _holeColor = Color(0xFF0D47A1); // Deep Slot Color

  bool _isResultDialogOpen = false;

  @override
  void initState() {
    super.initState();
    // Lock to landscape for Four in a Row
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
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
    if (_game.isGameOver) return;
    if (_game.isColumnFull(col)) return;

    setState(() {
      _game.dropDisc(col);
    });

    if (_game.status == FourInARowGameStatus.won) {
      // Allow winning line highlight to be seen briefly before presenting result dialog
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted || _isResultDialogOpen) return;
        _showResultDialog();
      });
    } else if (_game.status == FourInARowGameStatus.draw) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted || _isResultDialogOpen) return;
        _showResultDialog();
      });
    }
  }

  void _revertMove() {
    if (!_game.canRevert) return;
    setState(() {
      _game.revert();
    });
  }

  void _restartGame() {
    setState(() {
      _game.reset();
    });
  }

  void _exitGame() {
    Navigator.of(context).pop();
  }

  void _showResultDialog() {
    _isResultDialogOpen = true;

    final isBlueWinner = _game.winner == FourInARowPlayer.player1;
    final isRedWinner = _game.winner == FourInARowPlayer.player2;

    String title;
    Color themeColor;
    IconData icon;

    if (isBlueWinner) {
      title = 'BLUE PLAYER WIN';
      themeColor = _bluePlayerColor;
      icon = Icons.emoji_events_rounded;
    } else if (isRedWinner) {
      title = 'RED PLAYER WIN';
      themeColor = _redPlayerColor;
      icon = Icons.emoji_events_rounded;
    } else {
      title = 'DRAW';
      themeColor = const Color(0xFF546E7A);
      icon = Icons.handshake_rounded;
    }

    GameResultDialog.show(
      context,
      title: title,
      themeColor: themeColor,
      icon: icon,
      autoExitSeconds: 3,
      onPlayAgain: () {
        _isResultDialogOpen = false;
        _restartGame();
      },
      onExit: () {
        _isResultDialogOpen = false;
        _exitGame();
      },
    ).then((_) {
      _isResultDialogOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isBlueTurn = _game.currentPlayer == FourInARowPlayer.player1;
    final activeColor = isBlueTurn ? _bluePlayerColor : _redPlayerColor;

    return PopScope(
      canPop: true,
      child: Scaffold(
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: activeColor.withValues(alpha: 0.08),
          child: SafeArea(
            child: Stack(
              children: [
                // ── Main Landscape Gameplay Content ────────────────────────
                Row(
                  children: [
                    // Left: Blue Player 1 Turn Indicator
                    _buildPlayerSide(
                      player: FourInARowPlayer.player1,
                      label: 'BLUE',
                      color: _bluePlayerColor,
                      isActive: !_game.isGameOver && isBlueTurn,
                      isLeft: true,
                    ),

                    // Center: 7x6 Interactive Board
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: AspectRatio(
                            aspectRatio: FourInARowGame.cols / FourInARowGame.rows,
                            child: _buildBoard(),
                          ),
                        ),
                      ),
                    ),

                    // Right: Red Player 2 Turn Indicator
                    _buildPlayerSide(
                      player: FourInARowPlayer.player2,
                      label: 'RED',
                      color: _redPlayerColor,
                      isActive: !_game.isGameOver && !isBlueTurn,
                      isLeft: false,
                    ),
                  ],
                ),

                // ── Top-Right Options 3-Dot Menu ───────────────────────────
                Positioned(
                  top: 4,
                  right: 4,
                  child: _buildOptionsMenu(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the 3-dot options menu containing Exit Game, Restart, and Revert.
  Widget _buildOptionsMenu() {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.more_vert_rounded,
          color: Colors.black87,
          size: 20,
        ),
      ),
      tooltip: 'Options',
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
          value: 'revert',
          enabled: _game.canRevert,
          child: Row(
            children: [
              Icon(
                Icons.undo_rounded,
                color: _game.canRevert ? Colors.black87 : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Revert',
                style: TextStyle(
                  color: _game.canRevert ? Colors.black87 : Colors.grey,
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

  /// Builds the side player column with the anchored semicircle turn indicator.
  Widget _buildPlayerSide({
    required FourInARowPlayer player,
    required String label,
    required Color color,
    required bool isActive,
    required bool isLeft,
  }) {
    return SizedBox(
      width: 110,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment:
            isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          // Player Avatar Badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: isActive ? 1.0 : 0.6,
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      player == FourInARowPlayer.player1
                          ? Icons.person_rounded
                          : Icons.person_outline_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    player.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      color: isActive ? color : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Anchored Semicircle Turn Indicator
          _buildSemicircleIndicator(
            color: color,
            label: '$label TURN',
            isActive: isActive,
            isLeft: isLeft,
          ),
        ],
      ),
    );
  }

  /// Semicircle turn indicator anchored to the bottom screen edge.
  Widget _buildSemicircleIndicator({
    required Color color,
    required String label,
    required bool isActive,
    required bool isLeft,
  }) {
    final borderRadius = isLeft
        ? const BorderRadius.only(
            topRight: Radius.circular(32),
            bottomRight: Radius.circular(8),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(32),
            bottomLeft: Radius.circular(8),
          );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: isActive ? 108 : 96,
      height: 46,
      padding: EdgeInsets.only(
        left: isLeft ? 10 : 8,
        right: isLeft ? 8 : 10,
        top: 6,
        bottom: 6,
      ),
      decoration: BoxDecoration(
        color: isActive ? color : color.withValues(alpha: 0.2),
        borderRadius: borderRadius,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isActive ? Colors.white : color.withValues(alpha: 0.9),
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Interactive 7x6 board with column tap gestures and floating winning line overlay.
  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / FourInARowGame.cols;
        final cellHeight = constraints.maxHeight / FourInARowGame.rows;

        return Stack(
          children: [
            // Blue Board Frame with Holes
            Container(
              decoration: BoxDecoration(
                color: _boardColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade900.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
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

            // Floating White Winning Line Overlay
            if (_game.status == FourInARowGameStatus.won &&
                _game.winningPositions.length >= FourInARowGame.connectCount)
              Positioned.fill(
                child: CustomPaint(
                  painter: _WinningLinePainter(
                    winningPositions: _game.winningPositions,
                    cellWidth: cellWidth,
                    cellHeight: cellHeight,
                  ),
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

/// Custom painter that draws a crisp floating white line overlay over the winning 4 discs.
class _WinningLinePainter extends CustomPainter {
  final List<BoardPosition> winningPositions;
  final double cellWidth;
  final double cellHeight;

  _WinningLinePainter({
    required this.winningPositions,
    required this.cellWidth,
    required this.cellHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (winningPositions.length < 4) return;

    final first = winningPositions.first;
    final last = winningPositions.last;

    // Calculate center coordinates of start and end winning discs
    final startOffset = Offset(
      (first.col * cellWidth) + (cellWidth / 2),
      (first.row * cellHeight) + (cellHeight / 2),
    );

    final endOffset = Offset(
      (last.col * cellWidth) + (cellWidth / 2),
      (last.row * cellHeight) + (cellHeight / 2),
    );

    // Subtle drop shadow under the line
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      startOffset.translate(0, 2),
      endOffset.translate(0, 2),
      shadowPaint,
    );

    // Main crisp white overlay line
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(startOffset, endOffset, linePaint);
  }

  @override
  bool shouldRepaint(covariant _WinningLinePainter oldDelegate) {
    return oldDelegate.winningPositions != winningPositions ||
        oldDelegate.cellWidth != cellWidth ||
        oldDelegate.cellHeight != cellHeight;
  }
}
