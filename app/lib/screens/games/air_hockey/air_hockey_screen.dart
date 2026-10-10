import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../data/games_registry.dart';
import '../../../games/air_hockey/logic/air_hockey_game.dart';
import '../../../games/air_hockey/models/air_hockey_models.dart';
import '../../../games/air_hockey/presentation/air_hockey_match_controller.dart';
import '../../../models/game_definition.dart';
import '../../../widgets/turn_indicator.dart';
import '../../game_result_screen.dart';

/// Maps between the engine's table units and screen pixels.
///
/// The engine works on a table exactly 1.0 wide and 2.0 tall, so a single
/// scale factor -- the table's pixel width -- converts both ways. Same
/// shape as Sling Puck's `_FieldGeometry`.
class _TableGeometry {
  const _TableGeometry(this.scale);

  final double scale;

  Offset toScreen(double x, double y) => Offset(x * scale, y * scale);

  Offset toTable(Offset screen) =>
      Offset(screen.dx / scale, screen.dy / scale);

  double lengthToScreen(double tableLength) => tableLength * scale;
}

/// Visual Specifications:
/// - A 1:2 table stood on its end, in the style of a tabletop air hockey
///   set: white deck with a dotted grid and red markings, warm wooden
///   rails and near-black rounded corner caps, drawn with the chunky
///   outlines and soft gloss the rest of the platform uses (AGENTS.md §9)
/// - Both players push at once, so there is no turn indicator and no turn
///   background (AGENTS.md §10.1.3, via TurnIndicatorLayout.simultaneous).
///   The backdrop is a flat dull slate instead, and each player gets a
///   score badge on their own edge, where a face-to-face indicator would
///   sit
/// - Touch anywhere in your own half and your mallet travels to your
///   finger; both halves take a finger at the same time
/// - First to three goals takes the match
/// - 3-dot options menu (Restart, Exit Game). No Revert: nothing here
///   happens in discrete moves to undo
/// - Seamless transition to the shared GameResultScreen
class AirHockeyScreen extends StatefulWidget {
  final GameMode mode;

  const AirHockeyScreen({
    super.key,
    this.mode = GameMode.local,
  });

  @override
  State<AirHockeyScreen> createState() => _AirHockeyScreenState();
}

class _AirHockeyScreenState extends State<AirHockeyScreen>
    with TickerProviderStateMixin {
  late final AirHockeyMatchController _matchController;

  /// This game's metadata, looked up once so the turn indicator layout
  /// and orientation contract are driven by configuration rather than
  /// hardcoded in this screen (AGENTS.md §10.1.6).
  static final GameDefinition _definition =
      kGames.firstWhere((g) => g.id == 'air_hockey');

  // Platform player identity (AGENTS.md §10.1.1).
  static const Color _bluePlayerColor = Color(0xFF00ACF8);
  static const Color _redPlayerColor = Color(0xFFFF5E57);
  static const Color _optionsButtonColor = Color(0xFF303943);

  /// No turn means no turn tint, so the backdrop is simply a flat dull
  /// slate that lets the white deck carry the screen.
  static const Color _backdropColor = Color(0xFF2E3A4A);

  // The table, matched to a wooden tabletop set.
  static const Color _deckColor = Color(0xFFF7F5EE);
  static const Color _markingColor = Color(0xFFE03A32);
  static const Color _railColor = Color(0xFFE8A33D);
  static const Color _railShadeColor = Color(0xFFC9832A);

  /// A lighter peach than the rails, so the netting reads against it.
  static const Color _netRecessColor = Color(0xFFF2C185);
  static const Color _outlineColor = Color(0xFF1C2127);

  /// Charcoal rather than the photo's red: a red puck beside a red mallet
  /// would read as Red's property rather than as the thing both players
  /// are chasing.
  static const Color _puckColor = Color(0xFF32383F);

  static const double _railWidth = 12;
  static const double _borderWidth = 3;
  static const double _tableRadius = 26;

  static const int _resultDelayMs = 900;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  /// Which player each live finger is steering. A finger belongs to the
  /// half it came down in and keeps that half until it lifts, so dragging
  /// across the centre line cannot steal the other mallet.
  final Map<int, AirHockeyPlayer> _pointers = {};

  int _lastHandledGoalCount = 0;
  bool _isTransitioningToResult = false;
  bool _isOptionsMenuOpen = false;
  Timer? _resultTransitionTimer;

  @override
  void initState() {
    super.initState();
    _matchController = AirHockeyMatchController(mode: widget.mode)
      ..addListener(_onMatchStateChanged);
    _ticker = createTicker(_onTick);
    _ensureTicking();
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

  // ── The clock ─────────────────────────────────────────────────────────

  /// Air Hockey is never at rest the way a turn-based board is -- the
  /// puck drifts, the mallets chase fingers -- so the ticker simply runs
  /// for as long as the match does.
  void _ensureTicking() {
    if (_ticker.isActive || _matchController.game.isGameOver) return;
    _lastTick = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt =
        (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    if (!mounted || dt <= 0) return;

    final justWon = _matchController.advance(dt);

    final game = _matchController.game;
    if (game.goalCount != _lastHandledGoalCount) {
      _lastHandledGoalCount = game.goalCount;
    }

    if (justWon || game.isGameOver) {
      _ticker.stop();
      _scheduleResultTransition();
    }

    setState(() {});
  }

  void _onMatchStateChanged() {
    if (!mounted) return;
    if (_matchController.game.isGameOver) _scheduleResultTransition();
    setState(() {});
  }

  // ── Touch handling (both players at once) ─────────────────────────────

  AirHockeyPlayer _halfAt(Offset table) =>
      table.dy >= AirHockeyGame.tableHeight / 2
          ? AirHockeyPlayer.player1
          : AirHockeyPlayer.player2;

  void _onPointerDown(PointerDownEvent event, _TableGeometry geometry) {
    if (_isTransitioningToResult) return;

    final table = geometry.toTable(event.localPosition);
    final player = _halfAt(table);

    // One finger per half. A second finger on the same half is ignored
    // rather than allowed to fight the first for the mallet.
    if (_pointers.containsValue(player)) return;
    if (!_matchController.canControl(player)) return;

    _pointers[event.pointer] = player;
    _matchController.steer(player, table.dx, table.dy);
    _ensureTicking();
  }

  void _onPointerMove(PointerMoveEvent event, _TableGeometry geometry) {
    final player = _pointers[event.pointer];
    if (player == null) return;

    final table = geometry.toTable(event.localPosition);
    _matchController.steer(player, table.dx, table.dy);
  }

  void _onPointerUp(int pointer) {
    final player = _pointers.remove(pointer);
    if (player == null) return;
    _matchController.release(player);
  }

  // ── Match chrome ──────────────────────────────────────────────────────

  void _restartGame() {
    _resultTransitionTimer?.cancel();
    _resultTransitionTimer = null;
    _pointers.clear();
    _matchController.restart();
    setState(() {
      _lastHandledGoalCount = 0;
      _isTransitioningToResult = false;
    });
    _ensureTicking();
  }

  void _exitGame() => Navigator.of(context).pop();

  /// No draw arm: somebody has to reach three goals first.
  void _navigateToResultScreen() {
    final resultData =
        _matchController.game.winner == AirHockeyPlayer.player1
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
          'AirHockeyScreen only implements '
          'GameOrientationBehavior.fixedPortrait, but air_hockey is '
          'declared as ${_definition.orientationBehavior}.',
        ),
    };

    return PopScope(canPop: true, child: Scaffold(body: gameBody));
  }

  Widget _buildFixedPortraitComposition() {
    final game = _matchController.game;

    return ColoredBox(
      color: _backdropColor,
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 56, 10, 56),
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // It is the *deck* that has to come out exactly 1:2,
                    // not the box around it: the rails and the border eat
                    // the same number of pixels off every side, so sizing
                    // the outer box 1:2 would leave the deck taller than
                    // it is meant to be and slide every marking, every
                    // goal line and every touch down the table with it.
                    const frame = (_railWidth + _borderWidth) * 2;
                    final deck = math.min(
                      constraints.maxWidth - frame,
                      (constraints.maxHeight - frame) /
                          AirHockeyGame.tableHeight,
                    );
                    return SizedBox(
                      key: const ValueKey('air_hockey_table'),
                      width: deck + frame,
                      height: (deck * AirHockeyGame.tableHeight) + frame,
                      child: _buildTable(),
                    );
                  },
                ),
              ),
            ),

            // Declared in metadata and honoured here even though it
            // renders nothing, so this screen stays driven by
            // configuration rather than quietly opting out
            // (AGENTS.md §10.1.6).
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

            // The live status that stands in for the turn indicator
            // (AGENTS.md §10.1.3). It names both players rather than
            // sitting on their own edges, which is the same quiet chip
            // Dots and Boxes and Soccer Pool use.
            Positioned(top: 12, left: 16, child: _buildScoreChip(game)),

            if (game.isPaused && game.lastScorer != null)
              Positioned.fill(
                child: IgnorePointer(child: _buildGoalFlash(game.lastScorer!)),
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

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: _railColor,
        borderRadius: BorderRadius.circular(_tableRadius),
        border: Border.all(color: _outlineColor, width: _borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(_railWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_tableRadius - _railWidth),
          // Measured inside the rails, so this scale matches the
          // coordinate frame the pointer events are reported in.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final geometry = _TableGeometry(constraints.biggest.width);

              return Listener(
                key: const ValueKey('air_hockey_deck'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => _onPointerDown(e, geometry),
                onPointerMove: (e) => _onPointerMove(e, geometry),
                onPointerUp: (e) => _onPointerUp(e.pointer),
                onPointerCancel: (e) => _onPointerUp(e.pointer),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _TablePainter(
                          geometry: geometry,
                          deck: _deckColor,
                          marking: _markingColor,
                          blue: _bluePlayerColor,
                          red: _redPlayerColor,
                          outline: _outlineColor,
                          netRecess: _netRecessColor,
                        ),
                      ),
                    ),
                    // Drawn across the whole deck rather than inside the
                    // puck's own box, because a streak is longer than
                    // the thing making it. Only in the tree while there
                    // is a streak to draw.
                    if (_matchController.game.puck.speed >=
                        _TrailPainter.minSpeed)
                      Positioned.fill(
                        key: const ValueKey('air_hockey_puck_trail'),
                        child: CustomPaint(
                          painter: _TrailPainter(
                            puck: _matchController.game.puck,
                            geometry: geometry,
                            colour: _puckColor,
                          ),
                        ),
                      ),

                    // The moving bodies stay real widgets so each keeps a
                    // key a test can reach, the way Sling Puck's pieces
                    // do. They never take a touch themselves -- the
                    // Listener below owns the whole table.
                    _buildMallet(AirHockeyPlayer.player2, geometry),
                    _buildMallet(AirHockeyPlayer.player1, geometry),
                    _buildPuck(geometry),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPuck(_TableGeometry geometry) {
    final puck = _matchController.game.puck;
    final radius = geometry.lengthToScreen(AirHockeyGame.puckRadius);

    return _buildBody(
      key: const ValueKey('air_hockey_puck'),
      centre: geometry.toScreen(puck.x, puck.y),
      radius: radius,
      painter: _BodyPainter(
        radius: radius,
        colour: _puckColor,
        outline: _outlineColor,
        knobColour: null,
      ),
    );
  }

  Widget _buildMallet(AirHockeyPlayer player, _TableGeometry geometry) {
    final isBlue = player == AirHockeyPlayer.player1;
    final mallet = _matchController.game.malletFor(player);
    final radius = geometry.lengthToScreen(AirHockeyGame.malletRadius);

    return _buildBody(
      key: ValueKey('air_hockey_mallet_${isBlue ? 'blue' : 'red'}'),
      centre: geometry.toScreen(mallet.x, mallet.y),
      radius: radius,
      painter: _BodyPainter(
        radius: radius,
        colour: isBlue ? _bluePlayerColor : _redPlayerColor,
        outline: _outlineColor,
        knobColour: _railShadeColor,
      ),
    );
  }

  /// A round body, drawn with room around it for its shadow and its
  /// outline so neither is clipped. The painter is told the radius
  /// rather than deriving it from this box, so the two cannot drift
  /// apart when the box is resized.
  Widget _buildBody({
    required Key key,
    required Offset centre,
    required double radius,
    required _BodyPainter painter,
  }) {
    final box = radius * _BodyPainter.boxFactor;

    return Positioned.fromRect(
      rect: Rect.fromCenter(center: centre, width: box, height: box),
      child: IgnorePointer(
        child: SizedBox(
          key: key,
          width: box,
          height: box,
          child: CustomPaint(painter: painter),
        ),
      ),
    );
  }

  /// A player's own score, as filled pips plus the colour's name. Three
  /// signals -- position, word and shape -- so nothing here rests on
  /// colour alone (AGENTS.md §10.1.16).
  /// The live score. Deliberately quiet -- dark text on a near-white
  /// pill, the same chip Dots and Boxes and Soccer Pool carry -- so it
  /// reads as information rather than as a third thing on the table.
  /// Each player finds their own count beside their own colour, which
  /// is the status AGENTS.md 10.1.3 asks a game with no turns to show.
  Widget _buildScoreChip(AirHockeyGame game) {
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
            key: const ValueKey('air_hockey_score_red'),
            style: _scoreTextStyle,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(':', style: _scoreTextStyle),
          ),
          Text(
            '${game.blueScore}',
            key: const ValueKey('air_hockey_score_blue'),
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

  Widget _buildGoalFlash(AirHockeyPlayer scorer) {
    final colour = scorer == AirHockeyPlayer.player1
        ? _bluePlayerColor
        : _redPlayerColor;

    return Center(
      child: Container(
        key: const ValueKey('air_hockey_goal_flash'),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        decoration: BoxDecoration(
          color: colour,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: const Text(
          'GOAL!',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 30,
            letterSpacing: 2,
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

  /// Restart and Exit Game only. A real-time game has no discrete last
  /// move, so Revert is left out rather than shown disabled
  /// (AGENTS.md §10.1.3).
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

/// The table itself: deck, markings and goals. Everything here is fixed
/// furniture, so it only repaints when the table is resized.
class _TablePainter extends CustomPainter {
  const _TablePainter({
    required this.geometry,
    required this.deck,
    required this.marking,
    required this.blue,
    required this.red,
    required this.outline,
    required this.netRecess,
  });

  final _TableGeometry geometry;
  final Color deck;
  final Color marking;
  final Color blue;
  final Color red;
  final Color outline;

  /// The timber the netting is strung on: the rail colour, lightened,
  /// so the mouth reads as part of the frame rather than the deck.
  final Color netRecess;

  @override
  void paint(Canvas canvas, Size size) {
    _paintDeck(canvas, size);
    _paintMarkings(canvas, size);
    _paintGoals(canvas, size);
  }

  void _paintDeck(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = deck);
  }

  void _paintMarkings(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = marking
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, geometry.lengthToScreen(0.009));

    final midY = geometry.lengthToScreen(AirHockeyGame.tableHeight / 2);

    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), ink);
    canvas.drawCircle(
      Offset(size.width / 2, midY),
      geometry.lengthToScreen(0.14),
      ink,
    );
    canvas.drawCircle(
      Offset(size.width / 2, midY),
      geometry.lengthToScreen(0.03),
      Paint()..color = marking,
    );

    // A blue line either side of the centre, the way a rink is marked.
    // Finer than the red ink: these are there to be read, not to
    // compete with the centre line.
    final blueInk = Paint()
      ..color = blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, geometry.lengthToScreen(0.006));
    for (final y in const [0.7, 1.3]) {
      final at = geometry.lengthToScreen(y);
      canvas.drawLine(Offset(0, at), Offset(size.width, at), blueInk);
    }

    // Two face-off circles in each half, like the photo, sitting wide.
    for (final spot in const [
      (0.22, 0.42),
      (0.78, 0.42),
      (0.22, 1.58),
      (0.78, 1.58),
    ]) {
      final centre = geometry.toScreen(spot.$1, spot.$2);
      canvas.drawCircle(centre, geometry.lengthToScreen(0.085), ink);
      canvas.drawCircle(
        centre,
        geometry.lengthToScreen(0.015),
        Paint()..color = marking,
      );
    }

    // The crease arc in front of each goal, bulging into the table.
    // Wider than the goal mouth on purpose: at the same width its ends
    // landed exactly on the posts and the two markings read as one.
    for (final (y, startAngle) in [
      (0.0, 0.0),
      (AirHockeyGame.tableHeight, math.pi),
    ]) {
      final rect = Rect.fromCircle(
        center: geometry.toScreen(AirHockeyGame.tableWidth / 2, y),
        radius: geometry.lengthToScreen(0.25),
      );
      canvas.drawArc(rect, startAngle, math.pi, false, ink);
    }
  }

  void _paintGoals(Canvas canvas, Size size) {
    final mouth = geometry.lengthToScreen(AirHockeyGame.goalHalfWidth * 2);
    final depth = geometry.lengthToScreen(0.058);
    final left = (size.width - mouth) / 2;

    // Each goal is painted in the colour of the player defending it, so
    // you can see at a glance which end is yours to protect.
    _paintNet(canvas, Rect.fromLTWH(left, 0, mouth, depth), red);
    _paintNet(
      canvas,
      Rect.fromLTWH(left, size.height - depth, mouth, depth),
      blue,
    );

    final post = Paint()..color = outline;
    final postRadius = math.max(2.5, geometry.lengthToScreen(0.014));
    for (final y in [0.0, size.height]) {
      canvas.drawCircle(Offset(left, y), postRadius, post);
      canvas.drawCircle(Offset(left + mouth, y), postRadius, post);
    }
  }

  /// One goal: a peach recess the colour of the rails, a white mesh
  /// strung across it, and a frame in the colour of whoever is
  /// defending it.
  ///
  /// Netting on the same timber as the surround is what makes it read
  /// as a goal cut into the table rather than a coloured bar painted
  /// on the deck; the frame is what still tells each player which end
  /// is theirs.
  void _paintNet(Canvas canvas, Rect goal, Color colour) {
    canvas.drawRect(goal, Paint()..color = netRecess);

    final mesh = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, geometry.lengthToScreen(0.004));

    const columns = 7;
    const rows = 2;
    for (var i = 1; i < columns; i++) {
      final x = goal.left + (goal.width * i / columns);
      canvas.drawLine(Offset(x, goal.top), Offset(x, goal.bottom), mesh);
    }
    for (var i = 1; i < rows; i++) {
      final y = goal.top + (goal.height * i / rows);
      canvas.drawLine(Offset(goal.left, y), Offset(goal.right, y), mesh);
    }

    canvas.drawRect(
      goal,
      Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.5, geometry.lengthToScreen(0.011)),
    );
  }

  @override
  bool shouldRepaint(_TablePainter oldDelegate) =>
      oldDelegate.geometry.scale != geometry.scale ||
      oldDelegate.deck != deck ||
      oldDelegate.marking != marking ||
      oldDelegate.blue != blue ||
      oldDelegate.red != red;
}

/// A puck or a mallet: a disc with a chunky outline, a soft shadow and a
/// cartoon highlight, plus a knob on top if it is a mallet.
class _BodyPainter extends CustomPainter {
  const _BodyPainter({
    required this.radius,
    required this.colour,
    required this.outline,
    required this.knobColour,
  });

  /// How much bigger than the body its box has to be. The shadow sits
  /// just below the body, and anything past this is cut off.
  static const double boxFactor = 2.8;

  /// Told rather than derived from the box, so the two cannot drift
  /// apart when the box is resized to make room for a bigger shadow.
  final double radius;

  final Color colour;
  final Color outline;

  /// `null` for the puck, which has no knob to grip.
  final Color? knobColour;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);

    // A quiet drop shadow, just enough to lift the body off the deck.
    // The thing that should read as speed is the streak behind the
    // puck, not this.
    canvas.drawCircle(
      centre.translate(0, radius * 0.3),
      radius * 1.02,
      Paint()..color = Colors.black.withValues(alpha: 0.32),
    );
    canvas.drawCircle(centre, radius, Paint()..color = colour);
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, radius * 0.14),
    );

    // The knob is kept to a smaller share of a bigger striker, so what
    // grows is the coloured ring a player actually aims with.
    final knob = knobColour;
    if (knob != null) {
      canvas.drawCircle(centre, radius * 0.4, Paint()..color = knob);
      canvas.drawCircle(
        centre,
        radius * 0.4,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, radius * 0.08),
      );
    }

    // Lit from up and to the left, like the rest of the platform's art.
    canvas.drawCircle(
      centre.translate(-radius * 0.3, -radius * 0.34),
      radius * (knob == null ? 0.24 : 0.14),
      Paint()..color = Colors.white.withValues(alpha: 0.42),
    );
  }

  @override
  bool shouldRepaint(_BodyPainter oldDelegate) =>
      oldDelegate.colour != colour ||
      oldDelegate.outline != outline ||
      oldDelegate.knobColour != knobColour;
}

/// The little colour swatch beside a number in the score chip, so the
/// count is tied to a player by more than position.
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

/// The streak a moving puck drags behind it.
///
/// A line of ghosts rather than one tapered shape: each is the puck as
/// it was a moment ago, smaller and fainter the further back it is, so
/// the streak grows and shrinks with the puck's own speed without any
/// history having to be kept.
class _TrailPainter extends CustomPainter {
  const _TrailPainter({
    required this.puck,
    required this.geometry,
    required this.colour,
  });

  final PuckBody puck;
  final _TableGeometry geometry;
  final Color colour;

  /// Below this the puck is only drifting, and a streak would be noise.
  static const double minSpeed = 0.35;

  static const int _ghosts = 8;

  /// How far the streak reaches behind a puck at full tilt, in puck
  /// radii.
  static const double _reachInRadii = 5.5;

  @override
  void paint(Canvas canvas, Size size) {
    final speed = puck.speed;
    if (speed < minSpeed) return;

    final strength =
        ((speed - minSpeed) / (AirHockeyGame.maxPuckSpeed - minSpeed))
            .clamp(0.0, 1.0);

    final radius = geometry.lengthToScreen(AirHockeyGame.puckRadius);
    final centre = geometry.toScreen(puck.x, puck.y);
    // Straight back down the line it came in on.
    final back = Offset(-puck.vx / speed, -puck.vy / speed);
    final reach = radius * _reachInRadii * strength;

    for (var i = 1; i <= _ghosts; i++) {
      final along = i / _ghosts;
      canvas.drawCircle(
        centre + (back * (reach * along)),
        radius * (1 - (0.55 * along)),
        Paint()
          ..color = colour.withValues(alpha: 0.42 * strength * (1 - along)),
      );
    }
  }

  @override
  bool shouldRepaint(_TrailPainter oldDelegate) => true;
}
