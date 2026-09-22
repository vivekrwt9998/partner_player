import 'package:flutter/material.dart';
import 'lobby_palette.dart';

/// The lobby's painted backdrop: sky, sun, a few clouds and a grassy
/// horizon. Sits behind the scrolling grid and never moves, so the cards
/// read as objects laid out on top of one scene.
class LobbyBackground extends StatelessWidget {
  const LobbyBackground({super.key});

  @override
  Widget build(BuildContext context) => const CustomPaint(
        painter: _BackgroundPainter(),
        size: Size.infinite,
        willChange: false,
        child: SizedBox.expand(),
      );
}

class _BackgroundPainter extends CustomPainter {
  const _BackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [LobbyPalette.skyTop, LobbyPalette.skyBottom],
        ).createShader(rect),
    );

    _cloud(canvas, Offset(size.width * 0.16, size.height * 0.07),
        size.width * 0.06);
    _cloud(canvas, Offset(size.width * 0.72, size.height * 0.30),
        size.width * 0.05);
    _cloud(canvas, Offset(size.width * 0.20, size.height * 0.62),
        size.width * 0.045);
    _cloud(canvas, Offset(size.width * 0.80, size.height * 0.76),
        size.width * 0.055);

    // Grassy horizon along the bottom.
    final hill = Path()
      ..moveTo(0, size.height * 0.90)
      ..quadraticBezierTo(size.width * 0.30, size.height * 0.84,
          size.width * 0.62, size.height * 0.89)
      ..quadraticBezierTo(
          size.width * 0.85, size.height * 0.92, size.width, size.height * 0.87)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    // Bushes first, so the hill covers their lower halves and only their
    // tops peek over the horizon.
    final bush = Paint()..color = LobbyPalette.grassDark;
    for (final spot in const [
      (0.08, 0.905, 0.055),
      (0.17, 0.915, 0.038),
      (0.74, 0.895, 0.048),
      (0.83, 0.905, 0.034),
    ]) {
      canvas.drawCircle(
        Offset(size.width * spot.$1, size.height * spot.$2),
        size.width * spot.$3,
        bush,
      );
    }
    canvas.drawPath(hill, Paint()..color = LobbyPalette.grass);
  }

  void _cloud(Canvas canvas, Offset centre, double radius) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawCircle(centre, radius, paint);
    canvas.drawCircle(
        centre.translate(radius * 0.95, radius * 0.18), radius * 0.7, paint);
    canvas.drawCircle(
        centre.translate(-radius * 0.95, radius * 0.22), radius * 0.6, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centre.dx - (radius * 1.6), centre.dy,
            radius * 3.2, radius * 0.9),
        Radius.circular(radius * 0.45),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) => false;
}
