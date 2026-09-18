import 'dart:async';
import 'package:flutter/material.dart';

/// Result type enum for game outcomes.
enum GameResultType {
  blueWin,
  redWin,
  draw,
}

/// Structured data object for passing result information to [GameResultScreen].
class GameResultData {
  final String title;
  final Color backgroundColor;
  final GameResultType resultType;
  final int autoExitSeconds;

  const GameResultData({
    required this.title,
    required this.backgroundColor,
    required this.resultType,
    this.autoExitSeconds = 3,
  });

  /// Factory for Player 1 / Blue win result.
  factory GameResultData.blueWin({String label = 'BLUE PLAYER\nWINS!'}) {
    return GameResultData(
      title: label,
      backgroundColor: const Color(0xFF00ACF8),
      resultType: GameResultType.blueWin,
    );
  }

  /// Factory for a Red player win result.
  ///
  /// Bot matches can supply their participant-specific label explicitly.
  factory GameResultData.redWin({String label = 'RED PLAYER\nWINS!'}) {
    return GameResultData(
      title: label,
      backgroundColor: const Color(0xFFFF5E57),
      resultType: GameResultType.redWin,
    );
  }

  /// Factory for Draw result.
  factory GameResultData.draw({String label = 'DRAW'}) {
    return GameResultData(
      title: label,
      backgroundColor: const Color(0xFF8E9AAF),
      resultType: GameResultType.draw,
    );
  }
}

/// Dedicated, celebratory full-screen Game Result Screen matching the exact design specification.
class GameResultScreen extends StatefulWidget {
  final GameResultData resultData;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;

  const GameResultScreen({
    super.key,
    required this.resultData,
    required this.onPlayAgain,
    required this.onExit,
  });

  /// Pushes the result screen as a smooth page route over the gameplay screen.
  static Future<void> show(
    BuildContext context, {
    required GameResultData resultData,
    required VoidCallback onPlayAgain,
    required VoidCallback onExit,
  }) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => GameResultScreen(
          resultData: resultData,
          onPlayAgain: onPlayAgain,
          onExit: onExit,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  State<GameResultScreen> createState() => _GameResultScreenState();
}

class _GameResultScreenState extends State<GameResultScreen> {
  late int _remainingSeconds;
  Timer? _countdownTimer;
  bool _actionHandled = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.resultData.autoExitSeconds;
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _handleExit();
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  void _cancelTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _handlePlayAgain() {
    if (_actionHandled) return;
    _actionHandled = true;
    _cancelTimer();
    Navigator.of(context).pop();
    widget.onPlayAgain();
  }

  void _handleExit() {
    if (_actionHandled) return;
    _actionHandled = true;
    _cancelTimer();
    Navigator.of(context).pop();
    widget.onExit();
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.resultData;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleExit();
      },
      child: Scaffold(
        backgroundColor: result.backgroundColor,
        body: Stack(
          children: [
            // ── Background Confetti Particles ──────────────────────────
            Positioned.fill(
              child: CustomPaint(
                painter: _ConfettiPainter(),
              ),
            ),

            // ── Main Celebratory Content ───────────────────────────────
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Crown & Disc Avatar
                      _buildAvatar(result.resultType),

                      const SizedBox(height: 10),

                      // Title
                      Text(
                        result.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 3-Second Circular Countdown Badge
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2.5,
                          ),
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        child: Text(
                          '$_remainingSeconds',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Action Buttons (Play Again / Exit)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Column(
                          children: [
                            // PLAY AGAIN (Yellow Pill Button)
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _handlePlayAgain,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFCA28), // Bright Sunny Yellow
                                  foregroundColor: const Color(0xFF0D2F62), // Dark Navy Blue Text
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: const Text(
                                  'PLAY AGAIN',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // EXIT (Outlined Pill Button)
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton(
                                onPressed: _handleExit,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white, width: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                                ),
                                child: const Text(
                                  'EXIT',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the celebratory crown & disc avatar.
  Widget _buildAvatar(GameResultType type) {
    if (type == GameResultType.draw) {
      // Overlapping Blue & Red Discs for Draw
      return SizedBox(
        width: 110,
        height: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 14,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF00ACF8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 14,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5E57),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isBlue = type == GameResultType.blueWin;
    final discColor = isBlue ? const Color(0xFF00ACF8) : const Color(0xFFFF5E57);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Golden Cartoon Crown
        const Icon(
          Icons.emoji_events_rounded,
          color: Color(0xFFFFD54F),
          size: 34,
        ),
        const SizedBox(height: 2),

        // Glowing Hero Disc
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: discColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom painter for festive background confetti particles.
class _ConfettiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final confetti = [
      // Left side confetti
      (Offset(size.width * 0.12, size.height * 0.25), 6.0, const Color(0xFFFFD54F)),
      (Offset(size.width * 0.08, size.height * 0.55), 8.0, Colors.white),
      (Offset(size.width * 0.16, size.height * 0.75), 5.0, const Color(0xFFFF8A80)),
      (Offset(size.width * 0.22, size.height * 0.35), 7.0, const Color(0xFF80D8FF)),

      // Right side confetti
      (Offset(size.width * 0.88, size.height * 0.22), 7.0, Colors.white),
      (Offset(size.width * 0.82, size.height * 0.52), 6.0, const Color(0xFFFFD54F)),
      (Offset(size.width * 0.92, size.height * 0.72), 8.0, const Color(0xFF80D8FF)),
      (Offset(size.width * 0.78, size.height * 0.38), 5.0, const Color(0xFFFF8A80)),
    ];

    for (final item in confetti) {
      final paint = Paint()..color = item.$3.withValues(alpha: 0.7);
      canvas.drawCircle(item.$1, item.$2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
