import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../data/games_registry.dart';
import '../../../models/game_definition.dart';
import '../../../games/color_war/models/color_war_models.dart';
import '../../../games/color_war/presentation/color_war_match_controller.dart';
import '../../../widgets/turn_indicator.dart';
import '../../game_result_screen.dart';

/// Visual Specifications:
/// - Dynamic background: soft blue on Blue turn, soft coral on Red turn
///   (AGENTS.md §10.1.7)
/// - A square grid of cream tiles; a claimed tile is tinted in its owner's
///   colour and carries one disc, with a white pip per orb inside it
/// - Face-to-face turn indicators: near/Blue at the bottom, far/Red at the
///   top (AGENTS.md §10.1.2 portrait fixed-side positioning)
/// - 3-dot options menu top right. There is no scoreboard: the board is
///   the score
/// - A chain reaction plays out one wave at a time, driven by
///   [ColorWarMatchController]. Each wave is held for a beat while orbs are
///   thrown out of the bursting cells, so the board is never seen
///   teleporting
/// - Seamless transition to the full-screen celebratory GameResultScreen
class ColorWarScreen extends StatefulWidget {
  final GameMode mode;

  const ColorWarScreen({
    super.key,
    this.mode = GameMode.local,
  });

  @override
  State<ColorWarScreen> createState() => _ColorWarScreenState();
}

class _ColorWarScreenState extends State<ColorWarScreen>
    with SingleTickerProviderStateMixin {
  late final ColorWarMatchController _matchController;

  /// This game's metadata, looked up once so the turn indicator layout and
  /// orientation contract are driven by configuration rather than hardcoded
  /// in this screen (AGENTS.md §10.1.6).
  static final GameDefinition _definition =
      kGames.firstWhere((g) => g.id == 'color_war');

  // Platform player identity (AGENTS.md §10.1.1) and the turn backgrounds
  // the other board games already use.
  static const Color _bluePlayerColor = Color(0xFF00ACF8);
  static const Color _redPlayerColor = Color(0xFFFF5E57);
  static const Color _blueBgColor = Color(0xFF63C5F0);
  static const Color _redBgColor = Color(0xFFF28D88);
  static const Color _optionsButtonColor = Color(0xFF303943);

  /// The board itself: bare tiles, no panel behind them.
  static const Color _emptyTileColor = Color(0xFFF7E7D3);
  static const Color _blueTileColor = Color(0xFFCDEDFB);
  static const Color _redTileColor = Color(0xFFFBD7D4);

  bool _isTransitioningToResult = false;
  bool _isOptionsMenuOpen = false;
  Timer? _resultTransitionTimer;

  /// Drives the orbs flying out of a bursting cell. Runs for exactly the
  /// window the controller holds each wave open for, so the flight always
  /// lands just as the board updates.
  late final AnimationController _burstController;
  int _lastBurstTick = 0;

  @override
  void initState() {
    super.initState();
    _matchController = ColorWarMatchController(mode: widget.mode)
      ..addListener(_onMatchStateChanged);
    _burstController = AnimationController(
      vsync: this,
      duration: _matchController.blastStepDuration,
    );
  }

  @override
  void dispose() {
    _resultTransitionTimer?.cancel();
    _burstController.dispose();
    _matchController
      ..removeListener(_onMatchStateChanged)
      ..dispose();
    super.dispose();
  }

  /// Reacts to every controller change in one place -- a local move, each
  /// wave of a chain reaction, a Bot reply, revert or restart -- since a
  /// cascade and a Bot's answer both arrive on their own timers rather than
  /// from [_onCellTap] (AGENTS.md §10.1.8).
  void _onMatchStateChanged() {
    if (!mounted) return;

    if (_matchController.burstTick != _lastBurstTick) {
      _lastBurstTick = _matchController.burstTick;
      if (_matchController.burstingCells.isNotEmpty) {
        _burstController.forward(from: 0);
      }
    }

    if (_matchController.game.isGameOver) _scheduleResultTransition();
    setState(() {});
  }

  void _onCellTap(int row, int col) {
    if (_isTransitioningToResult) return;
    _matchController.submitLocalCell(row, col);
  }

  void _revertMove() {
    if (!_matchController.canRevert || _isTransitioningToResult) return;
    _matchController.revert();
  }

  void _restartGame() {
    _resultTransitionTimer?.cancel();
    _resultTransitionTimer = null;
    _matchController.restart();
    setState(() => _isTransitioningToResult = false);
  }

  void _exitGame() => Navigator.of(context).pop();

  void _navigateToResultScreen() {
    final winner = _matchController.game.winner;
    final resultData = winner == ColorWarPlayer.player1
        ? GameResultData.blueWin(label: 'BLUE PLAYER\nWINS!')
        : GameResultData.redWin(label: _matchController.redWinnerLabel);

    GameResultScreen.show(
      context,
      resultData: resultData,
      onPlayAgain: _restartGame,
      onExit: _exitGame,
    );
  }

  /// Holds the finished board on screen for a beat so the last chain
  /// reaction is seen landing before the result takes over.
  void _scheduleResultTransition() {
    if (_isTransitioningToResult) return;

    setState(() => _isTransitioningToResult = true);
    _resultTransitionTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted && _isTransitioningToResult) _navigateToResultScreen();
    });
  }

  @override
  Widget build(BuildContext context) {
    // The declared orientation behavior is the enforced contract for this
    // screen's composition, not a decorative label (AGENTS.md §8).
    final gameBody = switch (_definition.orientationBehavior) {
      GameOrientationBehavior.fixedPortrait => _buildFixedPortraitComposition(),
      GameOrientationBehavior.fixedLandscape ||
      GameOrientationBehavior.adaptive =>
        throw UnsupportedError(
          'ColorWarScreen only implements '
          'GameOrientationBehavior.fixedPortrait, but color_war is '
          'declared as ${_definition.orientationBehavior}.',
        ),
    };

    return PopScope(
      canPop: true,
      child: Scaffold(body: gameBody),
    );
  }

  /// The screen's one and only supported composition: a square board
  /// centred between the two face-to-face turn indicators. A square board
  /// reads the same whether the device is held portrait or landscape, so
  /// this composition simply fits itself to whichever of the available
  /// width/height is more constraining -- it never rotates its pixels
  /// (AGENTS.md §8.1-8.4).
  Widget _buildFixedPortraitComposition() {
    final game = _matchController.game;
    final isBlueTurn = game.currentPlayer == ColorWarPlayer.player1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      color: isBlueTurn ? _blueBgColor : _redBgColor,
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 110, 20, 110),
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side =
                        math.min(constraints.maxWidth, constraints.maxHeight);
                    return SizedBox(
                      key: const ValueKey('color_war_board'),
                      width: side,
                      height: side,
                      child: _buildBoard(),
                    );
                  },
                ),
              ),
            ),

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

            if (_isOptionsMenuOpen) ...[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _isOptionsMenuOpen = false),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(top: 54, right: 14, child: _buildOptionsMenuPanel()),
            ],

            Positioned(top: 10, right: 14, child: _buildOptionsButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsButton() {
    return GestureDetector(
      onTap: () => setState(() => _isOptionsMenuOpen = !_isOptionsMenuOpen),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _optionsButtonColor.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
      ),
    );
  }

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
            Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard() {
    final game = _matchController.game;
    final bursting = _matchController.burstingCells;

    return Stack(
      children: [
        Column(
          children: [
            for (var row = 0; row < game.rows; row++)
              Expanded(
                child: Row(
                  children: [
                    for (var col = 0; col < game.cols; col++)
                      Expanded(child: _buildTile(row, col)),
                  ],
                ),
              ),
          ],
        ),

        // Orbs on their way out of the cells that are going off. Drawn
        // over the board rather than inside a tile, since they cross from
        // one tile into the next.
        if (bursting.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _burstController,
                builder: (context, _) => CustomPaint(
                  painter: _BurstPainter(
                    sources: bursting,
                    rows: game.rows,
                    cols: game.cols,
                    color: _matchController.burstingPlayer ==
                            ColorWarPlayer.player2
                        ? _redPlayerColor
                        : _bluePlayerColor,
                    progress: _burstController.value,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTile(int row, int col) {
    final cell = _matchController.game.cellAt(row, col);
    final tileColor = switch (cell.owner) {
      ColorWarPlayer.player1 => _blueTileColor,
      ColorWarPlayer.player2 => _redTileColor,
      null => _emptyTileColor,
    };

    return GestureDetector(
      key: ValueKey('cw_cell_${row}_$col'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(row, col),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: AnimatedScale(
              scale: cell.isEmpty ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
              child: FractionallySizedBox(
                widthFactor: 0.68,
                heightFactor: 0.68,
                child: cell.isEmpty
                    ? const SizedBox.shrink()
                    : CustomPaint(
                        painter: _OrbPainter(
                          color: cell.owner == ColorWarPlayer.player1
                              ? _bluePlayerColor
                              : _redPlayerColor,
                          orbs: cell.orbs,
                        ),
                        child: const SizedBox.expand(),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A cell going off: a ring pushing outwards from it, and one orb flying
/// into each neighbour it is about to claim.
///
/// The board underneath still shows the pre-burst state for the whole of
/// this animation -- the engine only applies the wave once the flight
/// lands -- so the orbs arrive exactly as the neighbours change colour.
class _BurstPainter extends CustomPainter {
  final List<ColorWarPosition> sources;
  final int rows;
  final int cols;
  final Color color;
  final double progress;

  const _BurstPainter({
    required this.sources,
    required this.rows,
    required this.cols,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (sources.isEmpty) return;

    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;
    final travel = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final orbRadius = cellWidth * 0.13;

    Offset centreOf(int row, int col) => Offset(
          (col + 0.5) * cellWidth,
          (row + 0.5) * cellHeight,
        );

    final orbPaint = Paint()..color = color;
    final ringPaint = Paint()
      ..color = color.withValues(alpha: (1 - travel) * 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellWidth * 0.08;

    for (final source in sources) {
      final from = centreOf(source.row, source.col);

      // A shockwave leaving the cell.
      canvas.drawCircle(
        from,
        (cellWidth * 0.22) + (cellWidth * 0.45 * travel),
        ringPaint,
      );

      for (final step in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        final row = source.row + step.$1;
        final col = source.col + step.$2;
        if (row < 0 || row >= rows || col < 0 || col >= cols) continue;

        canvas.drawCircle(
          Offset.lerp(from, centreOf(row, col), travel)!,
          orbRadius,
          orbPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.sources != sources ||
      oldDelegate.color != color;
}

/// One cell's contents: a single disc in the owner's colour, with a white
/// pip for each orb it is holding -- so how close a cell is to bursting can
/// be read at a glance, like the face of a die.
class _OrbPainter extends CustomPainter {
  final Color color;
  final int orbs;

  const _OrbPainter({required this.color, required this.orbs});

  /// Pip positions for 1..4 orbs, as fractions of the disc's radius.
  static const List<List<Offset>> _pipLayouts = [
    [Offset(0, 0)],
    [Offset(-0.40, 0), Offset(0.40, 0)],
    [Offset(0, -0.44), Offset(-0.40, 0.28), Offset(0.40, 0.28)],
    [
      Offset(-0.38, -0.38),
      Offset(0.38, -0.38),
      Offset(-0.38, 0.38),
      Offset(0.38, 0.38),
    ],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (orbs <= 0) return;

    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    canvas.drawCircle(centre, radius, Paint()..color = color);
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.10,
    );

    // A cell only rests below the burst limit, but mid-cascade it can
    // briefly collect more than that from several neighbours at once. It
    // goes off on the very next wave, so it just keeps the fullest face
    // rather than growing a layout of its own.
    final pips = orbs.clamp(1, _pipLayouts.length);

    final pipPaint = Paint()..color = Colors.white;
    final pipRadius = radius * (pips >= 3 ? 0.20 : 0.23);
    for (final pip in _pipLayouts[pips - 1]) {
      canvas.drawCircle(
        centre.translate(pip.dx * radius, pip.dy * radius),
        pipRadius,
        pipPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.orbs != orbs;
}
