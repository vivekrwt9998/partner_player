import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../data/games_registry.dart';
import '../../../games/hex/logic/hex_game.dart';
import '../../../games/hex/models/hex_models.dart';
import '../../../games/hex/presentation/hex_match_controller.dart';
import '../../../models/game_definition.dart';
import '../../../widgets/turn_indicator.dart';
import '../../game_result_screen.dart';

/// Visual Specifications:
/// - Dynamic background: soft blue on Blue turn, soft coral on Red turn
///   (AGENTS.md §10.1.7)
/// - An 11x11 rhombus of cream hexagons, stood up tall so it fills a
///   portrait screen: flat-top cells, straight left and right sides,
///   slanted top and bottom
/// - The four sides are striped in the platform identity colours --
///   Blue owns the two straight sides, Red the two slanted ones -- and
///   both pairs breathe, so what each player is joining stays on the
///   board rather than being something to remember
/// - A stone is a hexagon filling its own cell, in the platform identity
///   (Blue/Red), with a thin outline and a light inner bevel, and pops
///   in where it lands
/// - The chain that wins pulses as a whole, every stone dipping and
///   springing back together, leaving the stones themselves in place
///   (AGENTS.md §10.1.14)
/// - Face-to-face turn indicators and the standard 3-dot options menu.
///   No score: Hex has nothing to count, and the room that saves goes
///   to the board
class HexScreen extends StatefulWidget {
  final GameMode mode;

  const HexScreen({
    super.key,
    this.mode = GameMode.local,
  });

  @override
  State<HexScreen> createState() => _HexScreenState();
}

class _HexScreenState extends State<HexScreen>
    with TickerProviderStateMixin {
  late final HexMatchController _matchController;

  /// This game's metadata, looked up once so the turn indicator layout
  /// and orientation contract are driven by configuration rather than
  /// hardcoded in this screen (AGENTS.md §10.1.6).
  static final GameDefinition _definition =
      kGames.firstWhere((g) => g.id == 'hex');

  // Platform player identity (AGENTS.md §10.1.1) and the turn
  // backgrounds the other board games already use.
  static const Color _bluePlayerColor = Color(0xFF00ACF8);
  static const Color _redPlayerColor = Color(0xFFFF5E57);
  static const Color _blueBgColor = Color(0xFF63C5F0);
  static const Color _redBgColor = Color(0xFFF28D88);
  static const Color _optionsButtonColor = Color(0xFF303943);

  /// A wooden Hex set: cream cells with dark ink between them. The
  /// screen behind keeps the platform's turn tint, and cream sits
  /// quietly against both halves of it (AGENTS.md §10.1.7).
  static const Color _boardSurfaceColor = Color(0xFFE9DCC0);
  static const Color _gridLineColor = Color(0xFF2B2622);

  // Move timings. A stone lands, and if it finished a chain the whole
  // chain then pulses.
  static const int _placeMs = 170;

  /// One dip-and-return of the winning chain, and how many of them it
  /// does before settling.
  static const int _winPulseMs = 350;
  static const int _winPulseCount = 2;

  /// Held back so a winning chain finishes pulsing before the result
  /// screen takes over. The longest run is 170 + 350*2 = 870ms, so
  /// these numbers are coupled: slow the pulse down and this has to
  /// grow with it.
  static const int _resultDelayMs = 1150;

  /// One half of the breath the side stripes take. Slow enough to read
  /// as a pulse rather than a flash (AGENTS.md §46).
  static const int _sidePulseMs = 900;

  late final AnimationController _moveController;

  /// Drives the glow on whichever sides the player to move has to join.
  /// Runs for the whole match, so it is its own controller rather than
  /// something the move animation has to carry.
  late final AnimationController _sidePulseController;

  /// The move being animated, and how long its animation runs for. A
  /// quiet move is just the stone landing; a winning one carries the
  /// chain highlight behind it.
  HexMove? _animatingMove;
  int _totalMs = _placeMs;

  /// The stones of the winning chain, so a cell can tell whether it is
  /// one of them without searching the list on every frame.
  Set<HexCell> _winCells = const {};

  int _lastHandledMoveCount = 0;
  bool _isTransitioningToResult = false;
  bool _isOptionsMenuOpen = false;
  Timer? _resultTransitionTimer;

  @override
  void initState() {
    super.initState();
    _matchController = HexMatchController(mode: widget.mode)
      ..addListener(_onMatchStateChanged);
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _placeMs),
    )..addStatusListener((status) {
        if (status != AnimationStatus.completed || !mounted) return;
        // The board has settled, so the opponent may answer now.
        _matchController.setPresentationBusy(false);
        // A winning move keeps its highlight up until the result screen
        // covers it; clearing it here would blink the chain off for the
        // last fraction of a second.
        if (_animatingMove?.isTerminal ?? false) return;
        setState(() {
          _animatingMove = null;
          _winCells = const {};
        });
      });
    _sidePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _sidePulseMs),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _resultTransitionTimer?.cancel();
    _sidePulseController.dispose();
    _moveController.dispose();
    _matchController
      ..removeListener(_onMatchStateChanged)
      ..dispose();
    super.dispose();
  }

  // ── Reacting to the match ─────────────────────────────────────────────

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
      if (move != null) _startMoveAnimation(move);
      if (game.isGameOver) _scheduleResultTransition();
    }

    setState(() {});
  }

  void _startMoveAnimation(HexMove move) {
    // Claimed before the controller gets as far as scheduling the bot,
    // because this runs inside the same notification as the move. That
    // ordering is what holds the bot back until the stone has landed.
    _matchController.setPresentationBusy(true);

    _animatingMove = move;
    _winCells = move.winningPath.toSet();
    _totalMs = move.winningPath.isEmpty
        ? _placeMs
        : _placeMs + (_winPulseMs * _winPulseCount);

    _moveController
      ..duration = Duration(milliseconds: _totalMs)
      ..forward(from: 0);
  }

  void _onCellTap(int row, int col) {
    // The engine applies a move instantly, so a second tap while the
    // stone is still landing would leave the animation describing a
    // board that no longer exists.
    if (_isTransitioningToResult || _animatingMove != null) return;
    _matchController.submitLocalMove(row, col);
  }

  void _resetAnimation() {
    _moveController.stop();
    _moveController.reset();
    _animatingMove = null;
    _winCells = const {};
    _totalMs = _placeMs;
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

  /// No draw arm: Hex cannot be drawn, so a finished game always has a
  /// winner.
  void _navigateToResultScreen() {
    final resultData = _matchController.game.winner == HexPlayer.player1
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
          'HexScreen only implements '
          'GameOrientationBehavior.fixedPortrait, but hex is '
          'declared as ${_definition.orientationBehavior}.',
        ),
    };

    return PopScope(canPop: true, child: Scaffold(body: gameBody));
  }

  /// A tall rhombus centred between the two face-to-face turn badges.
  /// The board keeps its own 17 : 16*sqrt(3) shape and is fitted to
  /// whichever side is more constraining, so it never crops and never
  /// rotates its pixels (AGENTS.md §8.1-8.4).
  Widget _buildFixedPortraitComposition() {
    final game = _matchController.game;
    final isBlueTurn = game.currentPlayer == HexPlayer.player1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      color: isBlueTurn ? _blueBgColor : _redBgColor,
      child: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Proportional rather than a flat 110: on a short
                // viewport a fixed inset would leave the board barely
                // a hundred points tall. The floor still clears the
                // face-to-face badges, which are at most 76 high.
                final inset = (constraints.maxHeight * 0.13).clamp(72.0, 110.0);

                return Padding(
                  // Narrow side margins: the board is the screen, and
                  // every point it loses to padding comes straight off
                  // the cells.
                  padding: EdgeInsets.fromLTRB(10, inset, 10, inset),
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, inner) {
                        final geometry = _HexGeometry.fit(inner.biggest);
                        return SizedBox(
                          key: const ValueKey('hex_board'),
                          width: geometry.width,
                          height: geometry.height,
                          child: _buildBoard(geometry),
                        );
                      },
                    ),
                  ),
                );
              },
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

  Widget _buildBoard(_HexGeometry geometry) {
    final game = _matchController.game;

    return Stack(
      children: [
        // One painter for the whole tessellation rather than 121
        // coloured children: flex rounding leaves hairline seams
        // between neighbours.
        Positioned.fill(
          child: CustomPaint(
            painter: _BoardPainter(
              geometry: geometry,
              surfaceColor: _boardSurfaceColor,
              lineColor: _gridLineColor,
            ),
          ),
        ),

        // The sides are their own layer because they breathe and the
        // cells behind them do not: repainting 121 hexagons every frame
        // to animate four stripes would be waste (AGENTS.md §29).
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _sidePulseController,
            builder: (context, _) {
              // Both pairs breathe, not just the player to move: these
              // stripes say which sides belong to whom, and that is as
              // true of the side you are not playing. Nothing breathes
              // once the game is won -- the winning chain is what should
              // hold the eye then.
              final breathing = !game.isGameOver;

              return CustomPaint(
                key: ValueKey(
                  'hex_sides_${breathing ? 'pulsing' : 'still'}',
                ),
                painter: _SidesPainter(
                  geometry: geometry,
                  blueSideColor: _bluePlayerColor,
                  redSideColor: _redPlayerColor,
                  pulse: breathing
                      ? Curves.easeInOut.transform(_sidePulseController.value)
                      : 0,
                ),
              );
            },
          ),
        ),

        for (var row = 0; row < HexGame.size; row++)
          for (var col = 0; col < HexGame.size; col++)
            _buildCell(row, col, geometry),
      ],
    );
  }

  /// One tap target per cell.
  ///
  /// Neighbouring hexagons have overlapping bounding boxes, so the
  /// [ClipPath] is doing real work: `RenderClipPath.hitTest` turns away
  /// anything outside the hexagon, which leaves exactly one cell
  /// claiming any given point. Inscribed rectangles would avoid the
  /// overlap instead, but they would also leave a quarter of every cell
  /// dead to the touch. Keyed widgets rather than hit-testing inside the
  /// painter, the way every other board on the platform works.
  Widget _buildCell(int row, int col, _HexGeometry geometry) {
    return Positioned.fromRect(
      rect: geometry.boundsOf(row, col),
      child: ClipPath(
        clipper: _HexClipper(geometry.radius),
        child: GestureDetector(
          key: ValueKey('hex_cell_${row}_$col'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _onCellTap(row, col),
          child: Center(child: _buildCellContents(row, col, geometry)),
        ),
      ),
    );
  }

  Widget _buildCellContents(int row, int col, _HexGeometry geometry) {
    final owner = _matchController.game.stoneAt(row, col);
    if (owner == null) return const SizedBox.shrink();

    final stone = _buildStone(owner, row, col, geometry);

    final move = _animatingMove;
    final isPlaced =
        move != null && move.cell.row == row && move.cell.col == col;
    final isWinning = _winCells.contains(HexCell(row, col));
    if (!isPlaced && !isWinning) return stone;

    return AnimatedBuilder(
      animation: _moveController,
      builder: (context, _) => Transform.scale(
        scale: _stoneScale(isPlaced: isPlaced, isWinning: isWinning),
        child: stone,
      ),
    );
  }

  /// How big a stone is drawn right now.
  ///
  /// Two things can be moving it and they multiply rather than fight:
  /// the stone that was just laid grows in from nothing, and the whole
  /// winning chain pulses. The stone that won is both.
  double _stoneScale({required bool isPlaced, required bool isWinning}) {
    var scale = 1.0;

    if (isPlaced) {
      scale *= Curves.easeOutBack.transform(
        (_moveController.value * _totalMs / _placeMs).clamp(0.0, 1.0),
      );
    }
    if (isWinning) scale *= _winPulseScale();

    return scale;
  }

  /// The pulse the winning chain does once the last stone has landed:
  /// down to 60% and back up past its own size, twice over.
  ///
  /// Every cell of the chain gets the same number, so the whole line
  /// beats at once rather than lighting up one end to the other.
  double _winPulseScale() {
    if (_winCells.isEmpty) return 1;

    final into = (_moveController.value * _totalMs) - _placeMs;
    const span = _winPulseMs * _winPulseCount;
    if (into <= 0 || into >= span) return 1;

    final phase = (into % _winPulseMs) / _winPulseMs;
    if (phase < 0.5) {
      return 1 - (0.4 * Curves.easeInOut.transform(phase / 0.5));
    }
    return 0.6 + (0.4 * Curves.easeOutBack.transform((phase - 0.5) / 0.5));
  }

  /// A stone is a hexagon filling its own cell, not a counter dropped on
  /// top of one: a finished chain reads as a run of filled cells, which
  /// is how a Hex board is meant to look.
  Widget _buildStone(
    HexPlayer owner,
    int row,
    int col,
    _HexGeometry geometry,
  ) {
    final colour =
        owner == HexPlayer.player1 ? _bluePlayerColor : _redPlayerColor;
    final side = owner == HexPlayer.player1 ? 'blue' : 'red';
    final stroke = math.max(1.5, geometry.stoneRadius * 0.11);

    return SizedBox(
      // The owner is in the key so a test can say which stone it found
      // without reaching into a painter.
      key: ValueKey('hex_stone_${side}_${row}_$col'),
      width: geometry.cellWidth,
      height: geometry.cellHeight,
      child: CustomPaint(
        painter: _StonePainter(
          radius: geometry.stoneRadius,
          colour: colour,
          strokeWidth: stroke,
        ),
      ),
    );
  }
}

// ── Geometry ────────────────────────────────────────────────────────────

/// Where every hexagon sits, derived from one number.
///
/// The board is flat-top hexagons laid out so that columns step
/// down-and-right and rows step straight down. That gives the rhombus
/// straight left and right sides and slanted top and bottom ones, and a
/// 17 : 16*sqrt(3) outline -- a shape that happens to be within a
/// percent of a phone screen's, which is why the board is stood up this
/// way round rather than laid on its side.
@immutable
class _HexGeometry {
  const _HexGeometry._(this.radius);

  /// Fits the board into [available], keeping its shape.
  factory _HexGeometry.fit(Size available) {
    final radius = math.min(
      available.width / _widthInRadii,
      available.height / _heightInRadii,
    );
    // A degenerate box (a zero-sized test surface, a collapsed parent)
    // must still produce a usable board rather than NaN geometry.
    return _HexGeometry._(radius.isFinite && radius > 0.5 ? radius : 0.5);
  }

  /// Centre to corner of one hexagon. Everything else is a multiple.
  final double radius;

  static const int _size = HexGame.size;
  static final double _sqrt3 = math.sqrt(3);

  /// Board width in radii: `1.5 * (size - 1)` between the outermost
  /// centres, plus half a hexagon at each end.
  static const double _widthInRadii = (1.5 * (_size - 1)) + 2;

  /// Board height in radii, before the sqrt(3) that turns a flat-top
  /// hexagon's radius into its height.
  static final double _heightInRadii = _sqrt3 * ((1.5 * (_size - 1)) + 1);

  double get width => radius * _widthInRadii;

  double get height => radius * _heightInRadii;

  /// Point to point across a flat-top hexagon.
  double get cellWidth => radius * 2;

  /// Flat to flat, which is the tighter of the two and so what a stone
  /// has to fit inside.
  double get cellHeight => radius * _sqrt3;

  /// A stone is its cell, filled in: the same hexagon at the same size,
  /// so a chain of them reads as one solid run across the board. Its
  /// outline is half-clipped away by the cell it sits in, which is what
  /// leaves the grid still showing between neighbours.
  double get stoneRadius => radius;

  Offset centreOf(int row, int col) => Offset(
        radius + (1.5 * radius * col),
        _sqrt3 * radius * (0.5 + row + (col / 2)),
      );

  /// The hexagon's bounding box. Neighbouring boxes overlap, which is
  /// why the cells clip themselves before accepting a tap.
  Rect boundsOf(int row, int col) => Rect.fromCenter(
        center: centreOf(row, col),
        width: cellWidth,
        height: cellHeight,
      );

  /// Corner [index] of the hexagon at (row, col), counted from the one
  /// due right and going clockwise on screen. Edge `k` runs from corner
  /// `k` to corner `k + 1`, which is the same `k` as
  /// [HexGame.neighbourOffsets].
  Offset cornerOf(int row, int col, int index) {
    final angle = index * math.pi / 3;
    final centre = centreOf(row, col);
    return Offset(
      centre.dx + (radius * math.cos(angle)),
      centre.dy + (radius * math.sin(angle)),
    );
  }

  Path hexPathAt(int row, int col) =>
      _hexagonPath(centreOf(row, col), radius);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HexGeometry &&
          runtimeType == other.runtimeType &&
          radius == other.radius;

  @override
  int get hashCode => radius.hashCode;
}

Path _hexagonPath(Offset centre, double radius) {
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final angle = i * math.pi / 3;
    final point = Offset(
      centre.dx + (radius * math.cos(angle)),
      centre.dy + (radius * math.sin(angle)),
    );
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}

/// Clips a cell to its own hexagon, so a tap in the overlap between two
/// bounding boxes reaches the cell actually under the finger. Every
/// hexagon is the same shape, so one clipper serves all 121.
class _HexClipper extends CustomClipper<Path> {
  const _HexClipper(this.radius);

  final double radius;

  @override
  Path getClip(Size size) =>
      _hexagonPath(Offset(size.width / 2, size.height / 2), radius);

  @override
  bool shouldReclip(_HexClipper oldClipper) => oldClipper.radius != radius;
}

// ── Painter ─────────────────────────────────────────────────────────────

/// The board itself: the cream tessellation and the ink between cells.
class _BoardPainter extends CustomPainter {
  const _BoardPainter({
    required this.geometry,
    required this.surfaceColor,
    required this.lineColor,
  });

  final _HexGeometry geometry;
  final Color surfaceColor;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = surfaceColor;
    final ink = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, geometry.radius * 0.075);

    for (var row = 0; row < HexGame.size; row++) {
      for (var col = 0; col < HexGame.size; col++) {
        final path = geometry.hexPathAt(row, col);
        canvas.drawPath(path, fill);
        canvas.drawPath(path, ink);
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.surfaceColor != surfaceColor ||
      oldDelegate.lineColor != lineColor;
}

/// The four coloured sides: Blue along the two straight ones, Red along
/// the two slanted ones.
///
/// Both pairs breathe together -- deeper and a little heavier, then back
/// again -- so what each player is joining stays legible without anyone
/// having to remember it. The turn badge names the colour in words, so
/// nothing here rests on colour alone (AGENTS.md §10.1.16).
class _SidesPainter extends CustomPainter {
  const _SidesPainter({
    required this.geometry,
    required this.blueSideColor,
    required this.redSideColor,
    required this.pulse,
  });

  final _HexGeometry geometry;
  final Color blueSideColor;
  final Color redSideColor;

  /// 0 at rest, 1 at the top of the breath. Held at 0 once the game is
  /// over.
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) => _paintSides(canvas);

  /// Drawn edge by edge rather than as four straight lines, because the
  /// boundary of a hexagon grid zigzags and a straight line would cut
  /// the corners off.
  void _paintSides(Canvas canvas) {
    final baseStroke = math.max(3.0, geometry.radius * 0.26);

    Paint paintFor(HexPlayer player) {
      final base = player == HexPlayer.player1 ? blueSideColor : redSideColor;

      return Paint()
        // Deepened rather than brightened. Everything behind the stripe
        // is light -- cream board on one side, and a turn tint that is
        // itself a pale version of one of these very colours on the
        // other -- so a lighter pulse washes the stripe out at exactly
        // the moment it is meant to be loudest.
        ..color = Color.lerp(base, Colors.black, 0.32 * pulse)!
        ..style = PaintingStyle.stroke
        // A small swing: the stripe should look like it is breathing,
        // not growing.
        ..strokeWidth = baseStroke * (1 + (0.21 * pulse))
        ..strokeCap = StrokeCap.round;
    }

    for (var row = 0; row < HexGame.size; row++) {
      for (var col = 0; col < HexGame.size; col++) {
        for (var edge = 0; edge < 6; edge++) {
          final (dr, dc) = HexGame.neighbourOffsets[edge];
          if (_isOnBoard(row + dr, col + dc)) continue;

          final from = geometry.cornerOf(row, col, edge);
          final to = geometry.cornerOf(row, col, (edge + 1) % 6);

          final owner = _sideOwnerOf(row, col, edge);
          if (owner != null) {
            canvas.drawLine(from, to, paintFor(owner));
            continue;
          }

          // The one edge of a corner cell where a straight side and a
          // slanted side meet. Split it at the midpoint, the way a
          // physical board does: each half carries on the stripe it
          // touches.
          final mid = Offset.lerp(from, to, 0.5)!;
          final before = _sideOwnerOf(row, col, (edge + 5) % 6);
          final after = _sideOwnerOf(row, col, (edge + 1) % 6);
          if (before != null) canvas.drawLine(from, mid, paintFor(before));
          if (after != null) canvas.drawLine(mid, to, paintFor(after));
        }
      }
    }
  }

  /// Which player's side hexagon edge [edge] of this cell forms.
  ///
  /// `null` covers both an interior edge and the single edge of a
  /// corner cell where two differently-owned sides meet -- in each case
  /// because the neighbour across it is off the board in neither
  /// direction, or in both.
  HexPlayer? _sideOwnerOf(int row, int col, int edge) {
    final (dr, dc) = HexGame.neighbourOffsets[edge];
    final rowOff = row + dr < 0 || row + dr >= HexGame.size;
    final colOff = col + dc < 0 || col + dc >= HexGame.size;
    if (rowOff == colOff) return null;

    // Running off the side of a column means the left or right side of
    // the board, which is Blue's; off the end of a row is Red's.
    return colOff ? HexPlayer.player1 : HexPlayer.player2;
  }

  bool _isOnBoard(int row, int col) =>
      row >= 0 && row < HexGame.size && col >= 0 && col < HexGame.size;

  @override
  bool shouldRepaint(_SidesPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.blueSideColor != blueSideColor ||
      oldDelegate.redSideColor != redSideColor ||
      oldDelegate.pulse != pulse;
}

/// One stone: a filled hexagon with a soft inner bevel and a thin dark
/// outline, matching the orientation of the cell it sits in.
class _StonePainter extends CustomPainter {
  const _StonePainter({
    required this.radius,
    required this.colour,
    required this.strokeWidth,
  });

  final double radius;
  final Color colour;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final path = _hexagonPath(centre, radius);

    canvas.drawPath(path, Paint()..color = colour);

    // There is no inset shadow to reach for, so the bevel is a radial
    // gradient clipped to the same hexagon -- the softened version of
    // the trick the other boards use. Kept faint: it is there to round
    // the stone off, not to darken it.
    canvas.drawPath(
      path,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x00000000), Color(0x00000000), Color(0x22000000)],
          stops: [0.0, 0.62, 1.0],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_StonePainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.colour != colour ||
      oldDelegate.strokeWidth != strokeWidth;
}
