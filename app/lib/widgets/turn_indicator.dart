import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/game_definition.dart';

/// Visual + state data for one player's entry in a [TurnIndicatorOverlay].
///
/// Intentionally minimal: only what the indicator needs to render. Player
/// identity rules and color assignment stay in the game screen; this widget
/// only draws what it is told.
@immutable
class TurnIndicatorSpec {
  final Color color;
  final String label;
  final bool isActive;

  const TurnIndicatorSpec({
    required this.color,
    required this.label,
    required this.isActive,
  });
}

/// Reusable, game-agnostic turn indicator system.
///
/// The physical placement of the indicator(s) is driven entirely by
/// [layout], which a game selects via its `GameDefinition.turnIndicatorLayout`
/// based on its `GameDefinition.localInteractionType` (see AGENTS.md
/// §10.1.4 / §10.1.6). Individual game screens must not hardcode their own
/// indicator positioning; they configure this widget instead.
///
/// Meant to be placed with `Positioned.fill` inside a game's own root
/// [Stack], above the board layer. The indicator is purely informational and
/// never intercepts touches, so it can safely float over other content
/// without blocking gameplay taps underneath it.
class TurnIndicatorOverlay extends StatelessWidget {
  final TurnIndicatorLayout layout;
  final TurnIndicatorSpec first;
  final TurnIndicatorSpec second;
  final bool isGameOver;

  const TurnIndicatorOverlay({
    super.key,
    required this.layout,
    required this.first,
    required this.second,
    this.isGameOver = false,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return switch (layout) {
            TurnIndicatorLayout.sideBySide => _SideBySideIndicators(
                first: first,
                second: second,
                isGameOver: isGameOver,
                availableSize: size,
              ),
            TurnIndicatorLayout.passAndPlay => _PassAndPlayIndicator(
                active: first.isActive ? first : second,
                isGameOver: isGameOver,
                availableSize: size,
              ),
            TurnIndicatorLayout.faceToFace => _FaceToFaceIndicators(
                first: first,
                second: second,
                isGameOver: isGameOver,
                availableSize: size,
              ),
          };
        },
      ),
    );
  }
}

/// Shared label style for the curved corner badge.
TextStyle _cornerLabelStyle(double fontSize) => TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w900,
      fontSize: fontSize,
      height: 1.08,
      letterSpacing: 0.5,
    );

/// Side By Side.
///
/// Two mirrored quarter-circle badges anchored to the bottom corners, one per
/// player's own left/right side. Only the active player's badge is shown.
/// Sizing is derived from the label content itself so the shape stays tight
/// around its text instead of claiming a fixed, oversized slice of the
/// screen.
class _SideBySideIndicators extends StatelessWidget {
  final TurnIndicatorSpec first;
  final TurnIndicatorSpec second;
  final bool isGameOver;
  final Size availableSize;

  const _SideBySideIndicators({
    required this.first,
    required this.second,
    required this.isGameOver,
    required this.availableSize,
  });

  static const double _horizontalInset = 12.0;
  static const double _bottomInset = 10.0;
  static const double _edgeMargin = 14.0;
  static const double _minRadius = 60.0;

  /// The smallest square radius whose quarter-circle can hold [label] (given
  /// [textWidth] as the wrap width) without its far corner poking outside
  /// the curved edge.
  double _fitRadius(String label, double fontSize, double textWidth) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _cornerLabelStyle(fontSize)),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: textWidth);

    final farX = _horizontalInset + textWidth;
    final farY = _bottomInset + painter.height;
    return math.sqrt((farX * farX) + (farY * farY)) + _edgeMargin;
  }

  @override
  Widget build(BuildContext context) {
    final shortSide = math.min(availableSize.width, availableSize.height);
    final fontSize = (shortSide * 0.045).clamp(16.0, 22.0);
    final textWidth = fontSize * 4.2;

    // Both badges share one radius so the mirrored shapes stay symmetric
    // regardless of which label happens to be longer.
    final contentRadius = math.max(
      _fitRadius(first.label, fontSize, textWidth),
      _fitRadius(second.label, fontSize, textWidth),
    );
    // Never let the two corner badges grow large enough to touch each other,
    // even momentarily while one slides in as the other slides out.
    final ceiling = math.min(
      (availableSize.width / 2) - 8,
      shortSide * 0.34,
    );
    final radius = contentRadius
        .clamp(_minRadius, math.max(_minRadius, ceiling))
        .toDouble();

    return Stack(
      children: [
        Positioned(
          left: 0,
          bottom: 0,
          child: _CornerBadge(
            spec: first,
            isLeft: true,
            isVisible: !isGameOver && first.isActive,
            radius: radius,
            fontSize: fontSize,
            textWidth: textWidth,
            horizontalInset: _horizontalInset,
            bottomInset: _bottomInset,
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: _CornerBadge(
            spec: second,
            isLeft: false,
            isVisible: !isGameOver && second.isActive,
            radius: radius,
            fontSize: fontSize,
            textWidth: textWidth,
            horizontalInset: _horizontalInset,
            bottomInset: _bottomInset,
          ),
        ),
      ],
    );
  }
}

class _CornerBadge extends StatelessWidget {
  final TurnIndicatorSpec spec;
  final bool isLeft;
  final bool isVisible;
  final double radius;
  final double fontSize;
  final double textWidth;
  final double horizontalInset;
  final double bottomInset;

  const _CornerBadge({
    required this.spec,
    required this.isLeft,
    required this.isVisible,
    required this.radius,
    required this.fontSize,
    required this.textWidth,
    required this.horizontalInset,
    required this.bottomInset,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutBack,
      offset: isVisible
          ? Offset.zero
          : (isLeft ? const Offset(-1.2, 0) : const Offset(1.2, 0)),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isVisible ? 1.0 : 0.0,
        child: SizedBox(
          width: radius,
          height: radius,
          child: CustomPaint(
            painter: _CornerArcPainter(
              fillColor: spec.color,
              borderColor: Colors.white,
              borderWidth: 3.0,
              isLeft: isLeft,
            ),
            child: Align(
              alignment: isLeft ? Alignment.bottomLeft : Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.only(
                  left: isLeft ? horizontalInset : 0,
                  right: isLeft ? 0 : horizontalInset,
                  bottom: bottomInset,
                ),
                child: SizedBox(
                  width: textWidth,
                  child: Text(
                    spec.label,
                    textAlign: isLeft ? TextAlign.left : TextAlign.right,
                    softWrap: true,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _cornerLabelStyle(fontSize),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter that draws a quarter-circle side badge anchored to a bottom
/// corner, with a smooth curved white border along the arc. Left and right
/// variants are mirrored.
class _CornerArcPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final bool isLeft;

  const _CornerArcPainter({
    required this.fillColor,
    required this.borderColor,
    required this.borderWidth,
    required this.isLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width, size.height);
    // Anchored at the bottom corner of its own player side, and mirrored
    // between the two sides.
    final corner =
        isLeft ? Offset(0, size.height) : Offset(size.width, size.height);
    final arcRect = Rect.fromCircle(center: corner, radius: radius);
    // Left: sweeps from straight up round to along the bottom edge.
    // Right: sweeps from along the bottom edge round to straight up.
    final startAngle = isLeft ? -math.pi / 2 : math.pi;
    const sweepAngle = math.pi / 2;

    final quarter = Path()
      ..moveTo(corner.dx, corner.dy)
      ..arcTo(arcRect, startAngle, sweepAngle, false)
      ..close();
    canvas.drawPath(
      quarter,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );

    final arc = Path()..addArc(arcRect, startAngle, sweepAngle);
    canvas.drawPath(
      arc,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerArcPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.isLeft != isLeft;
  }
}

/// Face To Face.
///
/// Players positioned opposite each other: one near the bottom of the
/// layout, one near the top. Each gets their own semi-circular badge on
/// their own edge (bottom badge bulges up from the bottom edge, top badge
/// bulges down from the top edge — mirroring how the side-by-side corner
/// badges mirror left/right). Only the active player's badge is shown.
///
/// By convention (see AGENTS.md §10.1.2), [first] is the near/local player
/// and renders at the bottom; [second] is the far/opponent player and
/// renders at the top.
class _FaceToFaceIndicators extends StatelessWidget {
  final TurnIndicatorSpec first;
  final TurnIndicatorSpec second;
  final bool isGameOver;
  final Size availableSize;

  const _FaceToFaceIndicators({
    required this.first,
    required this.second,
    required this.isGameOver,
    required this.availableSize,
  });

  @override
  Widget build(BuildContext context) {
    final shortSide = math.min(availableSize.width, availableSize.height);
    final height = (shortSide * 0.14).clamp(52.0, 76.0);
    final fontSize = (height * 0.32).clamp(16.0, 22.0);

    // Both badges share one width, sized to fit whichever label is longer,
    // so the mirrored shapes stay symmetric regardless of text length.
    final longerLabel =
        first.label.length >= second.label.length ? first.label : second.label;
    final painter = TextPainter(
      text: TextSpan(text: longerLabel, style: _cornerLabelStyle(fontSize)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width =
        (painter.width + 56).clamp(120.0, availableSize.width * 0.7);

    return Stack(
      children: [
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Center(
            child: _EdgeBadge(
              spec: first,
              isVisible: !isGameOver && first.isActive,
              atTop: false,
              width: width,
              height: height,
              fontSize: fontSize,
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: _EdgeBadge(
              spec: second,
              isVisible: !isGameOver && second.isActive,
              atTop: true,
              width: width,
              height: height,
              fontSize: fontSize,
            ),
          ),
        ),
      ],
    );
  }
}

class _EdgeBadge extends StatelessWidget {
  final TurnIndicatorSpec spec;
  final bool isVisible;
  final bool atTop;
  final double width;
  final double height;
  final double fontSize;

  const _EdgeBadge({
    required this.spec,
    required this.isVisible,
    required this.atTop,
    required this.width,
    required this.height,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutBack,
      offset: isVisible ? Offset.zero : Offset(0, atTop ? -1.2 : 1.2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isVisible ? 1.0 : 0.0,
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: spec.color,
            borderRadius: atTop
                ? BorderRadius.vertical(bottom: Radius.circular(height))
                : BorderRadius.vertical(top: Radius.circular(height)),
            border: const Border.fromBorderSide(
              BorderSide(color: Colors.white, width: 3),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            spec.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _cornerLabelStyle(fontSize),
          ),
        ),
      ),
    );
  }
}

/// Pass & Play.
///
/// A single bottom-center badge that always tracks the current player,
/// rather than a fixed screen side. Neither player owns a permanent
/// position, matching the phone being physically handed between them.
class _PassAndPlayIndicator extends StatelessWidget {
  final TurnIndicatorSpec active;
  final bool isGameOver;
  final Size availableSize;

  const _PassAndPlayIndicator({
    required this.active,
    required this.isGameOver,
    required this.availableSize,
  });

  @override
  Widget build(BuildContext context) {
    if (isGameOver) return const SizedBox.shrink();

    final shortSide = math.min(availableSize.width, availableSize.height);
    final height = (shortSide * 0.14).clamp(52.0, 76.0);
    final fontSize = (height * 0.32).clamp(16.0, 22.0);

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                color: active.color,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(height)),
                border: const Border.fromBorderSide(
                  BorderSide(color: Colors.white, width: 3),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                active.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: fontSize,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
