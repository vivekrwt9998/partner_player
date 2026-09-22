import 'package:flutter/material.dart';
import 'lobby_palette.dart';

/// The illustrated thumbnail on a lobby card: each game's own board, drawn
/// as a little cartoon scene.
///
/// Painted rather than shipped as images. Six artwork PNGs at every screen
/// density would be by far the heaviest thing in the app for something
/// purely decorative (AGENTS.md §45), and paint stays crisp at whatever
/// size the grid gives a card.
class GameArtwork extends StatelessWidget {
  /// A `GameDefinition.id`. An unknown id draws the scene with no board on
  /// it rather than failing, so adding a game to the registry can never
  /// break the lobby.
  final String gameId;

  const GameArtwork({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _ArtworkPainter(gameId),
        size: Size.infinite,
        isComplex: true,
        willChange: false,
      );
}

// ---------------------------------------------------------------------------
// Painting
// ---------------------------------------------------------------------------

class _ArtworkPainter extends CustomPainter {
  final String gameId;

  const _ArtworkPainter(this.gameId);

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackdrop(canvas, size, ocean: gameId == 'battleship');

    switch (gameId) {
      case 'four_in_a_row':
        _paintFourInARow(canvas, size);
      case 'tic_tac_toe':
        _paintTicTacToe(canvas, size);
      case 'checkers':
        _paintCheckers(canvas, size);
      case 'tetra_tower':
        _paintTetraTower(canvas, size);
      case 'sling_puck':
        _paintSlingPuck(canvas, size);
      case 'color_war':
        _paintColorWar(canvas, size);
      case 'battleship':
        _paintBattleship(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant _ArtworkPainter oldDelegate) =>
      oldDelegate.gameId != gameId;
}

// --- shared bits -----------------------------------------------------------

Paint _fill(Color colour) => Paint()..color = colour;

Paint _line(Color colour, double width) => Paint()
  ..color = colour
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// A rounded plate with the cartoon outline round it -- the base shape every
/// board in here is built on.
void _plate(Canvas canvas, Rect rect, double radius, Color colour,
    {double outline = 0}) {
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
  canvas.drawRRect(
    rrect.shift(Offset(0, outline)),
    _fill(LobbyPalette.ink.withValues(alpha: 0.25)),
  );
  canvas.drawRRect(rrect, _fill(colour));
  if (outline > 0) {
    canvas.drawRRect(rrect, _line(LobbyPalette.ink, outline));
  }
}

/// A playing piece: flat colour, outline, and a highlight so it reads as a
/// chunky plastic disc rather than a dot.
void _disc(Canvas canvas, Offset centre, double radius, Color colour,
    {double outline = 0}) {
  canvas.drawCircle(centre, radius, _fill(colour));
  canvas.drawCircle(
    centre.translate(-radius * 0.28, -radius * 0.32),
    radius * 0.30,
    _fill(Colors.white.withValues(alpha: 0.45)),
  );
  if (outline > 0) {
    canvas.drawCircle(centre, radius, _line(LobbyPalette.ink, outline));
  }
}

void _cloud(Canvas canvas, Offset centre, double radius) {
  final paint = _fill(Colors.white.withValues(alpha: 0.85));
  canvas.drawCircle(centre, radius, paint);
  canvas.drawCircle(
      centre.translate(radius * 0.9, radius * 0.2), radius * 0.72, paint);
  canvas.drawCircle(
      centre.translate(-radius * 0.9, radius * 0.25), radius * 0.62, paint);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(centre.dx - (radius * 1.5), centre.dy + (radius * 0.1),
          radius * 3, radius * 0.9),
      Radius.circular(radius * 0.45),
    ),
    paint,
  );
}

void _paintBackdrop(Canvas canvas, Size size, {required bool ocean}) {
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: ocean
            ? const [Color(0xFF9BDBFF), Color(0xFF2E7FD0)]
            : const [LobbyPalette.skyTop, LobbyPalette.skyBottom],
      ).createShader(rect),
  );

  _cloud(canvas, Offset(size.width * 0.22, size.height * 0.16),
      size.width * 0.075);
  _cloud(canvas, Offset(size.width * 0.82, size.height * 0.10),
      size.width * 0.055);

  if (ocean) {
    final wave = _line(Colors.white.withValues(alpha: 0.45), size.width * 0.02);
    for (var row = 0; row < 3; row++) {
      final y = size.height * (0.58 + (row * 0.14));
      final path = Path()..moveTo(size.width * 0.08, y);
      for (var crest = 0; crest < 4; crest++) {
        final from = size.width * (0.08 + (crest * 0.21));
        path.quadraticBezierTo(
          from + (size.width * 0.105),
          y - (size.height * 0.05),
          from + (size.width * 0.21),
          y,
        );
      }
      canvas.drawPath(path, wave);
    }
    return;
  }

  // Rolling ground: a darker lip peeking out from under the grass.
  Path ground(double top) => Path()
    ..moveTo(0, top + (size.height * 0.05))
    ..quadraticBezierTo(
        size.width * 0.5, top - (size.height * 0.05), size.width, top)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  canvas.drawPath(ground(size.height * 0.68), _fill(LobbyPalette.grassDark));
  canvas.drawPath(ground(size.height * 0.74), _fill(LobbyPalette.grass));
}

// --- per-game scenes -------------------------------------------------------

void _paintFourInARow(Canvas canvas, Size size) {
  final board = Rect.fromCenter(
    center: Offset(size.width * 0.54, size.height * 0.44),
    width: size.width * 0.64,
    height: size.height * 0.54,
  );
  final outline = size.width * 0.022;
  _plate(canvas, board, size.width * 0.06, LobbyPalette.blue,
      outline: outline);

  const columns = 4;
  const rows = 3;
  final cell = board.width / (columns + 0.6);
  final radius = cell * 0.34;
  const filled = <int, Color>{
    1: LobbyPalette.red,
    5: LobbyPalette.cyan,
    6: LobbyPalette.red,
    9: LobbyPalette.cyan,
    10: LobbyPalette.red,
  };

  for (var row = 0; row < rows; row++) {
    for (var column = 0; column < columns; column++) {
      final centre = Offset(
        board.left + (cell * (0.8 + column)),
        board.top + (board.height * (0.24 + (row * 0.26))),
      );
      final colour = filled[(row * columns) + column];
      if (colour == null) {
        canvas.drawCircle(centre, radius, _fill(const Color(0xFF16499B)));
      } else {
        _disc(canvas, centre, radius, colour, outline: outline * 0.7);
      }
    }
  }

  // Two spares waiting on the grass.
  _disc(canvas, Offset(size.width * 0.13, size.height * 0.80),
      size.width * 0.07, LobbyPalette.red, outline: outline);
  _disc(canvas, Offset(size.width * 0.24, size.height * 0.85),
      size.width * 0.07, LobbyPalette.cyan, outline: outline);
}

void _paintTicTacToe(Canvas canvas, Size size) {
  final board = Rect.fromCenter(
    center: Offset(size.width * 0.5, size.height * 0.45),
    width: size.width * 0.60,
    height: size.width * 0.60,
  );
  final outline = size.width * 0.022;
  _plate(canvas, board, size.width * 0.06, const Color(0xFF2B6FD0),
      outline: outline);

  final grid = _line(Colors.white.withValues(alpha: 0.9), outline * 1.3);
  for (var i = 1; i < 3; i++) {
    final x = board.left + (board.width * i / 3);
    final y = board.top + (board.height * i / 3);
    canvas.drawLine(Offset(x, board.top + (board.height * 0.08)),
        Offset(x, board.bottom - (board.height * 0.08)), grid);
    canvas.drawLine(Offset(board.left + (board.width * 0.08), y),
        Offset(board.right - (board.width * 0.08), y), grid);
  }

  Offset cell(int column, int row) => Offset(
        board.left + (board.width * ((column + 0.5) / 3)),
        board.top + (board.height * ((row + 0.5) / 3)),
      );
  final mark = board.width * 0.09;

  void cross(Offset centre) {
    final pen = _line(LobbyPalette.red, outline * 1.8);
    canvas.drawLine(
        centre.translate(-mark, -mark), centre.translate(mark, mark), pen);
    canvas.drawLine(
        centre.translate(mark, -mark), centre.translate(-mark, mark), pen);
  }

  void nought(Offset centre) => canvas.drawCircle(
      centre, mark * 1.15, _line(LobbyPalette.cyan, outline * 1.8));

  cross(cell(0, 0));
  cross(cell(1, 1));
  cross(cell(0, 2));
  nought(cell(1, 0));
  nought(cell(2, 0));
  nought(cell(2, 1));
}

void _paintCheckers(Canvas canvas, Size size) {
  final frame = Rect.fromCenter(
    center: Offset(size.width * 0.5, size.height * 0.46),
    width: size.width * 0.68,
    height: size.width * 0.68,
  );
  final outline = size.width * 0.022;
  _plate(canvas, frame, size.width * 0.05, LobbyPalette.woodDark,
      outline: outline);

  final board = frame.deflate(frame.width * 0.08);
  canvas.save();
  canvas.clipRRect(
      RRect.fromRectAndRadius(board, Radius.circular(size.width * 0.02)));
  canvas.drawRect(board, _fill(LobbyPalette.cream));
  final square = board.width / 4;
  for (var row = 0; row < 4; row++) {
    for (var column = 0; column < 4; column++) {
      if ((row + column).isEven) continue;
      canvas.drawRect(
        Rect.fromLTWH(board.left + (column * square),
            board.top + (row * square), square, square),
        _fill(LobbyPalette.wood),
      );
    }
  }
  canvas.restore();

  Offset cell(int column, int row) => Offset(
        board.left + (square * (column + 0.5)),
        board.top + (square * (row + 0.5)),
      );
  final radius = square * 0.33;
  _disc(canvas, cell(1, 0), radius, LobbyPalette.navy, outline: outline * 0.8);
  _disc(canvas, cell(3, 0), radius, LobbyPalette.navy, outline: outline * 0.8);
  _disc(canvas, cell(2, 1), radius, LobbyPalette.navy, outline: outline * 0.8);
  _disc(canvas, cell(1, 2), radius, LobbyPalette.red, outline: outline * 0.8);
  _disc(canvas, cell(0, 3), radius, LobbyPalette.red, outline: outline * 0.8);
  _disc(canvas, cell(2, 3), radius, LobbyPalette.red, outline: outline * 0.8);
}

void _paintTetraTower(Canvas canvas, Size size) {
  final outline = size.width * 0.022;
  final blockWidth = size.width * 0.44;
  final blockHeight = size.height * 0.11;
  const colours = [
    LobbyPalette.red,
    LobbyPalette.sun,
    LobbyPalette.cyan,
    LobbyPalette.purple,
  ];
  // A slightly drunk stack -- each floor nudged off the one below it.
  const nudges = [0.0, 0.06, -0.05, 0.03];

  for (var floor = 0; floor < colours.length; floor++) {
    final rect = Rect.fromCenter(
      center: Offset(
        size.width * (0.5 + nudges[floor]),
        size.height * (0.74 - (floor * 0.135)),
      ),
      width: blockWidth,
      height: blockHeight,
    );
    _plate(canvas, rect, size.width * 0.03, colours[floor], outline: outline);
    // Studs, so each floor reads as a building block.
    for (var stud = 0; stud < 3; stud++) {
      canvas.drawCircle(
        Offset(rect.left + (rect.width * (0.25 + (stud * 0.25))),
            rect.top + (rect.height * 0.30)),
        rect.height * 0.14,
        _fill(Colors.white.withValues(alpha: 0.5)),
      );
    }
  }
}

void _paintSlingPuck(Canvas canvas, Size size) {
  final board = Rect.fromCenter(
    center: Offset(size.width * 0.5, size.height * 0.46),
    width: size.width * 0.44,
    height: size.height * 0.64,
  );
  final outline = size.width * 0.022;
  _plate(canvas, board, size.width * 0.05, const Color(0xFF232A33),
      outline: outline);

  // The middle wall, with the gap a puck has to thread.
  final divider = board.center.dy;
  final wall = _line(LobbyPalette.navyLight, outline * 1.4);
  canvas.drawLine(Offset(board.left + outline, divider),
      Offset(board.left + (board.width * 0.32), divider), wall);
  canvas.drawLine(Offset(board.right - (board.width * 0.32), divider),
      Offset(board.right - outline, divider), wall);

  // A band at each end.
  final band = _line(LobbyPalette.sun, outline * 0.9);
  for (final y in [
    board.top + (board.height * 0.12),
    board.bottom - (board.height * 0.12),
  ]) {
    canvas.drawLine(Offset(board.left + (board.width * 0.14), y),
        Offset(board.right - (board.width * 0.14), y), band);
  }

  final radius = board.width * 0.15;
  Offset at(double x, double y) =>
      Offset(board.left + (board.width * x), board.top + (board.height * y));
  _disc(canvas, at(0.32, 0.26), radius, LobbyPalette.red,
      outline: outline * 0.8);
  _disc(canvas, at(0.70, 0.32), radius, LobbyPalette.red,
      outline: outline * 0.8);
  _disc(canvas, at(0.50, 0.50), radius, LobbyPalette.cyan,
      outline: outline * 0.8);
  _disc(canvas, at(0.30, 0.72), radius, LobbyPalette.cyan,
      outline: outline * 0.8);
  _disc(canvas, at(0.72, 0.78), radius, LobbyPalette.cyan,
      outline: outline * 0.8);
}

void _paintColorWar(Canvas canvas, Size size) {
  final outline = size.width * 0.022;
  final board = Rect.fromCenter(
    center: Offset(size.width * 0.5, size.height * 0.45),
    width: size.width * 0.64,
    height: size.width * 0.64,
  );
  _plate(canvas, board, size.width * 0.05, const Color(0xFFF7E7D3),
      outline: outline);

  const grid = 3;
  final tile = board.width / grid;
  // Which tiles are claimed, and by whom -- a red chain mid-spread.
  const claimed = <int, Color>{
    0: LobbyPalette.red,
    1: LobbyPalette.red,
    4: LobbyPalette.red,
    5: LobbyPalette.cyan,
    7: LobbyPalette.cyan,
  };

  for (var row = 0; row < grid; row++) {
    for (var column = 0; column < grid; column++) {
      final colour = claimed[(row * grid) + column];
      if (colour == null) continue;

      final centre = Offset(
        board.left + (tile * (column + 0.5)),
        board.top + (tile * (row + 0.5)),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: centre, width: tile * 0.92, height: tile * 0.92),
          Radius.circular(tile * 0.18),
        ),
        _fill(colour.withValues(alpha: 0.22)),
      );
      _disc(canvas, centre, tile * 0.30, colour, outline: outline * 0.7);
    }
  }

  // The middle tile is going off: orbs flying out of it.
  final spark = _fill(LobbyPalette.sun);
  final centre = Offset(
    board.left + (tile * 1.5),
    board.top + (tile * 1.5),
  );
  for (final step in const [
    Offset(0, -1),
    Offset(0, 1),
    Offset(-1, 0),
    Offset(1, 0),
  ]) {
    canvas.drawCircle(
      centre + (step * tile * 0.62),
      tile * 0.12,
      spark,
    );
  }
}

void _paintBattleship(Canvas canvas, Size size) {
  final outline = size.width * 0.022;
  final hull = Path()
    ..moveTo(size.width * 0.20, size.height * 0.56)
    ..lineTo(size.width * 0.82, size.height * 0.56)
    ..lineTo(size.width * 0.70, size.height * 0.76)
    ..lineTo(size.width * 0.30, size.height * 0.76)
    ..close();
  canvas.drawPath(hull, _fill(LobbyPalette.navy));
  canvas.drawPath(hull, _line(LobbyPalette.ink, outline));

  _plate(
    canvas,
    Rect.fromLTWH(size.width * 0.38, size.height * 0.40, size.width * 0.24,
        size.height * 0.16),
    size.width * 0.02,
    LobbyPalette.cream,
    outline: outline,
  );
  _plate(
    canvas,
    Rect.fromLTWH(size.width * 0.66, size.height * 0.36, size.width * 0.09,
        size.height * 0.20),
    size.width * 0.02,
    LobbyPalette.red,
    outline: outline,
  );

  // Mast and flag.
  canvas.drawLine(
      Offset(size.width * 0.44, size.height * 0.40),
      Offset(size.width * 0.44, size.height * 0.18),
      _line(LobbyPalette.ink, outline));
  final flag = Path()
    ..moveTo(size.width * 0.44, size.height * 0.18)
    ..lineTo(size.width * 0.60, size.height * 0.23)
    ..lineTo(size.width * 0.44, size.height * 0.28)
    ..close();
  canvas.drawPath(flag, _fill(LobbyPalette.sun));
  canvas.drawPath(flag, _line(LobbyPalette.ink, outline * 0.8));
}
