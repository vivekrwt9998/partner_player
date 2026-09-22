import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../data/games_registry.dart';
import '../../../models/game_definition.dart';
import '../../../games/sling_puck/bot/simple_sling_puck_bot_strategy.dart';
import '../../../games/sling_puck/logic/game_tuning.dart';
import '../../../games/sling_puck/logic/sling_puck_game.dart';
import '../../../games/sling_puck/models/sling_puck_models.dart';
import '../../../games/sling_puck/presentation/sling_puck_match_controller.dart';
import '../../../widgets/turn_indicator.dart';
import '../../game_result_screen.dart';

/// Maps between the engine's field units and screen pixels.
///
/// The engine works on a field exactly 1.0 wide and 2.0 tall, so a single
/// scale factor -- the board's pixel width -- converts both ways.
class _FieldGeometry {
  const _FieldGeometry(this.scale);

  final double scale;

  Offset toScreen(double x, double y) => Offset(x * scale, y * scale);
  Offset toField(Offset screen) => Offset(screen.dx / scale, screen.dy / scale);
  double lengthToScreen(double fieldLength) => fieldLength * scale;
}

/// One finger currently carrying a piece.
class _PointerGrab {
  _PointerGrab({
    required this.player,
    required this.grabOffset,
    required this.velocity,
  });

  final SlingPuckPlayer player;

  /// Piece centre minus finger position when it was picked up, re-applied
  /// on every move so the piece never jumps under the finger.
  final Offset grabOffset;

  /// Accumulates the gesture so the release can flick the piece.
  final VelocityTracker velocity;
}

/// Visual Specifications:
/// - A 1:2 portrait field, split by a divider with a narrow goal gap, and a
///   fixed elastic band stretched between two posts at each end
/// - Both players play at once, so there is no turn indicator and no turn
///   background (AGENTS.md §10.1.3, via TurnIndicatorLayout.simultaneous),
///   and no running score either: what is left on your half is right there
///   on the board to look at
/// - 3-dot options menu (Restart, Exit Game, Debug overlay). No Revert:
///   nothing here happens in discrete moves to undo
/// - Pick a piece up and carry it, then flick to throw. A piece driven into
///   a band stretches it and is catapulted straight back off it
/// - Pieces bounce off the walls, the bars and each other, and a fast one
///   trails a tapered comet
/// - Seamless transition to full-screen celebratory GameResultScreen
class SlingPuckScreen extends StatefulWidget {
  final GameMode mode;

  const SlingPuckScreen({
    super.key,
    this.mode = GameMode.local,
  });

  @override
  State<SlingPuckScreen> createState() => _SlingPuckScreenState();
}

class _SlingPuckScreenState extends State<SlingPuckScreen>
    with TickerProviderStateMixin {
  late final SlingPuckMatchController _matchController;
  late final Ticker _ticker;

  /// This game's metadata, looked up once so the turn indicator layout and
  /// orientation contract are driven by configuration rather than hardcoded
  /// in this screen (AGENTS.md §10.1.6).
  static final GameDefinition _definition =
      kGames.firstWhere((g) => g.id == 'sling_puck');

  // Color Palette matching the rest of the platform's design specification.
  static const Color _bluePlayerColor = Color(0xFF00ACF8); // Blue Player
  static const Color _redPlayerColor = Color(0xFFFF5E57); // Red Player
  static const Color _boardColor = Color(0xFF232A33); // Frame / bars
  static const Color _fieldColor = Color(0xFFF2E9DC); // Playing surface
  static const Color _gateColor = Color(0xFFFFC93C); // The gate, once shut

  // Behind the field. A gradient rather than one flat slab: the frame used
  // to be within a shade of the backdrop and the two read as one mass, so
  // the board never looked like an object sitting on something.
  static const Color _backdropTop = Color(0xFF55637A);
  static const Color _backdropBottom = Color(0xFF2B323C);

  /// One light source for the whole board: down and a touch to the right.
  static const Offset _shadowDirection = Offset(0.28, 0.96);

  /// Measured from the reference recording.
  static const Color _bandColor = Color(0xFF50515A);

  bool _isTransitioningToResult = false;
  bool _isOptionsMenuOpen = false;
  bool _showDebug = false;
  Timer? _resultTransitionTimer;

  Duration _lastTick = Duration.zero;
  bool _wasAnimating = false;

  /// How far the gate's two panels have slid in, 0 to 1. Driven from the
  /// ticker rather than its own controller, since the ticker is already
  /// running whenever this can change.
  double _gateProgress = 0;

  /// How long the gate takes to slide shut, in seconds.
  static const double _gateCloseSeconds = 0.28;

  final Map<int, _PointerGrab> _pointers = {};

  GameTuning get _tuning => _matchController.game.tuning;

  @override
  void initState() {
    super.initState();
    _matchController = SlingPuckMatchController(mode: widget.mode)
      ..addListener(_onMatchStateChanged);
    _ticker = createTicker(_onTick);
    // The bot moves its hand whether or not anything on the board is, so
    // in a Bot match the clock has to be running from the start.
    if (_matchController.isBotMatch) _ensureTicking();
  }

  @override
  void dispose() {
    _resultTransitionTimer?.cancel();
    _ticker.dispose();
    _matchController
      ..removeListener(_onMatchStateChanged)
      ..dispose();
    super.dispose();
  }

  /// Starts the simulation clock if it isn't already running.
  ///
  /// The ticker only runs while something is moving, being carried or
  /// springing back, so a field at rest costs nothing -- and a test can
  /// still settle the frame pipeline instead of pumping forever.
  void _ensureTicking() {
    if (_ticker.isActive) return;
    _lastTick = Duration.zero;
    _ticker.start();
  }

  /// Feeds real time into the fixed-step solver, then parks itself once the
  /// field is still.
  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    if (!mounted || dt <= 0) return;

    _matchController.advance(dt);

    final game = _matchController.game;

    if (game.isGateClosed) {
      if (_gateProgress < 1) {
        _gateProgress =
            (_gateProgress + (dt / _gateCloseSeconds)).clamp(0.0, 1.0);
      }
    } else {
      _gateProgress = 0;
    }

    final isAnimating = game.pieces.any((p) => p.isMoving || p.isHeld) ||
        game.topBand.phase != BandPhase.idle ||
        game.bottomBand.phase != BandPhase.idle ||
        (game.isGateClosed && _gateProgress < 1) ||
        (_matchController.isBotMatch && !game.isGameOver);

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

  // ── Touch handling (both players at once) ──────────────────────────────

  void _onPointerDown(PointerDownEvent event, _FieldGeometry geometry) {
    if (_isTransitioningToResult || _isOptionsMenuOpen) return;

    // Forget any finger we never saw lift. Without this, one missed
    // pointer-up would lock that player out for the rest of the match.
    _pointers.removeWhere(
      (_, grab) => _matchController.game.heldPieceOf(grab.player) == null,
    );

    final point = geometry.toField(event.localPosition);
    final player = point.dy > _tuning.barCentreY
        ? SlingPuckPlayer.player1
        : SlingPuckPlayer.player2;

    // In a Bot match the far half is the bot's; a finger there does
    // nothing.
    if (!_matchController.canControl(player)) return;

    // One hand each: a second finger on the same half is ignored rather
    // than stealing the piece already in play.
    if (_pointers.values.any((g) => g.player == player)) return;

    final piece = _pieceUnder(point, player);
    if (piece == null) return;
    if (!_matchController.grab(piece.id, player)) return;

    final tracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.localPosition);

    setState(() {
      _pointers[event.pointer] = _PointerGrab(
        player: player,
        grabOffset: Offset(piece.x - point.dx, piece.y - point.dy),
        velocity: tracker,
      );
    });
    _ensureTicking();
  }

  void _onPointerMove(PointerMoveEvent event, _FieldGeometry geometry) {
    final grab = _pointers[event.pointer];
    if (grab == null) return;

    grab.velocity.addPosition(event.timeStamp, event.localPosition);

    final point = geometry.toField(event.localPosition);
    _matchController.moveHeld(
      grab.player,
      point.dx + grab.grabOffset.dx,
      point.dy + grab.grabOffset.dy,
    );
    setState(() {});
    _ensureTicking();
  }

  /// Lets go, flicking the piece with whatever speed the gesture had.
  void _onPointerUp(int pointer, _FieldGeometry geometry) {
    final grab = _pointers.remove(pointer);
    if (grab == null) return;

    final pixels = grab.velocity.getVelocity().pixelsPerSecond;
    _matchController.release(
      grab.player,
      vx: pixels.dx / geometry.scale,
      vy: pixels.dy / geometry.scale,
    );
    setState(() {});
    _ensureTicking();
  }

  /// The nearest piece to [point] on [player]'s half close enough to count
  /// as a touch on it.
  Piece? _pieceUnder(Offset point, SlingPuckPlayer player) {
    final hitRadius = _tuning.pieceRadius * 1.5;
    Piece? best;
    var bestDistanceSq = hitRadius * hitRadius;

    for (final piece in _matchController.game.pieces) {
      if (piece.isHeld || _matchController.game.sideOf(piece) != player) {
        continue;
      }
      final dx = piece.x - point.dx;
      final dy = piece.y - point.dy;
      final distanceSq = (dx * dx) + (dy * dy);
      if (distanceSq <= bestDistanceSq) {
        bestDistanceSq = distanceSq;
        best = piece;
      }
    }
    return best;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────

  void _restartGame() {
    _resultTransitionTimer?.cancel();
    _resultTransitionTimer = null;
    _pointers.clear();
    _gateProgress = 0;
    _matchController.restart();
    setState(() => _isTransitioningToResult = false);
    _ensureTicking();
  }

  void _exitGame() => Navigator.of(context).pop();

  void _navigateToResultScreen() {
    final game = _matchController.game;
    final isBlueWinner = game.winner == SlingPuckPlayer.player1;

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

    _pointers.clear();
    setState(() => _isTransitioningToResult = true);
    _resultTransitionTimer = Timer(const Duration(milliseconds: 700), () {
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
          'SlingPuckScreen only implements '
          'GameOrientationBehavior.fixedPortrait, but sling_puck is '
          'declared as ${_definition.orientationBehavior}.',
        ),
    };

    return PopScope(canPop: true, child: Scaffold(body: gameBody));
  }

  Widget _buildFixedPortraitComposition() {
    final game = _matchController.game;

    return Container(
      // No turn background: with both players going at once there is no
      // turn to colour the screen with.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_backdropTop, _backdropBottom],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 52, 16, 20),
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const aspect = GameTuning.fieldWidth / GameTuning.fieldHeight;
                    var height = constraints.maxHeight;
                    var width = height * aspect;
                    if (width > constraints.maxWidth) {
                      width = constraints.maxWidth;
                      height = width / aspect;
                    }
                    return SizedBox(
                      key: const ValueKey('sling_puck_board'),
                      width: width,
                      height: height,
                      child: _buildField(),
                    );
                  },
                ),
              ),
            ),
            // Declared in metadata and honoured here even though it renders
            // nothing, so this screen stays driven by configuration rather
            // than quietly opting out (AGENTS.md §10.1.6).
            Positioned.fill(
              child: TurnIndicatorOverlay(
                layout: _definition.turnIndicatorLayout,
                first: const TurnIndicatorSpec(
                  color: _bluePlayerColor,
                  label: 'BLUE',
                  isActive: true,
                ),
                second: const TurnIndicatorSpec(
                  color: _redPlayerColor,
                  label: 'RED',
                  isActive: true,
                ),
                isGameOver: game.isGameOver,
              ),
            ),

            if (_showDebug)
              Positioned(
                left: 8,
                right: 8,
                bottom: 40,
                child: _TuningPanel(
                  tuning: _tuning,
                  onChanged: (value) {
                    _matchController.applyTuning(value);
                    setState(() {});
                  },
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
              Positioned(top: 50, right: 14, child: _buildOptionsMenuPanel()),
            ],

            Positioned(top: 8, right: 14, child: _buildOptionsButton()),
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
        child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  /// Restart, Exit Game and the debug toggle.
  ///
  /// No Revert: play here is continuous rather than a sequence of discrete
  /// moves, so there is no "last move" to take back.
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
              icon: _showDebug
                  ? Icons.bug_report_rounded
                  : Icons.bug_report_outlined,
              label: _showDebug ? 'Hide debug' : 'Debug overlay',
              onTap: () => select(() => setState(() => _showDebug = !_showDebug)),
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

  /// How thick the board's frame is, and how round its corners are.
  ///
  /// The rounding is given to the decoration itself rather than to an outer
  /// clip, so the *inside* edge of the frame is curved too -- clipping from
  /// outside leaves the playing surface square-cornered inside a rounded
  /// frame, which is what it used to look like.
  static const double _frameWidth = 9;
  static const double _frameRadius = 24;

  /// The playing field: frame, divider, both bands, trails and pieces.
  Widget _buildField() {
    return Container(
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(_frameRadius),
        border: Border.all(color: _boardColor, width: _frameWidth),
        // Lit from the same place as the pieces, and hard-edged like them,
        // so the whole board reads as one flat object on the backdrop.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.36),
            blurRadius: 0,
            offset: _shadowDirection * 7,
          ),
        ],
      ),
      // The border auto-insets the child, so the clip only has to account
      // for what is left of the radius on the inside of the frame.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_frameRadius - _frameWidth),
        // Measured *inside* the bordered Container, so this scale matches
        // the coordinate frame the pointer events are reported in.
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
                    key: const ValueKey('sling_puck_field'),
                    child: CustomPaint(
                      painter: _FieldPainter(
                        game: game,
                        tuning: _tuning,
                        blue: _bluePlayerColor,
                        red: _redPlayerColor,
                        bar: _boardColor,
                        gate: _gateColor,
                        band: _bandColor,
                        gateProgress: _gateProgress,
                      ),
                    ),
                  ),
                  // Pieces stay real widgets so each one keeps a key that
                  // tests (and the debug readout) can find it by.
                  for (final piece in game.pieces) _buildPiece(piece, geometry),
                  if (_showDebug)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _DebugPainter(
                            game: game,
                            tuning: _tuning,
                            bot: _matchController.botStrategy,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPiece(Piece piece, _FieldGeometry geometry) {
    final centre = geometry.toScreen(piece.x, piece.y);
    final radius = geometry.lengthToScreen(_tuning.pieceRadius);
    final colour =
        piece.owner == SlingPuckPlayer.player1 ? _bluePlayerColor : _redPlayerColor;

    return Positioned(
      key: ValueKey('sling_puck_${piece.id}'),
      left: centre.dx - radius,
      top: centre.dy - radius,
      width: radius * 2,
      height: radius * 2,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: colour,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black87, width: radius * 0.126),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: piece.isHeld ? 0.45 : 0.38),
                // Hard-edged on purpose: no blur, so it reads as a crisp
                // cut-out rather than a soft glow. Offset is scaled off the
                // radius and off one shared direction, so every piece is
                // lit from the same place and a piece being carried only
                // sits *higher* -- it never casts at a different angle.
                blurRadius: 0,
                offset: _shadowDirection * radius * (piece.isHeld ? 0.34 : 0.19),
              ),
            ],
          ),
          child: const Stack(
            children: [
              // The star sits on the bare colour...
              Positioned.fill(child: CustomPaint(painter: _StarPainter())),
              // ...and the inner shading goes over the top of it. The two
              // repeated stops make the colour change instantly instead of
              // ramping, so this is a crisp dark ring inside the rim, not
              // a soft vignette. (BoxDecoration has no inset shadow, hence
              // doing it with a gradient at all.)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0x00000000),
                        Color(0x00000000),
                        Color(0x30000000),
                        Color(0x30000000),
                      ],
                      stops: [0.0, 0.70, 0.70, 1.0],
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

/// A five-pointed star in the middle of a piece.
///
/// Painted in white at low alpha rather than a fixed colour, so it reads as
/// a lighter tint of whichever team colour is underneath it, and sits
/// inside the clear middle of the dished shading drawn over it.
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
      // Start at the top so the star points straight up.
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

/// Draws the field itself: divider, both bands and the comet trails.
class _FieldPainter extends CustomPainter {
  _FieldPainter({
    required this.game,
    required this.tuning,
    required this.blue,
    required this.red,
    required this.bar,
    required this.gate,
    required this.band,
    required this.gateProgress,
  });

  final SlingPuckGame game;
  final GameTuning tuning;
  final Color blue;
  final Color red;
  final Color bar;
  final Color gate;
  final Color band;

  /// 0 while the gate is open, 1 once its two panels have met.
  final double gateProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width; // field is 1.0 wide, so this is the scale

    _paintDivider(canvas, s);
    _paintBand(canvas, s, game.topBand);
    _paintBand(canvas, s, game.bottomBand);
    _paintTrails(canvas, s);
  }

  void _paintDivider(Canvas canvas, double s) {
    final y = tuning.barCentreY * s;
    final paint = Paint()
      ..color = bar
      ..strokeWidth = tuning.barThickness * s
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, y), Offset(tuning.gapLeft * s, y), paint);
    canvas.drawLine(Offset(tuning.gapRight * s, y), Offset(s, y), paint);

    if (gateProgress <= 0) return;

    // Two panels sliding in from the edges of the gap to meet in the
    // middle, rather than a single bar blinking into existence.
    final gatePaint = Paint()
      ..color = gate
      ..strokeWidth = tuning.gateThickness * s
      ..strokeCap = StrokeCap.round;

    final left = tuning.gapLeft * s;
    final right = tuning.gapRight * s;
    final reach = (right - left) / 2 * gateProgress;

    canvas.drawLine(Offset(left, y), Offset(left + reach, y), gatePaint);
    canvas.drawLine(Offset(right, y), Offset(right - reach, y), gatePaint);
  }

  /// A band is a two-segment V from its left post, through the apex, to its
  /// right post. At rest that is a straight line; pressed it bows toward
  /// the wall; springing back it passes flat and briefly inverts.
  void _paintBand(Canvas canvas, double s, Band b) {
    final left = Offset(tuning.bandPostInset * s, b.restY * s);
    final right = Offset((1 - tuning.bandPostInset) * s, b.restY * s);
    final apex = Offset(b.apexX * s, b.apexY * s);

    canvas.drawPath(
      Path()
        ..moveTo(left.dx, left.dy)
        ..lineTo(apex.dx, apex.dy)
        ..lineTo(right.dx, right.dy),
      Paint()
        ..color = band
        ..strokeWidth = tuning.bandStroke * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    final postPaint = Paint()..color = band;
    final postRadius = tuning.bandStroke * s * 1.6;
    canvas.drawCircle(left, postRadius, postPaint);
    canvas.drawCircle(right, postRadius, postPaint);
  }

  /// A tapered comet behind anything moving fast: wide at the piece,
  /// pointed at the tail, fading out along its length.
  void _paintTrails(Canvas canvas, double s) {
    final r = tuning.pieceRadius;

    for (final piece in game.pieces) {
      if (piece.isHeld) continue;
      final speed = piece.speed;
      if (speed < tuning.trailMinSpeed) continue;

      final dirX = piece.vx / speed;
      final dirY = piece.vy / speed;
      final length = tuning.trailSeconds * speed;
      final halfWidth = r * 0.5;

      final head = Offset(piece.x * s, piece.y * s);
      final tail = Offset(
        (piece.x - (dirX * length)) * s,
        (piece.y - (dirY * length)) * s,
      );
      final sideX = -dirY * halfWidth * s;
      final sideY = dirX * halfWidth * s;

      final colour = piece.owner == SlingPuckPlayer.player1 ? blue : red;
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

/// Rest lines, the D_MAX limit and a per-piece state readout.
class _DebugPainter extends CustomPainter {
  const _DebugPainter({
    required this.game,
    required this.tuning,
    this.bot,
  });

  final SlingPuckGame game;
  final GameTuning tuning;

  /// Present only in a Bot match, so its hand can be drawn too.
  final SimpleSlingPuckBotStrategy? bot;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final guide = Paint()
      ..color = Colors.teal.withValues(alpha: 0.9)
      ..strokeWidth = 1;
    final limit = Paint()
      ..color = Colors.deepOrange.withValues(alpha: 0.8)
      ..strokeWidth = 1;

    for (final b in [game.topBand, game.bottomBand]) {
      final restY = b.restY * s;
      canvas.drawLine(Offset(0, restY), Offset(s, restY), guide);
      final maxY = (b.restY + (b.pressNormalY * tuning.maxStretch)) * s;
      canvas.drawLine(Offset(0, maxY), Offset(s, maxY), limit);
    }

    _paintBotHand(canvas, s);

    for (final piece in game.pieces) {
      final state = piece.isHeld
          ? 'held'
          : piece.boostLeft > 0
              ? 'boost'
              : piece.speed > tuning.cruiseSpeed
                  ? 'fast'
                  : piece.speed > 0
                      ? 'glide'
                      : 'rest';
      final painter = TextPainter(
        text: TextSpan(
          text: '${piece.speed.toStringAsFixed(2)}\n'
              '$state ${piece.boostLeft > 0 ? piece.boostLeft.toStringAsFixed(2) : ''}',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 8,
            height: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          (piece.x * s) - (painter.width / 2),
          (piece.y * s) + (tuning.pieceRadius * s),
        ),
      );
    }
  }

  /// The bot's virtual finger, and what it thinks it is doing.
  void _paintBotHand(Canvas canvas, double s) {
    final hand = bot;
    if (hand == null) return;

    final centre = Offset(hand.handX * s, hand.handY * s);
    final marker = Paint()
      ..color = Colors.purple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final reach = tuning.pieceRadius * s * 0.6;

    canvas.drawCircle(centre, reach, marker);
    canvas.drawLine(centre.translate(-reach, 0), centre.translate(reach, 0), marker);
    canvas.drawLine(centre.translate(0, -reach), centre.translate(0, reach), marker);

    final label = TextPainter(
      text: TextSpan(
        text: hand.phase.name,
        style: const TextStyle(
          color: Colors.purple,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, centre.translate(reach + 3, -reach));
  }

  @override
  bool shouldRepaint(covariant _DebugPainter oldDelegate) => true;
}

/// Live sliders for the values most worth tuning by feel.
class _TuningPanel extends StatelessWidget {
  const _TuningPanel({required this.tuning, required this.onChanged});

  final GameTuning tuning;
  final ValueChanged<GameTuning> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _row('V_LAUNCH', tuning.launchSpeed, 1, 8,
                  (v) => onChanged(tuning.copyWith(launchSpeed: v))),
              _row('V_CRUISE', tuning.cruiseSpeed, 0.1, 2,
                  (v) => onChanged(tuning.copyWith(cruiseSpeed: v))),
              _row('D_MAX', tuning.maxStretch, 0.02, 0.2,
                  (v) => onChanged(tuning.copyWith(maxStretch: v))),
              _row('T_BOOST', tuning.boostDuration, 0.05, 1,
                  (v) => onChanged(tuning.copyWith(boostDuration: v))),
              _row('K_SLOW', tuning.slowRate, 0.1, 3,
                  (v) => onChanged(tuning.copyWith(slowRate: v))),
              _row('omega', tuning.bandOmega, 5, 40,
                  (v) => onChanged(tuning.copyWith(bandOmega: v))),
              _row('zeta', tuning.bandZeta, 0.05, 1,
                  (v) => onChanged(tuning.copyWith(bandZeta: v))),
              _row('e piece', tuning.restitutionPiece, 0, 1,
                  (v) => onChanged(tuning.copyWith(restitutionPiece: v))),
              _row('e wall', tuning.restitutionWall, 0, 1,
                  (v) => onChanged(tuning.copyWith(restitutionWall: v))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: SliderTheme(
            data: const SliderThemeData(trackHeight: 2),
            child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(value.toStringAsFixed(2),
              textAlign: TextAlign.right, style: const TextStyle(fontSize: 10)),
        ),
      ],
    );
  }
}
