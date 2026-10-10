import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../data/games_registry.dart';
import '../../../games/dots_and_boxes/logic/dots_and_boxes_game.dart';
import '../../../games/dots_and_boxes/models/dots_and_boxes_models.dart';
import '../../../games/dots_and_boxes/presentation/dots_and_boxes_match_controller.dart';
import '../../../models/game_definition.dart';
import '../../../widgets/turn_indicator.dart';
import '../../game_result_screen.dart';

/// Where every dot, line and box sits inside the board panel.
///
/// One cell is the gap between two neighbouring dots, and the panel's
/// own padding is kept proportional to it so the board looks the same at
/// any size.
class _BoardGeometry {
  const _BoardGeometry({required this.cell, required this.padding});

  /// Fits the biggest board that will sit inside [available].
  factory _BoardGeometry.fit(Size available) {
    const paddingFactor = 0.45;
    final acrossCells = (DotsAndBoxesGame.dotColumns - 1) + (paddingFactor * 2);
    final downCells = (DotsAndBoxesGame.dotRows - 1) + (paddingFactor * 2);

    final cell = math.min(
      available.width / acrossCells,
      available.height / downCells,
    );
    return _BoardGeometry(cell: cell, padding: cell * paddingFactor);
  }

  final double cell;
  final double padding;

  double get width =>
      (padding * 2) + (cell * (DotsAndBoxesGame.dotColumns - 1));

  double get height => (padding * 2) + (cell * (DotsAndBoxesGame.dotRows - 1));

  Offset dotCentre(int row, int col) =>
      Offset(padding + (col * cell), padding + (row * cell));

  /// The bar drawn for a line, stopping short of the dots at each end.
  Rect barRect(BoxEdge edge) {
    final start = dotCentre(edge.row, edge.col);
    final thickness = cell * 0.17;
    final inset = cell * 0.16;

    return edge.isHorizontal
        ? Rect.fromLTWH(start.dx + inset, start.dy - (thickness / 2),
            cell - (inset * 2), thickness)
        : Rect.fromLTWH(start.dx - (thickness / 2), start.dy + inset, thickness,
            cell - (inset * 2));
  }

  /// A finger-sized area around a line.
  Rect hitRect(BoxEdge edge) {
    final start = dotCentre(edge.row, edge.col);
    final across = cell * 0.46;

    return edge.isHorizontal
        ? Rect.fromLTWH(start.dx, start.dy - (across / 2), cell, across)
        : Rect.fromLTWH(start.dx - (across / 2), start.dy, across, cell);
  }

  Rect boxRect(int row, int col) {
    final topLeft = dotCentre(row, col);
    return Rect.fromLTWH(topLeft.dx, topLeft.dy, cell, cell);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BoardGeometry &&
          cell == other.cell &&
          padding == other.padding;

  @override
  int get hashCode => Object.hash(cell, padding);
}

/// Visual Specifications:
/// - Dynamic background: soft blue on Blue turn, soft coral on Red turn
///   (AGENTS.md §10.1.7)
/// - A cream rounded panel carrying the dot grid: fat black dots, white
///   bars where a line could still go, near-black bars where one has
///   been drawn, and claimed boxes filled in their owner's colour
/// - The lines drawn in the most recent turn stay in that player's own
///   colour, so whoever is about to play can see what just happened
/// - A new line is drawn on, growing out from its middle, and a box it
///   closes pops in behind it
/// - Face-to-face turn indicators, a live box count top-left, and the
///   standard 3-dot options menu top-right
/// - Seamless transition to the shared celebratory GameResultScreen
class DotsAndBoxesScreen extends StatefulWidget {
  final GameMode mode;

  const DotsAndBoxesScreen({
    super.key,
    this.mode = GameMode.local,
  });

  @override
  State<DotsAndBoxesScreen> createState() => _DotsAndBoxesScreenState();
}

class _DotsAndBoxesScreenState extends State<DotsAndBoxesScreen>
    with SingleTickerProviderStateMixin {
  late final DotsAndBoxesMatchController _matchController;

  /// This game's metadata, looked up once so the turn indicator layout
  /// and orientation contract are driven by configuration rather than
  /// hardcoded in this screen (AGENTS.md §10.1.6).
  static final GameDefinition _definition =
      kGames.firstWhere((g) => g.id == 'dots_and_boxes');

  // Platform player identity (AGENTS.md §10.1.1) and the turn
  // backgrounds the other board games already use.
  static const Color _bluePlayerColor = Color(0xFF00ACF8);
  static const Color _redPlayerColor = Color(0xFFFF5E57);
  static const Color _blueBgColor = Color(0xFF63C5F0);
  static const Color _redBgColor = Color(0xFFF28D88);
  static const Color _optionsButtonColor = Color(0xFF303943);

  /// The board itself: a warm off-white panel, black dots, white gaps
  /// where a line could still go, and near-black where one has.
  static const Color _panelColor = Color(0xFFFDF0EB);
  static const Color _dotColor = Color(0xFF111111);
  static const Color _openEdgeColor = Color(0xFFFFFFFF);
  static const Color _drawnEdgeColor = Color(0xFF3A3A3A);

  static const double _panelRadius = 26;

  /// How long a line takes to draw itself on.
  static const int _lineMs = 260;
  static const int _resultDelayMs = 700;

  late final AnimationController _lineController;
  DotsAndBoxesMove? _animatingMove;

  int _lastHandledMoveCount = 0;
  bool _isTransitioningToResult = false;
  bool _isOptionsMenuOpen = false;
  Timer? _resultTransitionTimer;

  @override
  void initState() {
    super.initState();
    _matchController = DotsAndBoxesMatchController(mode: widget.mode)
      ..addListener(_onMatchStateChanged);
    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _lineMs),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _animatingMove = null);
          // The line is fully on, so the opponent may answer now.
          _matchController.setPresentationBusy(false);
        }
      });
  }

  @override
  void dispose() {
    _resultTransitionTimer?.cancel();
    _lineController.dispose();
    _matchController
      ..removeListener(_onMatchStateChanged)
      ..dispose();
    super.dispose();
  }

  /// One reaction point for everything the controller reports. A real
  /// move is told apart from a revert or restart by the move count going
  /// up, so only a real move animates (AGENTS.md §10.1.8).
  void _onMatchStateChanged() {
    if (!mounted) return;

    final game = _matchController.game;
    final isNewMove = game.moveCount > _lastHandledMoveCount;
    _lastHandledMoveCount = game.moveCount;

    if (isNewMove) {
      final move = _matchController.lastMove;
      if (move != null) {
        // Claimed before the controller gets as far as scheduling the
        // bot, because this runs inside the same notification as the
        // move. That ordering is what holds the bot back.
        _matchController.setPresentationBusy(true);
        _animatingMove = move;
        _lineController.forward(from: 0);
      }
      if (game.isGameOver) _scheduleResultTransition();
    }

    setState(() {});
  }

  void _onEdgeTap(BoxEdge edge) {
    // A line resolves the instant it is drawn, so a second tap mid-draw
    // would leave the animation describing a board that has moved on.
    if (_isTransitioningToResult || _animatingMove != null) return;
    _matchController.submitLocalEdge(edge);
  }

  void _resetAnimation() {
    _lineController.stop();
    _lineController.reset();
    _animatingMove = null;
  }

  void _revertMove() {
    if (!_matchController.canRevert || _isTransitioningToResult) return;
    _matchController.revert();
    _lastHandledMoveCount = _matchController.game.moveCount;
    setState(_resetAnimation);
    // Cleared outside the setState so a bot scheduled off the back of it
    // cannot re-enter one.
    _matchController.setPresentationBusy(false);
  }

  void _restartGame() {
    _resultTransitionTimer?.cancel();
    _resultTransitionTimer = null;
    _matchController.restart();
    _lastHandledMoveCount = 0;
    setState(() {
      _resetAnimation();
      _isTransitioningToResult = false;
    });
    _matchController.setPresentationBusy(false);
  }

  void _exitGame() => Navigator.of(context).pop();

  void _navigateToResultScreen() {
    final game = _matchController.game;

    final resultData = switch (game.status) {
      DotsAndBoxesGameStatus.draw => GameResultData.draw(label: 'DRAW'),
      _ => game.winner == DotsAndBoxesPlayer.player1
          ? GameResultData.blueWin(label: 'BLUE PLAYER\nWINS!')
          : GameResultData.redWin(label: _matchController.redWinnerLabel),
    };

    GameResultScreen.show(
      context,
      resultData: resultData,
      onPlayAgain: _restartGame,
      onExit: _exitGame,
    );
  }

  void _scheduleResultTransition() {
    if (_isTransitioningToResult) return;

    setState(() => _isTransitioningToResult = true);
    _resultTransitionTimer =
        Timer(const Duration(milliseconds: _resultDelayMs), () {
      if (mounted && _isTransitioningToResult) _navigateToResultScreen();
    });
  }

  // ── Composition ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // The declared orientation behavior is the enforced contract for this
    // screen's composition, not a decorative label (AGENTS.md §8).
    final gameBody = switch (_definition.orientationBehavior) {
      GameOrientationBehavior.fixedPortrait => _buildFixedPortraitComposition(),
      GameOrientationBehavior.fixedLandscape ||
      GameOrientationBehavior.adaptive =>
        throw UnsupportedError(
          'DotsAndBoxesScreen only implements '
          'GameOrientationBehavior.fixedPortrait, but dots_and_boxes is '
          'declared as ${_definition.orientationBehavior}.',
        ),
    };

    return PopScope(canPop: true, child: Scaffold(body: gameBody));
  }

  Widget _buildFixedPortraitComposition() {
    final game = _matchController.game;
    final isBlueTurn = game.currentPlayer == DotsAndBoxesPlayer.player1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      color: isBlueTurn ? _blueBgColor : _redBgColor,
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 104, 12, 104),
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final geometry = _BoardGeometry.fit(constraints.biggest);
                    return SizedBox(
                      key: const ValueKey('dots_and_boxes_board'),
                      width: geometry.width,
                      height: geometry.height,
                      child: _buildBoard(geometry),
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
                  label: 'BLUE',
                  isActive: isBlueTurn,
                ),
                second: TurnIndicatorSpec(
                  color: _redPlayerColor,
                  label: 'RED',
                  isActive: !isBlueTurn,
                ),
                isGameOver: game.isGameOver,
              ),
            ),

            Positioned(top: 12, left: 16, child: _buildScoreChip(game)),

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

  Widget _buildScoreChip(DotsAndBoxesGame game) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _ScoreDot(color: _redPlayerColor),
          const SizedBox(width: 7),
          Text(
            '${game.redScore}',
            key: const ValueKey('dots_and_boxes_score_red'),
            style: _scoreTextStyle,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(':', style: _scoreTextStyle),
          ),
          Text(
            '${game.blueScore}',
            key: const ValueKey('dots_and_boxes_score_blue'),
            style: _scoreTextStyle,
          ),
          const SizedBox(width: 7),
          const _ScoreDot(color: _bluePlayerColor),
        ],
      ),
    );
  }

  static const TextStyle _scoreTextStyle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 15,
    color: Color(0xFF1B1F26),
  );

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
        child:
            const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
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

  // ── Board ─────────────────────────────────────────────────────────────

  Widget _buildBoard(_BoardGeometry geometry) {
    final game = _matchController.game;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(_panelRadius),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _lineController,
              builder: (context, _) => CustomPaint(
                painter: _BoardPainter(
                  game: game,
                  geometry: geometry,
                  animatingMove: _animatingMove,
                  progress: _lineController.value,
                  blue: _bluePlayerColor,
                  red: _redPlayerColor,
                  dotColor: _dotColor,
                  openEdgeColor: _openEdgeColor,
                  drawnEdgeColor: _drawnEdgeColor,
                ),
              ),
            ),
          ),
          // Transparent tap targets, one per line. Kept as widgets rather
          // than hit-testing the painter so each has a key a test can
          // reach, the way every other board on the platform works.
          for (final edge in _allEdges()) _buildEdgeTarget(edge, geometry),
        ],
      ),
    );
  }

  static List<BoxEdge> _allEdges() => [
        for (var row = 0; row < DotsAndBoxesGame.boxRows; row++)
          for (var col = 0; col < DotsAndBoxesGame.dotColumns; col++)
            BoxEdge.vertical(row, col),
        for (var row = 0; row < DotsAndBoxesGame.dotRows; row++)
          for (var col = 0; col < DotsAndBoxesGame.boxColumns; col++)
            BoxEdge.horizontal(row, col),
      ];

  Widget _buildEdgeTarget(BoxEdge edge, _BoardGeometry geometry) {
    final rect = geometry.hitRect(edge);
    final name = edge.isHorizontal ? 'h' : 'v';

    return Positioned.fromRect(
      rect: rect,
      child: GestureDetector(
        key: ValueKey('dab_edge_${name}_${edge.row}_${edge.col}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _onEdgeTap(edge),
      ),
    );
  }
}

class _ScoreDot extends StatelessWidget {
  final Color color;

  const _ScoreDot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// Paints the whole board: claimed boxes, then every line, then the dots
/// on top so the bars tuck under them.
class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.game,
    required this.geometry,
    required this.animatingMove,
    required this.progress,
    required this.blue,
    required this.red,
    required this.dotColor,
    required this.openEdgeColor,
    required this.drawnEdgeColor,
  });

  final DotsAndBoxesGame game;
  final _BoardGeometry geometry;
  final DotsAndBoxesMove? animatingMove;
  final double progress;
  final Color blue;
  final Color red;
  final Color dotColor;
  final Color openEdgeColor;
  final Color drawnEdgeColor;

  /// A box waits until the line that closed it is most of the way on.
  static const double _boxStart = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBoxes(canvas);
    _paintEdges(canvas);
    _paintDots(canvas);
  }

  Color _colourOf(DotsAndBoxesPlayer player) =>
      player == DotsAndBoxesPlayer.player1 ? blue : red;

  void _paintBoxes(Canvas canvas) {
    final justClaimed = animatingMove?.claimedBoxes ?? const <BoxCell>[];
    final boxProgress = Curves.easeOutBack.transform(
      ((progress - _boxStart) / (1 - _boxStart)).clamp(0.0, 1.0),
    );

    for (var row = 0; row < DotsAndBoxesGame.boxRows; row++) {
      for (var col = 0; col < DotsAndBoxesGame.boxColumns; col++) {
        final owner = game.boxOwner(row, col);
        if (owner == null) continue;

        final isNew = justClaimed.contains(BoxCell(row, col));
        final scale = isNew ? boxProgress : 1.0;
        if (scale <= 0) continue;

        final full = geometry.boxRect(row, col).deflate(geometry.cell * 0.06);
        final rect = Rect.fromCenter(
          center: full.center,
          width: full.width * scale,
          height: full.height * scale,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(geometry.cell * 0.1 * scale),
          ),
          Paint()..color = _colourOf(owner),
        );
      }
    }
  }

  void _paintEdges(Canvas canvas) {
    // Only the single newest line wears its player's colour, so
    // whoever is about to play can see what was just done to them. A
    // run of them all in colour would read as a block, not as lines.
    final highlighted = game.lastEdge;
    final highlightColour = game.lastEdgePlayer == null
        ? drawnEdgeColor
        : _colourOf(game.lastEdgePlayer!);
    final growing = animatingMove?.edge;
    final growth = Curves.easeOutCubic.transform(progress);

    for (var row = 0; row < DotsAndBoxesGame.dotRows; row++) {
      for (var col = 0; col < DotsAndBoxesGame.boxColumns; col++) {
        _paintEdge(canvas, BoxEdge.horizontal(row, col), highlighted,
            highlightColour, growing, growth);
      }
    }
    for (var row = 0; row < DotsAndBoxesGame.boxRows; row++) {
      for (var col = 0; col < DotsAndBoxesGame.dotColumns; col++) {
        _paintEdge(canvas, BoxEdge.vertical(row, col), highlighted,
            highlightColour, growing, growth);
      }
    }
  }

  void _paintEdge(
    Canvas canvas,
    BoxEdge edge,
    BoxEdge? highlighted,
    Color highlightColour,
    BoxEdge? growing,
    double growth,
  ) {
    final drawn = game.isDrawn(edge);
    var rect = geometry.barRect(edge);

    if (drawn && edge == growing) {
      // Grows out from the middle of its own length.
      rect = edge.isHorizontal
          ? Rect.fromCenter(
              center: rect.center,
              width: rect.width * growth,
              height: rect.height)
          : Rect.fromCenter(
              center: rect.center,
              width: rect.width,
              height: rect.height * growth);
      if (rect.width <= 0 || rect.height <= 0) return;
    }

    final colour = !drawn
        ? openEdgeColor
        : edge == highlighted
            ? highlightColour
            : drawnEdgeColor;

    // Square ends, not rounded: the lines read as a drawn grid rather
    // than as a scatter of pills.
    canvas.drawRect(rect, Paint()..color = colour);
  }

  void _paintDots(Canvas canvas) {
    final paint = Paint()..color = dotColor;
    final radius = geometry.cell * 0.165;

    for (var row = 0; row < DotsAndBoxesGame.dotRows; row++) {
      for (var col = 0; col < DotsAndBoxesGame.dotColumns; col++) {
        canvas.drawCircle(geometry.dotCentre(row, col), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.animatingMove != animatingMove ||
      oldDelegate.geometry != geometry ||
      oldDelegate.game.moveCount != game.moveCount;
}
