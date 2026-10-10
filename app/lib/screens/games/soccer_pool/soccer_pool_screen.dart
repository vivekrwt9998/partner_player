import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../data/games_registry.dart';
import '../../../games/soccer_pool/logic/soccer_pool_game.dart';
import '../../../games/soccer_pool/models/soccer_pool_models.dart';
import '../../../games/soccer_pool/presentation/soccer_pool_match_controller.dart';
import '../../../models/game_definition.dart';
import '../../../widgets/turn_indicator.dart';
import '../../game_result_screen.dart';

/// Maps between the engine's field units and screen pixels.
///
/// The engine works on a field exactly 1.0 wide and 1.58 tall, so a single
/// scale factor -- the board's pixel width -- converts both ways.
class _FieldGeometry {
  const _FieldGeometry(this.scale);

  final double scale;

  Offset toScreen(double x, double y) => Offset(x * scale, y * scale);
  Offset toField(Offset screen) => Offset(screen.dx / scale, screen.dy / scale);
  double lengthToScreen(double fieldLength) => fieldLength * scale;
}

/// Visual Specifications:
/// - Fixed portrait pitch shaped like the reference: a tall football field
///   on a coral backdrop, white frame, cream playing surface, penalty box
///   rectangle and a goal mouth with the net pattern at each end. No
///   horizontal grass stripes, no penalty arcs (per the design change).
/// - Center circle, halfway line, and small kickoff dot at centre.
/// - 5 tokens per side + 1 football. Tokens are a black ring around a
///   blue/red disc with a white star. The ball gets its own pentagon-ish
///   soccer pattern. The current player's tokens show a dashed highlight
///   ring so you can pick one up.
/// - Pick up a token of your colour and flick: the further you draw, the
///   harder the shot. A moving piece leaves a tapered comet trail.
/// - Top-left has the score chip ("0 : 0", with team-coloured dots).
///   Top-right has the standard 3-dot options menu (Restart, Exit Game).
/// - Turn indicator is the face-to-face overlay: one badge per player.
/// - Seamless transition to the standard celebratory GameResultScreen.
class SoccerPoolScreen extends StatefulWidget {
  final GameMode mode;

  const SoccerPoolScreen({
    super.key,
    this.mode = GameMode.local,
  });

  @override
  State<SoccerPoolScreen> createState() => _SoccerPoolScreenState();
}

class _SoccerPoolScreenState extends State<SoccerPoolScreen>
    with TickerProviderStateMixin {
  late final SoccerPoolMatchController _matchController;
  late final Ticker _ticker;

  /// This game's metadata, looked up once so the turn indicator layout and
  /// orientation contract are driven by configuration rather than hardcoded
  /// in this screen (AGENTS.md §10.1.6).
  static final GameDefinition _definition =
      kGames.firstWhere((g) => g.id == 'soccer_pool');

  // Color palette matching the rest of the platform's design specification.
  static const Color _bluePlayerColor = Color(0xFF00ACF8);
  static const Color _redPlayerColor = Color(0xFFFF5E57);

  // Coral backdrop matches the reference images.
  static const Color _backdropColor = Color(0xFFF4A88C);

  // A flat, friendly green pitch — no stripes, no clutter.
  static const Color _fieldColor = Color(0xFF6DBE45);

  // White frame highlight.
  static const Color _frameColor = Color(0xFFFFFFFF);

  // Goal-mouth shading, nested inside the penalty box at the goal line.
  static const Color _goalColor = Color(0xFF4E9B31);

  // Mid line + center circle + penalty box outline.
  static const Color _lineColor = Color(0xFFFFFFFF);

  // Dashed highlight around the active player's own pieces.
  static const Color _highlightColor = Color(0xFF1B1F26);

  /// Light source shared by all drop-shadows on the pitch.
  static const Offset _shadowDirection = Offset(0.28, 0.96);

  bool _isTransitioningToResult = false;
  bool _isOptionsMenuOpen = false;
  Timer? _resultTransitionTimer;

  Duration _lastTick = Duration.zero;
  bool _wasAnimating = false;

  /// Slow, continuous rotation for the dashed "this is yours" ring, purely
  /// decorative -- driven independently of the physics ticker so it keeps
  /// turning while a player is still deciding, not just while something on
  /// the pitch is moving.
  late final AnimationController _highlightController;

  /// The piece the player has picked up. It never actually moves off its
  /// own spot while held -- only [_dragFieldPoint] moves, so a shot pulls
  /// back like a real elastic band rather than letting the piece be
  /// dragged anywhere on the pitch.
  SoccerPoolPiece? _heldPiece;

  /// Where [_heldPiece] was resting when it was picked up. The shot fires
  /// from here, in the opposite direction the piece was pulled toward.
  SoccerPoolVector? _heldOrigin;

  /// The finger's current position, in field units, while a piece is held.
  Offset? _dragFieldPoint;

  /// Most recent pointer id that started the current drag, so we can match
  /// the matching up/cancel cleanly even if the pointer count grows.
  int? _activePointer;

  @override
  void initState() {
    super.initState();
    _matchController = SoccerPoolMatchController(mode: widget.mode)
      ..addListener(_onMatchStateChanged);
    _ticker = createTicker(_onTick);
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _resultTransitionTimer?.cancel();
    _ticker.dispose();
    _highlightController.dispose();
    _matchController
      ..removeListener(_onMatchStateChanged)
      ..dispose();
    super.dispose();
  }

  // ── Touch handling ────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent event, _FieldGeometry geometry) {
    if (_isTransitioningToResult || _isOptionsMenuOpen) return;
    if (!_matchController.canAcceptLocalInput) return;

    final game = _matchController.game;
    final point = geometry.toField(event.localPosition);

    final piece = _pieceUnder(point, game.currentPlayer);
    if (piece == null) return;

    _heldPiece = piece;
    _heldOrigin = piece.position;
    _dragFieldPoint = point;
    _activePointer = event.pointer;
    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent event, _FieldGeometry geometry) {
    if (_heldPiece == null) return;
    _dragFieldPoint = geometry.toField(event.localPosition);
    setState(() {});
  }

  void _onPointerUp(int pointer, _FieldGeometry geometry) {
    if (_activePointer != pointer) return;
    final piece = _heldPiece;
    final origin = _heldOrigin;
    final dragPoint = _dragFieldPoint;
    _heldPiece = null;
    _heldOrigin = null;
    _dragFieldPoint = null;
    _activePointer = null;
    if (piece == null || origin == null || dragPoint == null) {
      setState(() {});
      return;
    }

    // Slingshot feel, exactly like Sling Puck's band: pull the piece back
    // away from where you want it to go and let go -- it fires the
    // *opposite* way. The piece itself never left its own spot while aiming.
    //
    // Scaled so a draw of about half the pitch width is a full-power shot:
    // shorter pulls stay proportionally gentler, which is the whole point
    // of aiming by how far you drag.
    const powerScale = 4.5;
    final pull = SoccerPoolVector(origin.x - dragPoint.dx, origin.y - dragPoint.dy);
    final launched = _matchController.tryShoot(piece.id, pull.scale(powerScale));
    setState(() {});
    if (launched) _ensureTicking();
  }

  /// The nearest piece belonging to [player] close enough to count as a
  /// touch on it.
  SoccerPoolPiece? _pieceUnder(Offset point, SoccerPoolPlayer player) {
    final hitRadius = SoccerPoolGame.tokenRadius * 1.6;
    SoccerPoolPiece? best;
    var bestDistanceSq = hitRadius * hitRadius;
    for (final piece in _matchController.game.pieces) {
      if (piece.isBall || piece.owner != player) continue;
      final dx = piece.position.x - point.dx;
      final dy = piece.position.y - point.dy;
      final distanceSq = (dx * dx) + (dy * dy);
      if (distanceSq <= bestDistanceSq) {
        bestDistanceSq = distanceSq;
        best = piece;
      }
    }
    return best;
  }

  // ── Tick / lifecycle ──────────────────────────────────────────────────

  void _ensureTicking() {
    if (_ticker.isActive) return;
    _lastTick = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    if (!mounted || dt <= 0) return;

    _matchController.advance(dt);
    final game = _matchController.game;

    final isAnimating = game.isMoving;
    if (isAnimating || _wasAnimating) {
      _wasAnimating = isAnimating;
      setState(() {});
    }
    if (!isAnimating) _ticker.stop();
  }

  void _onMatchStateChanged() {
    if (!mounted) return;
    if (_matchController.game.isGameOver) {
      _scheduleResultTransition();
    }
    setState(() {});
  }

  void _restartGame() {
    _resultTransitionTimer?.cancel();
    _resultTransitionTimer = null;
    _heldPiece = null;
    _heldOrigin = null;
    _dragFieldPoint = null;
    _activePointer = null;
    _matchController.restart();
    setState(() => _isTransitioningToResult = false);
    _ensureTicking();
  }

  void _exitGame() => Navigator.of(context).pop();

  void _navigateToResultScreen() {
    final game = _matchController.game;
    final isBlueWinner = game.winner == SoccerPoolPlayer.player1;

    GameResultScreen.show(
      context,
      resultData: isBlueWinner
          ? GameResultData.blueWin(label: 'BLUE PLAYER\nWINS!')
          : GameResultData.redWin(label: 'RED PLAYER\nWINS!'),
      onPlayAgain: _restartGame,
      onExit: _exitGame,
    );
  }

  void _scheduleResultTransition() {
    if (_isTransitioningToResult) return;
    _heldPiece = null;
    _heldOrigin = null;
    _dragFieldPoint = null;
    _activePointer = null;
    setState(() => _isTransitioningToResult = true);
    _resultTransitionTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted && _isTransitioningToResult) _navigateToResultScreen();
    });
  }

  // ── Composition ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final gameBody = switch (_definition.orientationBehavior) {
      GameOrientationBehavior.fixedPortrait => _buildFixedPortraitComposition(),
      GameOrientationBehavior.fixedLandscape ||
      GameOrientationBehavior.adaptive =>
        throw UnsupportedError(
          'SoccerPoolScreen only implements '
          'GameOrientationBehavior.fixedPortrait, but soccer_pool is '
          'declared as ${_definition.orientationBehavior}.',
        ),
    };

    return PopScope(canPop: true, child: Scaffold(body: gameBody));
  }

  Widget _buildFixedPortraitComposition() {
    final game = _matchController.game;

    return Container(
      color: _backdropColor,
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              // Symmetric top/bottom clearance so the face-to-face turn
              // badge (whichever player's turn it is) never sits on top of
              // that end's goal box -- it was swallowing it whole before.
              padding: const EdgeInsets.fromLTRB(16, 88, 16, 88),
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // The white frame is drawn as a border, which eats into
                    // the box it is on. Size the *playing surface* to the
                    // engine's 1 : 1.58 and add the frame around it -- do it
                    // the other way round and the surface ends up shorter
                    // than 1.58, which pushed the bottom goal and penalty
                    // box off the goal line while the top pair stayed flush.
                    const ratio = SoccerPoolGame.fieldHeight /
                        SoccerPoolGame.fieldWidth;
                    const frame = _frameWidth * 2;
                    var pitchWidth = constraints.maxWidth - frame;
                    var pitchHeight = pitchWidth * ratio;
                    if (pitchHeight > constraints.maxHeight - frame) {
                      pitchHeight = constraints.maxHeight - frame;
                      pitchWidth = pitchHeight / ratio;
                    }
                    return SizedBox(
                      key: const ValueKey('soccer_pool_board'),
                      width: pitchWidth + frame,
                      height: pitchHeight + frame,
                      child: _buildField(),
                    );
                  },
                ),
              ),
            ),
            // Score chip, top-left. Always visible so you can see where the
            // match stands at a glance.
            Positioned(top: 12, left: 16, child: _buildScoreChip(game)),
            // 3-dot options menu (Restart, Exit Game).
            Positioned(top: 8, right: 14, child: _buildOptionsButton()),
            if (_isOptionsMenuOpen) ...[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _isOptionsMenuOpen = false),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(top: 50, right: 14, child: _buildOptionsMenuPanel()),
            ],
            // Face-to-face turn indicators driven by configuration
            // (AGENTS.md §10.1.4 / §10.1.6).
            Positioned.fill(
              child: TurnIndicatorOverlay(
                layout: _definition.turnIndicatorLayout,
                first: TurnIndicatorSpec(
                  color: _bluePlayerColor,
                  label: 'BLUE',
                  isActive: game.currentPlayer == SoccerPoolPlayer.player1,
                ),
                second: TurnIndicatorSpec(
                  color: _redPlayerColor,
                  label: 'RED',
                  isActive: game.currentPlayer == SoccerPoolPlayer.player2,
                ),
                isGameOver: game.isGameOver,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreChip(SoccerPoolGame game) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: _redPlayerColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${game.redScore}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Color(0xFF1B1F26),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            ':',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Color(0xFF1B1F26),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${game.blueScore}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Color(0xFF1B1F26),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: _bluePlayerColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
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
          color: Colors.black.withValues(alpha: 0.55),
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
            _buildOptionsMenuItem(
              icon: Icons.refresh_rounded,
              label: 'Restart',
              onTap: () => select(_restartGame),
            ),
            _buildOptionsMenuItem(
              icon: Icons.logout_rounded,
              label: 'Exit Game',
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
    required VoidCallback onTap,
  }) {
    const color = Colors.black87;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ── Field ──────────────────────────────────────────────────────────────

  static const double _frameWidth = 9;
  static const double _frameRadius = 18;

  Widget _buildField() {
    return Container(
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(_frameRadius),
        border: Border.all(color: _frameColor, width: _frameWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 0,
            offset: _shadowDirection * 6,
          ),
        ],
      ),
      child: ClipRRect(
        // The playing surface itself, inside the frame: exactly the
        // engine's 1 x 1.58 field, which is what maps to field units.
        key: const ValueKey('soccer_pool_pitch'),
        borderRadius: BorderRadius.circular(_frameRadius - _frameWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final geometry = _FieldGeometry(constraints.biggest.width);
            final game = _matchController.game;

            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) => _onPointerDown(e, geometry),
              onPointerMove: (e) => _onPointerMove(e, geometry),
              onPointerUp: (e) => _onPointerUp(e.pointer, geometry),
              onPointerCancel: (e) => _onPointerUp(e.pointer, geometry),
              child: Stack(
                children: [
                  Positioned.fill(
                    key: const ValueKey('soccer_pool_field'),
                    child: AnimatedBuilder(
                      animation: _highlightController,
                      builder: (context, _) => CustomPaint(
                        painter: _FieldPainter(
                          game: game,
                          fieldColor: _fieldColor,
                          lineColor: _lineColor,
                          goalColor: _goalColor,
                          highlightColor: _highlightColor,
                          blue: _bluePlayerColor,
                          red: _redPlayerColor,
                          heldPieceId: _heldPiece?.id,
                          heldOrigin: _heldOrigin,
                          dragFieldPoint: _dragFieldPoint,
                          highlightRotation: _highlightController.value,
                        ),
                      ),
                    ),
                  ),
                  for (final piece in game.pieces) _buildPiece(piece, geometry),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPiece(SoccerPoolPiece piece, _FieldGeometry geometry) {
    final centre = geometry.toScreen(piece.position.x, piece.position.y);
    final radius = piece.isBall
        ? geometry.lengthToScreen(SoccerPoolGame.ballRadius)
        : geometry.lengthToScreen(SoccerPoolGame.tokenRadius);

    if (piece.isBall) {
      return Positioned(
        key: ValueKey('soccer_pool_ball'),
        left: centre.dx - radius,
        top: centre.dy - radius,
        width: radius * 2,
        height: radius * 2,
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black87, width: radius * 0.16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 0,
                  offset: _shadowDirection * radius * 0.22,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _BallPainter())),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: const [
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0x30000000),
                          Color(0x30000000),
                        ],
                        stops: const [0.0, 0.70, 0.70, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final colour = piece.owner == SoccerPoolPlayer.player1
        ? _bluePlayerColor
        : _redPlayerColor;
    final isHeld = piece == _heldPiece;

    return Positioned(
      key: ValueKey('soccer_pool_${piece.id}'),
      left: centre.dx - radius,
      top: centre.dy - radius,
      width: radius * 2,
      height: radius * 2,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: colour,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black87, width: radius * 0.13),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isHeld ? 0.45 : 0.38),
                blurRadius: 0,
                offset: _shadowDirection * radius * (isHeld ? 0.34 : 0.19),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _StarPainter())),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: const [
                        Color(0x00000000),
                        Color(0x00000000),
                        Color(0x30000000),
                        Color(0x30000000),
                      ],
                      stops: const [0.0, 0.70, 0.70, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A five-pointed star in the middle of a piece, painted in white at low
/// alpha so it reads as a lighter tint of whichever team colour is
/// underneath it.
class _StarPainter extends CustomPainter {
  const _StarPainter();

  static const int _points = 5;
  static const double _outerFraction = 0.30;
  static const double _innerFraction = 0.46;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final outer = size.width * _outerFraction;
    final inner = outer * _innerFraction;

    final path = Path();
    for (var i = 0; i < _points * 2; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = (i * math.pi / _points) - (math.pi / 2);
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
    path.close();

    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.32));
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) => false;
}

/// A small soccer-ball pattern — a dark central pentagon + a few sketchy
/// seam lines. Light enough to read on a small disc without crushing the
/// black rim.
class _BallPainter extends CustomPainter {
  const _BallPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.18;
    final stroke = Paint()
      ..color = Colors.black87
      ..strokeWidth = size.width * 0.04
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = Colors.black87;

    // Central pentagon.
    final pentagon = Path();
    for (var i = 0; i < 5; i++) {
      final angle = (i * math.pi * 2 / 5) - (math.pi / 2);
      final point = Offset(
        centre.dx + (radius * math.cos(angle)),
        centre.dy + (radius * math.sin(angle)),
      );
      if (i == 0) {
        pentagon.moveTo(point.dx, point.dy);
      } else {
        pentagon.lineTo(point.dx, point.dy);
      }
    }
    pentagon.close();
    canvas.drawPath(pentagon, fill);

    // Five short seams out of each pentagon vertex, pointing outward.
    for (var i = 0; i < 5; i++) {
      final angle = (i * math.pi * 2 / 5) - (math.pi / 2);
      final from = Offset(
        centre.dx + (radius * math.cos(angle)),
        centre.dy + (radius * math.sin(angle)),
      );
      final to = Offset(
        centre.dx + (radius * 1.6 * math.cos(angle)),
        centre.dy + (radius * 1.6 * math.sin(angle)),
      );
      canvas.drawLine(from, to, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _BallPainter oldDelegate) => false;
}

/// Draws the pitch itself: frame inner outline, pitch markings (mid line,
/// centre circle, a penalty box at each end with its goal net nested
/// inside -- no horizontal stripes, keeping the flat look), the dashed
/// highlight around the active player's own tokens, the current pull-back
/// while a piece is being aimed, and the comet trails.
class _FieldPainter extends CustomPainter {
  _FieldPainter({
    required this.game,
    required this.fieldColor,
    required this.lineColor,
    required this.goalColor,
    required this.highlightColor,
    required this.blue,
    required this.red,
    required this.highlightRotation,
    this.heldPieceId,
    this.heldOrigin,
    this.dragFieldPoint,
  });

  final SoccerPoolGame game;
  final Color fieldColor;
  final Color lineColor;
  final Color goalColor;
  final Color highlightColor;
  final Color blue;
  final Color red;

  /// 0..1, driving the slow continuous spin of the "this is yours" ring.
  final double highlightRotation;

  /// The piece the player is currently pulling back. The trail painter
  /// skips this piece so the comet doesn't flash behind a piece that
  /// hasn't actually launched yet.
  final int? heldPieceId;

  /// Where [heldPieceId] is resting (it never moves while held), and where
  /// the finger currently is, both in field units. Together they draw the
  /// pull-back band, mirroring Sling Puck's elastic.
  final SoccerPoolVector? heldOrigin;
  final Offset? dragFieldPoint;

  /// How deep the penalty box reaches in from its own goal line.
  static const double _boxHeightFraction = 0.18;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;

    _paintMidLine(canvas, s);
    _paintCenterCircle(canvas, s);
    _paintCenterSpot(canvas, s);
    _paintPenaltyBox(canvas, s, true); // top
    _paintPenaltyBox(canvas, s, false); // bottom
    _paintGoalBox(canvas, s, true);
    _paintGoalBox(canvas, s, false);
    _paintHighlights(canvas, s);
    _paintPullBack(canvas, s);
    _paintTrails(canvas, s);
  }

  void _paintMidLine(Canvas canvas, double s) {
    final y = (SoccerPoolGame.fieldHeight / 2) * s;
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = s * 0.006
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, y), Offset(s, y), paint);
  }

  void _paintCenterCircle(Canvas canvas, double s) {
    final centre = Offset(s / 2, (SoccerPoolGame.fieldHeight / 2) * s);
    final radius = s * 0.16;
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = s * 0.008
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(centre, radius, paint);
  }

  void _paintCenterSpot(Canvas canvas, double s) {
    final centre = Offset(s / 2, (SoccerPoolGame.fieldHeight / 2) * s);
    canvas.drawCircle(
      centre,
      s * 0.012,
      Paint()..color = lineColor,
    );
  }

  void _paintPenaltyBox(Canvas canvas, double s, bool isTop) {
    final boxWidth = s * 0.62;
    final boxHeight = s * _boxHeightFraction;
    final left = (s - boxWidth) / 2;
    final top = isTop ? 0.0 : (SoccerPoolGame.fieldHeight * s) - boxHeight;
    final rect = Rect.fromLTWH(left, top, boxWidth, boxHeight);
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = s * 0.008
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, paint);
  }

  /// The goal mouth, nested just inside the penalty box at the goal line
  /// itself -- a shaded, cross-hatched rectangle reading as the net.
  void _paintGoalBox(Canvas canvas, double s, bool isTop) {
    final goalWidth = SoccerPoolGame.goalWidth * s;
    final goalDepth = s * 0.085;
    final left = (s - goalWidth) / 2;
    final top = isTop ? 0.0 : (SoccerPoolGame.fieldHeight * s) - goalDepth;
    final rect = Rect.fromLTWH(left, top, goalWidth, goalDepth);

    canvas.drawRect(rect, Paint()..color = goalColor);

    // Cross-hatch so it reads as a net, not as a flat panel.
    final hatch = Paint()
      ..color = lineColor.withValues(alpha: 0.55)
      ..strokeWidth = s * 0.004;
    const hatchRows = 3;
    final rowStep = goalDepth / hatchRows;
    for (var i = 1; i < hatchRows; i++) {
      final y = top + (rowStep * i);
      canvas.drawLine(Offset(left, y), Offset(left + goalWidth, y), hatch);
    }
    const hatchCols = 6;
    final colStep = goalWidth / hatchCols;
    for (var i = 1; i < hatchCols; i++) {
      final x = left + (colStep * i);
      canvas.drawLine(Offset(x, top), Offset(x, top + goalDepth), hatch);
    }

    canvas.drawRect(
      rect,
      Paint()
        ..color = lineColor
        ..strokeWidth = s * 0.008
        ..style = PaintingStyle.stroke,
    );
  }

  /// Dashed circles around the current player's own tokens, so the player
  /// can see at a glance which ones they may pick up. Slowly rotates so it
  /// reads as a live "this one's yours" cue rather than a static ring.
  void _paintHighlights(Canvas canvas, double s) {
    if (game.isGameOver) return;
    final current = game.currentPlayer;
    // Both terms in pixels: the token's own radius is in field units and
    // has to be scaled, the gap around it is already a pixel figure.
    // Adding them before scaling made the ring grow with the square of the
    // board and land far off-canvas, so it was never actually seen.
    final radius = (SoccerPoolGame.tokenRadius * s) + (s * 0.022);
    final paint = Paint()
      ..color = highlightColor
      ..strokeWidth = s * 0.010
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final piece in game.pieces) {
      if (piece.isBall || piece.owner != current) continue;
      _drawDashedCircle(
        canvas,
        Offset(piece.position.x * s, piece.position.y * s),
        radius,
        paint,
      );
    }
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset centre,
    double radius,
    Paint paint,
  ) {
    const dashCount = 18;
    const dashFraction = 0.55; // fraction of each segment that's drawn
    final rect = Rect.fromCircle(center: centre, radius: radius);
    final sweep = 2 * math.pi / dashCount;
    final rotation = highlightRotation * 2 * math.pi;
    for (var i = 0; i < dashCount; i++) {
      final start = -math.pi / 2 + (i * sweep) + rotation;
      final end = start + (sweep * dashFraction);
      canvas.drawArc(rect, start, end - start, false, paint);
    }
  }

  /// The pull-back band while a piece is being aimed: a single elastic
  /// line from the piece's own (unmoving) spot to wherever the finger
  /// currently is, so pulling back visibly loads the shot -- matching
  /// Sling Puck's slingshot feel.
  void _paintPullBack(Canvas canvas, double s) {
    final origin = heldOrigin;
    final drag = dragFieldPoint;
    final id = heldPieceId;
    if (origin == null || drag == null || id == null) return;

    SoccerPoolPiece? piece;
    for (final candidate in game.pieces) {
      if (candidate.id == id) {
        piece = candidate;
        break;
      }
    }
    if (piece == null) return;

    final from = Offset(origin.x * s, origin.y * s);
    final to = Offset(drag.dx * s, drag.dy * s);
    final colour = piece.owner == SoccerPoolPlayer.player1 ? blue : red;

    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = colour.withValues(alpha: 0.8)
        ..strokeWidth = s * 0.012
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(to, s * 0.022, Paint()..color = colour.withValues(alpha: 0.85));
  }

  /// Tapered comet trail behind any piece moving fast enough to read as
  /// a flick. Wide at the piece, pointed at the tail, fading out.
  void _paintTrails(Canvas canvas, double s) {
    for (final piece in game.pieces) {
      if (heldPieceId != null && piece.id == heldPieceId) continue;
      final speed = piece.velocity.length;
      if (speed < 0.12) continue;

      final r = piece.isBall
          ? SoccerPoolGame.ballRadius
          : SoccerPoolGame.tokenRadius;
      final dirX = piece.velocity.x / speed;
      final dirY = piece.velocity.y / speed;
      final length = math.min(speed * 0.55, r * 4);
      final halfWidth = r * 0.55;

      final head = Offset(piece.position.x * s, piece.position.y * s);
      final tail = Offset(
        (piece.position.x - (dirX * length)) * s,
        (piece.position.y - (dirY * length)) * s,
      );
      final sideX = -dirY * halfWidth * s;
      final sideY = dirX * halfWidth * s;

      final colour = piece.isBall
          ? Colors.white
          : (piece.owner == SoccerPoolPlayer.player1 ? blue : red);
      canvas.drawPath(
        Path()
          ..moveTo(head.dx + sideX, head.dy + sideY)
          ..lineTo(tail.dx, tail.dy)
          ..lineTo(head.dx - sideX, head.dy - sideY)
          ..close(),
        Paint()
          ..shader = ui.Gradient.linear(
            head,
            tail,
            [colour.withValues(alpha: 0.7), colour.withValues(alpha: 0)],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FieldPainter oldDelegate) => true;
}