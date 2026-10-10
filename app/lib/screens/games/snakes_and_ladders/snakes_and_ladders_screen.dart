import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../data/games_registry.dart';
import '../../../games/snakes_and_ladders/logic/snakes_and_ladders_game.dart';
import '../../../games/snakes_and_ladders/models/snakes_and_ladders_models.dart';
import '../../../games/snakes_and_ladders/presentation/snakes_and_ladders_match_controller.dart';
import '../../../models/game_definition.dart';
import '../../../widgets/turn_indicator.dart';
import '../../game_result_screen.dart';

/// Maps between squares and screen pixels.
class _BoardGeometry {
  const _BoardGeometry(this.cell);

  /// The side of one square, in pixels.
  final double cell;

  double get side => cell * SnakesAndLaddersGame.columns;

  /// The middle of a square, 1 to 100.
  Offset centreOf(int square) {
    final (row, column) = SnakesAndLaddersGame.gridFor(square);
    return Offset((column + 0.5) * cell, (row + 0.5) * cell);
  }

  Rect rectOf(int square) {
    final (row, column) = SnakesAndLaddersGame.gridFor(square);
    return Rect.fromLTWH(column * cell, row * cell, cell, cell);
  }
}

/// Visual Specifications:
/// - A 10x10 board numbered the way a real one is: square 1 bottom
///   left, each row running back the other way, 100 in the top corner
/// - Ladders are drawn as rails and rungs, snakes as a tapering body
///   with a head at the square that swallows you
/// - Tokens carry the platform identity (Blue/Red) and walk the board
///   square by square, then slide along whatever they landed on
/// - Turn-tinted background and face-to-face turn indicators
///   (AGENTS.md §10.1.1, §10.1.7)
/// - A die the player to move taps to roll
/// - 3-dot options menu (Restart, Exit Game). No Revert: taking back a
///   roll is not taking back a decision, it is a second go at the die
/// - Seamless transition to the shared GameResultScreen
class SnakesAndLaddersScreen extends StatefulWidget {
  final GameMode mode;

  const SnakesAndLaddersScreen({
    super.key,
    this.mode = GameMode.local,
  });

  @override
  State<SnakesAndLaddersScreen> createState() => _SnakesAndLaddersScreenState();
}

class _SnakesAndLaddersScreenState extends State<SnakesAndLaddersScreen>
    with TickerProviderStateMixin {
  late final SnakesAndLaddersMatchController _matchController;

  /// This game's metadata, looked up once so the turn indicator layout
  /// and orientation contract are driven by configuration rather than
  /// hardcoded in this screen (AGENTS.md §10.1.6).
  static final GameDefinition _definition =
      kGames.firstWhere((g) => g.id == 'snakes_and_ladders');

  // Platform player identity (AGENTS.md §10.1.1) and the turn
  // backgrounds the other board games already use.
  static const Color _bluePlayerColor = Color(0xFF00ACF8);
  static const Color _redPlayerColor = Color(0xFFFF5E57);
  static const Color _blueBgColor = Color(0xFF63C5F0);
  static const Color _redBgColor = Color(0xFFF28D88);
  static const Color _optionsButtonColor = Color(0xFF303943);

  // A printed board: cream card, two alternating square tints, dark
  // ink for the numbers.
  static const Color _boardFrameColor = Color(0xFF2A2F36);
  static const Color _lightSquareColor = Color(0xFFFBF3DF);
  static const Color _darkSquareColor = Color(0xFFF2E2BE);
  static const Color _numberColor = Color(0x991F2A37);
  static const Color _ladderColor = Color(0xFFB07434);
  static const Color _ladderRungColor = Color(0xFFD9A05B);
  static const Color _snakeColor = Color(0xFF4CA64C);
  static const Color _snakeBellyColor = Color(0xFF8FD36B);

  static const double _frameWidth = 7;
  static const double _boardRadius = 14;

  // The die spins before it settles, then the token walks, then
  // whatever it landed on carries it off.
  static const int _diceSpinMs = 480;
  static const int _perStepMs = 95;
  static const int _jumpMs = 520;

  static const int _resultDelayMs = 700;

  late final AnimationController _moveController;
  final math.Random _dieFaceRandom = math.Random();

  SnakesAndLaddersMove? _animatingMove;
  int _totalMs = _diceSpinMs;

  /// What the die is showing right now. Spins through faces while a
  /// roll is settling.
  int _dieFace = 1;
  Timer? _dieSpinTimer;

  int _lastHandledMoveCount = 0;
  bool _isTransitioningToResult = false;
  bool _isOptionsMenuOpen = false;
  Timer? _resultTransitionTimer;

  @override
  void initState() {
    super.initState();
    _matchController = SnakesAndLaddersMatchController(mode: widget.mode)
      ..addListener(_onMatchStateChanged);
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _diceSpinMs),
    )..addStatusListener((status) {
        if (status != AnimationStatus.completed || !mounted) return;
        setState(() => _animatingMove = null);
      });
  }

  @override
  void dispose() {
    _dieSpinTimer?.cancel();
    _resultTransitionTimer?.cancel();
    _moveController.dispose();
    _matchController
      ..removeListener(_onMatchStateChanged)
      ..dispose();
    super.dispose();
  }

  // ── Reacting to the match ─────────────────────────────────────────────

  void _onMatchStateChanged() {
    if (!mounted) return;

    final game = _matchController.game;
    final isNewRoll = game.moveCount > _lastHandledMoveCount;
    _lastHandledMoveCount = game.moveCount;

    if (isNewRoll) {
      final move = game.lastMove;
      if (move != null) _startMoveAnimation(move);
      if (game.isGameOver) _scheduleResultTransition();
    }

    setState(() {});
  }

  void _startMoveAnimation(SnakesAndLaddersMove move) {
    _animatingMove = move;
    _totalMs = _diceSpinMs +
        (move.steps.abs() * _perStepMs) +
        (move.jump == null ? 0 : _jumpMs);

    _spinDie();
    _moveController
      ..duration = Duration(milliseconds: _totalMs)
      ..forward(from: 0);
  }

  /// Flickers the die through faces, then leaves it on what was
  /// actually rolled.
  void _spinDie() {
    _dieSpinTimer?.cancel();
    final settled = _animatingMove?.roll ?? _dieFace;
    final started = DateTime.now();

    _dieSpinTimer = Timer.periodic(const Duration(milliseconds: 70), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final spun = DateTime.now().difference(started).inMilliseconds;
      if (spun >= _diceSpinMs) {
        timer.cancel();
        setState(() => _dieFace = settled);
        return;
      }
      setState(() => _dieFace = _dieFaceRandom.nextInt(6) + 1);
    });
  }

  void _onRoll() {
    if (_isTransitioningToResult || _animatingMove != null) return;
    _matchController.rollDice();
  }

  void _resetAnimation() {
    _dieSpinTimer?.cancel();
    _moveController.stop();
    _moveController.reset();
    _animatingMove = null;
    _totalMs = _diceSpinMs;
    _dieFace = 1;
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
  }

  void _exitGame() => Navigator.of(context).pop();

  /// No draw arm: somebody reaches the last square first.
  void _navigateToResultScreen() {
    final resultData =
        _matchController.game.winner == SnakesAndLaddersPlayer.player1
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

    _isTransitioningToResult = true;
    _resultTransitionTimer = Timer(
      Duration(milliseconds: _totalMs + _resultDelayMs),
      () {
        if (mounted && _isTransitioningToResult) _navigateToResultScreen();
      },
    );
  }

  // ── Where a token is drawn ────────────────────────────────────────────

  /// Where a token sits right now, in pixels.
  ///
  /// Mid-roll the moving token is wherever the animation has got to:
  /// first it waits out the die, then it walks a square at a time, then
  /// the snake or ladder carries it off. Everything else just sits on
  /// its square.
  Offset _tokenCentre(SnakesAndLaddersPlayer player, _BoardGeometry geometry) {
    final game = _matchController.game;
    final move = _animatingMove;
    final resting = game.positionOf(player);

    if (move == null || move.player != player || move.blocked) {
      return _restingCentre(player, resting, geometry);
    }

    final elapsed = _moveController.value * _totalMs;
    final walkMs = move.steps.abs() * _perStepMs;

    if (elapsed <= _diceSpinMs) {
      return _restingCentre(player, move.from, geometry);
    }

    if (elapsed <= _diceSpinMs + walkMs) {
      final walked = walkMs == 0 ? 1.0 : (elapsed - _diceSpinMs) / walkMs;
      final exact = move.from + (move.steps * walked);
      final behind = exact.floor().clamp(move.from, move.landedOn);
      final ahead = (behind + 1).clamp(move.from, move.landedOn);
      return Offset.lerp(
        _restingCentre(player, behind, geometry),
        _restingCentre(player, ahead, geometry),
        exact - behind,
      )!;
    }

    final jump = move.jump;
    if (jump == null) return _restingCentre(player, move.landedOn, geometry);

    final slid =
        ((elapsed - _diceSpinMs - walkMs) / _jumpMs).clamp(0.0, 1.0);
    return Offset.lerp(
      _restingCentre(player, jump.from, geometry),
      _restingCentre(player, jump.to, geometry),
      Curves.easeInOut.transform(slid),
    )!;
  }

  /// Tokens share squares often, so they sit either side of the middle
  /// rather than one hiding the other.
  Offset _restingCentre(
    SnakesAndLaddersPlayer player,
    int square,
    _BoardGeometry geometry,
  ) {
    final nudge = geometry.cell * 0.16;
    final sideways =
        player == SnakesAndLaddersPlayer.player1 ? -nudge : nudge;

    // Still waiting to come on: parked on square one, which under
    // these rules no token can ever actually occupy -- a six brings it
    // on at square six -- so it reads as the start line without ever
    // being mistaken for a real position. Parking it off the board
    // would simply hide it, since the board is clipped.
    return geometry.centreOf(square == 0 ? 1 : square).translate(sideways, 0);
  }

  // ── Composition ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // The declared orientation behavior is the enforced contract for
    // this screen's composition, not a decorative label (AGENTS.md §8).
    final gameBody = switch (_definition.orientationBehavior) {
      GameOrientationBehavior.fixedPortrait => _buildFixedPortraitComposition(),
      GameOrientationBehavior.fixedLandscape ||
      GameOrientationBehavior.adaptive =>
        throw UnsupportedError(
          'SnakesAndLaddersScreen only implements '
          'GameOrientationBehavior.fixedPortrait, but snakes_and_ladders '
          'is declared as ${_definition.orientationBehavior}.',
        ),
    };

    return PopScope(canPop: true, child: Scaffold(body: gameBody));
  }

  Widget _buildFixedPortraitComposition() {
    final game = _matchController.game;
    final isBlueTurn = game.currentPlayer == SnakesAndLaddersPlayer.player1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      color: isBlueTurn ? _blueBgColor : _redBgColor,
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 92, 10, 150),
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // The board is square, so it fits itself to
                    // whichever side is more constraining and never
                    // rotates its pixels (AGENTS.md §8.1-8.4).
                    const frame = _frameWidth * 2;
                    final side = math.min(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    final geometry = _BoardGeometry(
                      (side - frame) / SnakesAndLaddersGame.columns,
                    );

                    return SizedBox(
                      key: const ValueKey('snakes_and_ladders_board'),
                      width: geometry.side + frame,
                      height: geometry.side + frame,
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

            Positioned(
              left: 0,
              right: 0,
              bottom: 74,
              child: Center(child: _buildDie(isBlueTurn)),
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

  Widget _buildBoard(_BoardGeometry geometry) {
    return Container(
      decoration: BoxDecoration(
        color: _boardFrameColor,
        borderRadius: BorderRadius.circular(_boardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(_frameWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_boardRadius - _frameWidth),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BoardPainter(
                  geometry: geometry,
                  lightSquare: _lightSquareColor,
                  darkSquare: _darkSquareColor,
                  number: _numberColor,
                  ladder: _ladderColor,
                  rung: _ladderRungColor,
                  snake: _snakeColor,
                  snakeBelly: _snakeBellyColor,
                ),
              ),
            ),
            // Tokens stay real widgets so each keeps a key a test can
            // reach, the way Sling Puck's pieces do.
            _buildToken(SnakesAndLaddersPlayer.player2, geometry),
            _buildToken(SnakesAndLaddersPlayer.player1, geometry),
          ],
        ),
      ),
    );
  }

  Widget _buildToken(SnakesAndLaddersPlayer player, _BoardGeometry geometry) {
    final isBlue = player == SnakesAndLaddersPlayer.player1;
    final size = geometry.cell * 0.62;

    return AnimatedBuilder(
      animation: _moveController,
      builder: (context, child) {
        final centre = _tokenCentre(player, geometry);
        return Positioned(
          left: centre.dx - (size / 2),
          top: centre.dy - (size / 2),
          child: child!,
        );
      },
      child: IgnorePointer(
        child: SizedBox(
          key: ValueKey('snakes_and_ladders_token_${isBlue ? 'blue' : 'red'}'),
          width: size,
          height: size,
          child: CustomPaint(
            painter: _TokenPainter(
              colour: isBlue ? _bluePlayerColor : _redPlayerColor,
              outline: _boardFrameColor,
            ),
          ),
        ),
      ),
    );
  }

  /// The die. Tapping it rolls for whoever is to move.
  Widget _buildDie(bool isBlueTurn) {
    final busy = _animatingMove != null || _isTransitioningToResult;
    final colour = isBlueTurn ? _bluePlayerColor : _redPlayerColor;

    return GestureDetector(
      key: const ValueKey('snakes_and_ladders_die'),
      onTap: _onRoll,
      child: AnimatedScale(
        scale: busy ? 0.92 : 1,
        duration: const Duration(milliseconds: 180),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colour, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CustomPaint(
            painter: _DieFacePainter(
              face: _dieFace,
              pip: _boardFrameColor,
            ),
          ),
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

  /// Restart and Exit Game only -- see
  /// [SnakesAndLaddersMatchController.supportsRevert] for why there is
  /// no Revert.
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.black87, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Painters ────────────────────────────────────────────────────────────

/// The printed board: squares, their numbers, and every snake and
/// ladder on it. All fixed furniture, so it only repaints on a resize.
class _BoardPainter extends CustomPainter {
  const _BoardPainter({
    required this.geometry,
    required this.lightSquare,
    required this.darkSquare,
    required this.number,
    required this.ladder,
    required this.rung,
    required this.snake,
    required this.snakeBelly,
  });

  final _BoardGeometry geometry;
  final Color lightSquare;
  final Color darkSquare;
  final Color number;
  final Color ladder;
  final Color rung;
  final Color snake;
  final Color snakeBelly;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSquares(canvas);
    for (final entry in SnakesAndLaddersGame.jumps.entries) {
      final jump = Jump(entry.key, entry.value);
      if (jump.isLadder) {
        _paintLadder(canvas, jump);
      } else {
        _paintSnake(canvas, jump);
      }
    }
  }

  void _paintSquares(Canvas canvas) {
    final light = Paint()..color = lightSquare;
    final dark = Paint()..color = darkSquare;

    for (var square = 1; square <= SnakesAndLaddersGame.lastSquare; square++) {
      final rect = geometry.rectOf(square);
      final (row, column) = SnakesAndLaddersGame.gridFor(square);
      canvas.drawRect(rect, (row + column).isEven ? light : dark);

      final label = TextPainter(
        text: TextSpan(
          text: '$square',
          style: TextStyle(
            color: number,
            fontSize: geometry.cell * 0.26,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        rect.topLeft + Offset(geometry.cell * 0.1, geometry.cell * 0.06),
      );
    }
  }

  void _paintLadder(Canvas canvas, Jump jump) {
    final foot = geometry.centreOf(jump.from);
    final top = geometry.centreOf(jump.to);

    final along = top - foot;
    final length = along.distance;
    if (length < 1) return;

    // Across the ladder, at right angles to the climb.
    final across = Offset(-along.dy, along.dx) / length * (geometry.cell * 0.17);

    final rail = Paint()
      ..color = ladder
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.5, geometry.cell * 0.075)
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(foot + across, top + across, rail);
    canvas.drawLine(foot - across, top - across, rail);

    final rungs = math.max(2, (length / (geometry.cell * 0.55)).round());
    final rungPaint = Paint()
      ..color = rung
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, geometry.cell * 0.055)
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i <= rungs; i++) {
      final at = Offset.lerp(foot, top, i / rungs)!;
      canvas.drawLine(at + across, at - across, rungPaint);
    }
  }

  void _paintSnake(Canvas canvas, Jump jump) {
    final head = geometry.centreOf(jump.from);
    final tail = geometry.centreOf(jump.to);

    final along = tail - head;
    final length = along.distance;
    if (length < 1) return;

    // A lazy S, so it reads as a snake rather than a pipe.
    final across = Offset(-along.dy, along.dx) / length * (geometry.cell * 0.6);
    final body = Path()
      ..moveTo(head.dx, head.dy)
      ..cubicTo(
        head.dx + across.dx,
        head.dy + across.dy,
        tail.dx - across.dx,
        tail.dy - across.dy,
        tail.dx,
        tail.dy,
      );

    canvas.drawPath(
      body,
      Paint()
        ..color = snake
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(4, geometry.cell * 0.2)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = snakeBelly
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, geometry.cell * 0.07)
        ..strokeCap = StrokeCap.round,
    );

    // The head sits on the square that swallows you.
    final headRadius = geometry.cell * 0.2;
    canvas.drawCircle(head, headRadius, Paint()..color = snake);
    for (final side in [-1, 1]) {
      canvas.drawCircle(
        head.translate(headRadius * 0.38 * side, -headRadius * 0.25),
        headRadius * 0.22,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_BoardPainter oldDelegate) =>
      oldDelegate.geometry.cell != geometry.cell ||
      oldDelegate.lightSquare != lightSquare ||
      oldDelegate.snake != snake ||
      oldDelegate.ladder != ladder;
}

/// A player's token: a disc with a chunky outline and a gloss.
class _TokenPainter extends CustomPainter {
  const _TokenPainter({required this.colour, required this.outline});

  final Color colour;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(
      centre.translate(0, radius * 0.18),
      radius * 0.98,
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );
    canvas.drawCircle(centre, radius, Paint()..color = colour);
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, radius * 0.16),
    );
    canvas.drawCircle(
      centre.translate(-radius * 0.28, -radius * 0.3),
      radius * 0.24,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(_TokenPainter oldDelegate) =>
      oldDelegate.colour != colour;
}

/// One face of a die, 1 to 6.
class _DieFacePainter extends CustomPainter {
  const _DieFacePainter({required this.face, required this.pip});

  final int face;
  final Color pip;

  /// Where the pips go, as fractions of the face.
  static const Map<int, List<(double, double)>> _layout = {
    1: [(0.5, 0.5)],
    2: [(0.28, 0.28), (0.72, 0.72)],
    3: [(0.26, 0.26), (0.5, 0.5), (0.74, 0.74)],
    4: [(0.3, 0.3), (0.7, 0.3), (0.3, 0.7), (0.7, 0.7)],
    5: [(0.28, 0.28), (0.72, 0.28), (0.5, 0.5), (0.28, 0.72), (0.72, 0.72)],
    6: [
      (0.3, 0.26),
      (0.7, 0.26),
      (0.3, 0.5),
      (0.7, 0.5),
      (0.3, 0.74),
      (0.7, 0.74),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final spots = _layout[face] ?? const [(0.5, 0.5)];
    final radius = size.shortestSide * 0.085;
    final paint = Paint()..color = pip;

    for (final (x, y) in spots) {
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DieFacePainter oldDelegate) =>
      oldDelegate.face != face || oldDelegate.pip != pip;
}
