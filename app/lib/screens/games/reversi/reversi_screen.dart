import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../data/games_registry.dart';
import '../../../games/reversi/logic/reversi_game.dart';
import '../../../games/reversi/models/reversi_models.dart';
import '../../../games/reversi/presentation/reversi_match_controller.dart';
import '../../../models/game_definition.dart';
import '../../../widgets/turn_indicator.dart';
import '../../game_result_screen.dart';

/// Visual Specifications:
/// - Dynamic background: soft blue on Blue turn, soft coral on Red turn
///   (AGENTS.md §10.1.7)
/// - A classic green 8x8 board behind a thick frame, rounded on the
///   outside and again on the playing surface inside it
/// - Discs carry the platform identity (Blue/Red), a thin outline and a
///   light inner shadow -- no drop shadow
/// - Every square the player may legally take is marked with a ghost disc
///   in their own colour
/// - Captured discs turn over with a real half-rotation, the wave
///   spreading outwards from the disc that was just laid
/// - Face-to-face turn indicators, a live disc count top-left, and the
///   standard 3-dot options menu top-right
/// - Seamless transition to the shared GameResultScreen, including the
///   draw it is the first board game here to actually need
class ReversiScreen extends StatefulWidget {
  final GameMode mode;

  const ReversiScreen({
    super.key,
    this.mode = GameMode.local,
  });

  @override
  State<ReversiScreen> createState() => _ReversiScreenState();
}

class _ReversiScreenState extends State<ReversiScreen>
    with SingleTickerProviderStateMixin {
  late final ReversiMatchController _matchController;

  /// This game's metadata, looked up once so the turn indicator layout and
  /// orientation contract are driven by configuration rather than
  /// hardcoded in this screen (AGENTS.md §10.1.6).
  static final GameDefinition _definition =
      kGames.firstWhere((g) => g.id == 'reversi');

  // Platform player identity (AGENTS.md §10.1.1) and the turn backgrounds
  // the other board games already use.
  static const Color _bluePlayerColor = Color(0xFF00ACF8);
  static const Color _redPlayerColor = Color(0xFFFF5E57);
  static const Color _blueBgColor = Color(0xFF63C5F0);
  static const Color _redBgColor = Color(0xFFF28D88);
  static const Color _optionsButtonColor = Color(0xFF303943);

  /// The board itself is matched to a real magnetic Reversi set: bright
  /// green squares, a black plastic frame and black grid lines. The
  /// screen behind it keeps the platform's turn tint (AGENTS.md §10.1.7).
  static const Color _boardSurfaceColor = Color(0xFF23A94F);
  static const Color _boardFrameColor = Color(0xFF1C1C1C);
  static const Color _gridLineColor = Color(0xFF111111);

  static const double _frameWidth = 10;
  static const double _outerRadius = 11;
  static const double _innerRadius = 6;

  // Flip timings. The placed disc lands first, then the capture travels
  // outwards one square at a time.
  static const int _placeMs = 170;
  static const int _discFlipMs = 485;
  static const int _staggerMs = 80;

  /// Held back so the last flip of a game-ending move finishes before the
  /// result screen takes over. The longest possible cascade is six
  /// squares -- 170 + 485 + 80*5 = 1055ms -- so these two numbers are
  /// coupled: slow the flip down and this has to grow with it.
  static const int _resultDelayMs = 1150;

  late final AnimationController _flipController;

  /// The move being animated, and how far each captured disc sits from
  /// the disc that was laid. Chebyshev distance is exactly the step index
  /// along its ray, so discs the same distance out on different rays turn
  /// together and the whole thing reads as one wave.
  ReversiMove? _animatingMove;
  Map<ReversiPosition, int> _flipDistances = const {};
  int _totalMs = _placeMs + _discFlipMs;

  int _lastHandledMoveCount = 0;
  bool _isTransitioningToResult = false;
  bool _isOptionsMenuOpen = false;
  Timer? _resultTransitionTimer;

  /// Shown when a player had no legal move and was skipped. The turn
  /// indicator cannot say this -- it does not change on a pass -- so this
  /// notice is the only signal the player gets.
  String? _passNotice;
  Timer? _passNoticeTimer;

  @override
  void initState() {
    super.initState();
    _matchController = ReversiMatchController(mode: widget.mode)
      ..addListener(_onMatchStateChanged);
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _animatingMove = null;
            _flipDistances = const {};
          });
          // The board has settled, so the opponent may answer now.
          _matchController.setPresentationBusy(false);
        }
      });
  }

  @override
  void dispose() {
    _resultTransitionTimer?.cancel();
    _passNoticeTimer?.cancel();
    _flipController.dispose();
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
      if (move != null) {
        _startFlip(move);
        _showPassNoticeFor(move);
      }
      if (game.isGameOver) _scheduleResultTransition();
    }

    setState(() {});
  }

  void _startFlip(ReversiMove move) {
    // Claimed before the controller gets as far as scheduling the bot,
    // because this runs inside the same notification as the move. That
    // ordering is what holds the bot back until the flip has finished.
    _matchController.setPresentationBusy(true);

    _flipDistances = {
      for (final disc in move.flipped)
        disc: math.max(
          (disc.row - move.position.row).abs(),
          (disc.col - move.position.col).abs(),
        ),
    };
    final furthest = _flipDistances.values.fold<int>(1, math.max);
    _totalMs = _placeMs + _discFlipMs + (_staggerMs * (furthest - 1));

    _animatingMove = move;
    _flipController
      ..duration = Duration(milliseconds: _totalMs)
      ..forward(from: 0);
  }

  void _showPassNoticeFor(ReversiMove move) {
    _passNoticeTimer?.cancel();
    final passed = move.passedPlayer;
    if (passed == null) {
      _passNotice = null;
      return;
    }

    _passNotice = '${_nameOf(passed)} HAS NO MOVE\n'
        '${_nameOf(move.player)} PLAYS AGAIN';
    _passNoticeTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _passNotice = null);
    });
  }

  static String _nameOf(ReversiPlayer player) =>
      player == ReversiPlayer.player1 ? 'BLUE' : 'RED';

  void _onCellTap(int row, int col) {
    // The engine applies a move instantly, so a second tap mid-flip would
    // leave the animation describing a board that no longer exists.
    if (_isTransitioningToResult || _animatingMove != null) return;
    _matchController.submitLocalMove(row, col);
  }

  void _resetAnimation() {
    _flipController.stop();
    _flipController.reset();
    _animatingMove = null;
    _flipDistances = const {};
    _passNoticeTimer?.cancel();
    _passNotice = null;
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
      ReversiGameStatus.draw => GameResultData.draw(label: 'DRAW'),
      _ => game.winner == ReversiPlayer.player1
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
          'ReversiScreen only implements '
          'GameOrientationBehavior.fixedPortrait, but reversi is '
          'declared as ${_definition.orientationBehavior}.',
        ),
    };

    return PopScope(canPop: true, child: Scaffold(body: gameBody));
  }

  /// A square board centred between the two face-to-face turn badges. A
  /// square board reads the same whether the device is held portrait or
  /// landscape, so this fits itself to whichever side is more
  /// constraining and never rotates its pixels (AGENTS.md §8.1-8.4).
  Widget _buildFixedPortraitComposition() {
    final game = _matchController.game;
    final isBlueTurn = game.currentPlayer == ReversiPlayer.player1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      color: isBlueTurn ? _blueBgColor : _redBgColor,
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              // Narrow side margins: the board is the screen, and every
              // point it loses to padding comes straight off the squares.
              padding: const EdgeInsets.fromLTRB(10.8, 110, 10.8, 110),
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side =
                        math.min(constraints.maxWidth, constraints.maxHeight);
                    return SizedBox(
                      key: const ValueKey('reversi_board'),
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
                // Short labels: a 'RED TURN' badge is wide enough to run
                // into the score chip on a narrow phone.
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

            if (_passNotice != null)
              Positioned.fill(
                child: IgnorePointer(child: _buildPassNotice(_passNotice!)),
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

  /// The live disc count. Deliberately quiet -- no shadow, dark text on a
  /// near-white pill so it stays legible over both turn backgrounds.
  Widget _buildScoreChip(ReversiGame game) {
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
            key: const ValueKey('reversi_score_red'),
            style: _scoreTextStyle,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(':', style: _scoreTextStyle),
          ),
          Text(
            '${game.blueScore}',
            key: const ValueKey('reversi_score_blue'),
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

  Widget _buildPassNotice(String notice) {
    return Center(
      child: Container(
        key: const ValueKey('reversi_pass_notice'),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xCC1B2430),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          notice,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
            height: 1.3,
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

  Widget _buildBoard() {
    return Container(
      decoration: BoxDecoration(
        color: _boardSurfaceColor,
        borderRadius: BorderRadius.circular(_outerRadius),
        border: Border.all(color: _boardFrameColor, width: _frameWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_innerRadius),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The Border has already inset us, so these constraints are
            // the playing surface itself -- no hand arithmetic, and the
            // squares cannot drift away from the painted grid.
            final cellSize =
                constraints.biggest.shortestSide / ReversiGame.size;

            return Stack(
              children: [
                // One painter rather than 64 coloured children: flex
                // rounding leaves hairline seams between them, and on a
                // flat green surface those read as a lattice.
                Positioned.fill(
                  child: CustomPaint(
                    painter: const _BoardPainter(
                      lineColor: _gridLineColor,
                    ),
                  ),
                ),
                Column(
                  children: [
                    for (var row = 0; row < ReversiGame.size; row++)
                      Expanded(
                        child: Row(
                          children: [
                            for (var col = 0; col < ReversiGame.size; col++)
                              Expanded(child: _buildSquare(row, col, cellSize)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSquare(int row, int col, double cellSize) {
    final game = _matchController.game;
    final position = ReversiPosition(row, col);
    final discSize = cellSize * 0.80;

    return GestureDetector(
      key: ValueKey('reversi_cell_${row}_$col'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(row, col),
      child: Center(
        child: _buildSquareContents(game, position, discSize),
      ),
    );
  }

  Widget _buildSquareContents(
    ReversiGame game,
    ReversiPosition position,
    double discSize,
  ) {
    final move = _animatingMove;

    if (move != null) {
      if (move.position == position) {
        // The disc that was just laid appears from nothing, so it pops in
        // rather than turning over.
        return AnimatedBuilder(
          animation: _flipController,
          builder: (context, _) => Transform.scale(
            scale: Curves.easeOutBack.transform(
              (_flipController.value * _totalMs / _placeMs).clamp(0.0, 1.0),
            ),
            child: _buildDisc(move.player, discSize),
          ),
        );
      }

      final distance = _flipDistances[position];
      if (distance != null) {
        return AnimatedBuilder(
          animation: _flipController,
          builder: (context, _) => _buildFlippingDisc(
            from: move.player.opponent,
            to: move.player,
            progress: _flipProgress(distance),
            discSize: discSize,
          ),
        );
      }
    }

    final owner = game.discAt(position.row, position.col);
    if (owner != null) return _buildDisc(owner, discSize);

    if (_showHints && game.legalMoves.containsKey(position)) {
      return _buildHint(game.currentPlayer, discSize);
    }
    return const SizedBox.shrink();
  }

  bool get _showHints =>
      _matchController.canAcceptLocalInput &&
      _animatingMove == null &&
      !_isTransitioningToResult;

  /// How far through its own half-turn the disc [distance] squares from
  /// the placed one is. Arithmetic rather than one CurvedAnimation per
  /// disc, since a single move can turn a dozen of them.
  double _flipProgress(int distance) {
    final start = (_placeMs + ((distance - 1) * _staggerMs)) / _totalMs;
    final end = start + (_discFlipMs / _totalMs);
    final raw =
        ((_flipController.value - start) / (end - start)).clamp(0.0, 1.0);
    return Curves.easeInOut.transform(raw);
  }

  /// A real half-rotation about the vertical axis, with the colour
  /// swapped exactly at edge-on where the disc is invisibly thin -- so
  /// the two faces read as one disc turning over rather than a crossfade.
  Widget _buildFlippingDisc({
    required ReversiPlayer from,
    required ReversiPlayer to,
    required double progress,
    required double discSize,
  }) {
    final angle = progress * math.pi;
    final face = angle > (math.pi / 2) ? to : from;

    return Transform(
      // Both the perspective entry and centring the alignment matter:
      // without them the disc only narrows, which looks squashed rather
      // than turned.
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0015)
        ..rotateY(angle),
      child: _buildDisc(face, discSize),
    );
  }

  Widget _buildDisc(ReversiPlayer owner, double discSize) {
    final colour =
        owner == ReversiPlayer.player1 ? _bluePlayerColor : _redPlayerColor;

    return SizedBox(
      width: discSize,
      height: discSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colour,
          shape: BoxShape.circle,
          // Thin outline, and no drop shadow: the bevel below does the
          // shaping instead.
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.35),
            width: (discSize * 0.075).clamp(2.0, 3.5),
          ),
        ),
        child: const DecoratedBox(
          // BoxDecoration has no inset shadow, so the light bevel is a
          // radial gradient -- the same trick Sling Puck uses, with the
          // stops softened into a ramp.
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0x00000000), Color(0x00000000), Color(0x45000000)],
              stops: [0.0, 0.50, 1.0],
            ),
          ),
          child: SizedBox.expand(),
        ),
      ),
    );
  }

  /// Marks a square you may take. One colour for both players -- the
  /// board's own ink rather than either disc colour -- because it marks
  /// a square, it is not a preview of a disc. It appears only on your
  /// own turn, beside a badge that names the colour in words, so nothing
  /// here rests on colour alone (AGENTS.md §10.1.16).
  Widget _buildHint(ReversiPlayer player, double discSize) {
    return SizedBox(
      key: ValueKey('reversi_hint_${player.name}'),
      width: discSize * 0.52,
      height: discSize * 0.52,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x591C1C1C),
        ),
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

/// The playing surface's markings: the grid, plus the four guide dots a
/// real Othello board carries.
class _BoardPainter extends CustomPainter {
  final Color lineColor;

  const _BoardPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.shortestSide / ReversiGame.size;
    final paint = Paint()
      // Heavier than a hairline, the way the lines are moulded into a
      // real board, and scaled with the square so a tablet does not end
      // up with a spiderweb.
      ..color = lineColor
      ..strokeWidth = math.max(2, cell * 0.05)
      ..isAntiAlias = false;

    for (var i = 1; i < ReversiGame.size; i++) {
      final offset = cell * i;
      canvas.drawLine(Offset(offset, 0), Offset(offset, size.height), paint);
      canvas.drawLine(Offset(0, offset), Offset(size.width, offset), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}
