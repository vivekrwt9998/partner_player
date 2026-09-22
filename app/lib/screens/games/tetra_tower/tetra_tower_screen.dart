import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../data/games_registry.dart';
import '../../../models/game_definition.dart';
import '../../../games/tetra_tower/logic/tetra_tower_game.dart';
import '../../../games/tetra_tower/models/tetra_tower_models.dart';
import '../../../games/tetra_tower/presentation/tetra_tower_match_controller.dart';
import '../../../widgets/turn_indicator.dart';
import '../../game_result_screen.dart';

/// Visual Specifications (matching Four in a Row / Tic Tac Toe / Checkers'
/// design):
/// - Dynamic background: soft blue on Blue turn, soft coral on Red turn
/// - A 4x4 "current floor" grid, framed like the other games' boards
/// - A stability meter (green -> red) and floor counter above the grid, and
///   a preview of the piece you're about to place with a rotate button
/// - Face-to-face turn indicators: near/Blue player at the bottom, far/Red
///   player at the top (AGENTS.md §10.1.2 portrait fixed-side positioning)
/// - 3-dot options menu in top right (Revert, Restart, Exit Game)
/// - Tap a highlighted cell to drop the current piece there; it pops in
/// - Seamless transition to full-screen celebratory GameResultScreen
class TetraTowerScreen extends StatefulWidget {
  final GameMode mode;

  /// Overrides the engine instance used for this match. Only meant for
  /// tests that need a deterministic piece sequence (e.g.
  /// `TetraTowerGame(random: Random(1))`) -- normal gameplay always omits
  /// this and gets a freshly-shuffled game.
  @visibleForTesting
  final TetraTowerGame? debugGame;

  const TetraTowerScreen({
    super.key,
    this.mode = GameMode.local,
    this.debugGame,
  });

  @override
  State<TetraTowerScreen> createState() => _TetraTowerScreenState();
}

class _TetraTowerScreenState extends State<TetraTowerScreen> {
  late final TetraTowerMatchController _matchController;

  /// This game's metadata, looked up once so the turn indicator layout and
  /// orientation contract are driven by configuration rather than hardcoded
  /// in this screen (AGENTS.md §10.1.6).
  static final GameDefinition _definition =
      kGames.firstWhere((g) => g.id == 'tetra_tower');

  // Color Palette matching the rest of the platform's design specification.
  static const Color _bluePlayerColor = Color(0xFF00ACF8); // Blue Player
  static const Color _redPlayerColor = Color(0xFFFF5E57); // Red Player
  static const Color _blueBgColor = Color(0xFF63C5F0); // Blue Turn Background
  static const Color _redBgColor = Color(0xFFF28D88); // Red Turn Background
  static const Color _boardColor = Color(0xFF303943); // Frame / Options Button
  static const Color _emptyCellColor = Color(0xFF58636F); // Empty grid cell

  bool _isTransitioningToResult = false;
  bool _isOptionsMenuOpen = false;
  Timer? _resultTransitionTimer;
  int _lastHandledMoveCount = 0;

  @override
  void initState() {
    super.initState();
    _matchController = TetraTowerMatchController(
      mode: widget.mode,
      game: widget.debugGame,
    )..addListener(_onMatchStateChanged);
  }

  @override
  void dispose() {
    _resultTransitionTimer?.cancel();
    _matchController
      ..removeListener(_onMatchStateChanged)
      ..dispose();
    super.dispose();
  }

  /// Reacts to every controller change (a placement, a rotation, a revert,
  /// or a restart) in one place, mirroring the other games' screens. Only
  /// a genuine new placement (the move count going up) can end the game.
  void _onMatchStateChanged() {
    if (!mounted) return;

    final game = _matchController.game;
    if (game.moveCount != _lastHandledMoveCount) {
      _lastHandledMoveCount = game.moveCount;
      if (game.isGameOver) {
        _scheduleResultTransition();
      }
    }
    setState(() {});
  }

  void _onCellTap(int row, int col) {
    if (_isTransitioningToResult) return;
    _matchController.submitLocalPlacement(row, col);
  }

  void _onRotateTap() {
    if (_isTransitioningToResult) return;
    _matchController.rotatePiece();
  }

  void _revertMove() {
    if (!_matchController.canRevert || _isTransitioningToResult) return;
    _matchController.revert();
    setState(() {});
  }

  void _restartGame() {
    _resultTransitionTimer?.cancel();
    _resultTransitionTimer = null;
    _matchController.restart();
    setState(() {
      _isTransitioningToResult = false;
    });
  }

  void _exitGame() {
    Navigator.of(context).pop();
  }

  void _navigateToResultScreen() {
    final game = _matchController.game;
    final isBlueWinner = game.winner == TetraTowerPlayer.player1;

    final resultData = isBlueWinner
        ? GameResultData.blueWin(label: 'BLUE PLAYER\nWINS!')
        : GameResultData.redWin(label: 'RED PLAYER\nWINS!');

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
          'TetraTowerScreen only implements '
          'GameOrientationBehavior.fixedPortrait, but tetra_tower is '
          'declared as ${_definition.orientationBehavior}.',
        ),
    };

    return PopScope(
      canPop: true,
      child: Scaffold(body: gameBody),
    );
  }

  /// The screen's one and only supported composition: a square 4x4 grid
  /// stacked vertically between the two face-to-face turn indicators, with
  /// the stability meter and piece preview above it. Like Tic Tac Toe and
  /// Checkers, a square grid reads the same whether the device is portrait
  /// or landscape -- this composition simply fits itself to whichever of
  /// the available width/height is more constraining, never needing to
  /// rotate its pixels (AGENTS.md §8.1-8.4).
  Widget _buildFixedPortraitComposition() {
    final game = _matchController.game;
    final isBlueTurn = game.currentPlayer == TetraTowerPlayer.player1;
    final currentBgColor = isBlueTurn ? _blueBgColor : _redBgColor;
    final currentPlayerColor = isBlueTurn ? _bluePlayerColor : _redPlayerColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      color: currentBgColor,
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 110, 20, 16),
              child: Column(
                children: [
                  _buildStabilityMeter(game),
                  const SizedBox(height: 14),
                  _buildPieceRow(game, currentPlayerColor),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final side = math.min(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          return SizedBox(
                            key: const ValueKey('tetra_tower_grid'),
                            width: side,
                            height: side,
                            child: _buildGrid(),
                          );
                        },
                      ),
                    ),
                  ),
                ],
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

  /// The stability gauge: fills from green to red as [TetraTowerGame.
  /// totalInstability] approaches [TetraTowerGame.collapseThreshold], plus
  /// which floor of the tower is currently being built.
  Widget _buildStabilityMeter(TetraTowerGame game) {
    final ratio =
        (game.totalInstability / TetraTowerGame.collapseThreshold).clamp(0.0, 1.0);
    final meterColor = Color.lerp(const Color(0xFF4CAF50), const Color(0xFFD32F2F), ratio)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'FLOOR ${game.currentLayerIndex + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'STABILITY',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 350),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 14,
              backgroundColor: Colors.black.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(meterColor),
            ),
          ),
        ),
      ],
    );
  }

  /// The current piece's shape preview plus its rotate button.
  Widget _buildPieceRow(TetraTowerGame game, Color pieceColor) {
    return Row(
      children: [
        _buildPiecePreview(game.currentPieceCells, pieceColor),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Place this piece, or rotate it first',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Material(
          color: Colors.black.withValues(alpha: 0.2),
          shape: const CircleBorder(),
          child: IconButton(
            onPressed: _matchController.canAcceptLocalInput ? _onRotateTap : null,
            icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
            tooltip: 'Rotate',
          ),
        ),
      ],
    );
  }

  Widget _buildPiecePreview(List<(int, int)> cells, Color color) {
    const cellPx = 15.0;
    final rowCount = cells.map((c) => c.$1).reduce(math.max) + 1;
    final colCount = cells.map((c) => c.$2).reduce(math.max) + 1;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        width: colCount * cellPx,
        height: rowCount * cellPx,
        child: Stack(
          children: [
            for (final cell in cells)
              Positioned(
                left: cell.$2 * cellPx,
                top: cell.$1 * cellPx,
                width: cellPx - 2,
                height: cellPx - 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                ),
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

  /// The current floor's 4x4 grid: a charcoal frame around cells that are
  /// either empty, occupied by a settled piece, or a highlighted legal spot
  /// for the current piece's anchor.
  Widget _buildGrid() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _boardColor, width: 5),
          color: _boardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: List.generate(
            TetraTowerGame.gridSize,
            (row) => Expanded(
              child: Row(
                children: List.generate(
                  TetraTowerGame.gridSize,
                  (col) => Expanded(child: _buildCell(row, col)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col) {
    final game = _matchController.game;
    final occupant = game.getCell(game.currentLayerIndex, row, col);
    final isLegalAnchor = occupant == null && game.canPlaceAt(row, col);

    return GestureDetector(
      key: ValueKey('tetra_tower_cell_${row}_$col'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(row, col),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: occupant == null
                      ? _emptyCellColor
                      : (occupant == TetraTowerPlayer.player1
                          ? _bluePlayerColor
                          : _redPlayerColor),
                  borderRadius: BorderRadius.circular(6),
                  border: occupant != null
                      ? Border.all(color: Colors.black, width: 2)
                      : null,
                ),
              ),
            ),
            if (isLegalAnchor)
              FractionallySizedBox(
                widthFactor: 0.4,
                heightFactor: 0.4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
