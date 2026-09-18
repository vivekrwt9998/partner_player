import 'dart:async';
import 'package:flutter/material.dart';

/// Result type enum for game outcomes.
enum GameResultType {
  win,
  draw,
}

/// Structured data object for passing result information to [GameResultScreen].
class GameResultData {
  final String title;
  final Color backgroundColor;
  final IconData icon;
  final GameResultType resultType;
  final int autoExitSeconds;

  const GameResultData({
    required this.title,
    required this.backgroundColor,
    required this.icon,
    this.resultType = GameResultType.win,
    this.autoExitSeconds = 3,
  });

  /// Factory for Player 1 / Blue win result.
  factory GameResultData.blueWin({String label = 'BLUE PLAYER WINS'}) {
    return GameResultData(
      title: label,
      backgroundColor: const Color(0xFF00ACF8),
      icon: Icons.emoji_events_rounded,
      resultType: GameResultType.win,
    );
  }

  /// Factory for Player 2 / Red win result.
  factory GameResultData.redWin({String label = 'RED PLAYER WINS'}) {
    return GameResultData(
      title: label,
      backgroundColor: const Color(0xFFFF5E57),
      icon: Icons.emoji_events_rounded,
      resultType: GameResultType.win,
    );
  }

  /// Factory for Draw result.
  factory GameResultData.draw({String label = 'DRAW'}) {
    return GameResultData(
      title: label,
      backgroundColor: const Color(0xFF546E7A),
      icon: Icons.handshake_rounded,
      resultType: GameResultType.draw,
    );
  }
}

/// Dedicated, full-screen celebratory Game Result Screen.
///
/// Centralized and reusable across all games on the platform.
/// Displays winner identity/theme, celebratory iconography, action buttons
/// (Play Again, Exit), and a safe 3-second auto-exit countdown.
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
        transitionDuration: const Duration(milliseconds: 350),
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
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Celebratory Trophy / Handshake Icon ──────────────────
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      result.icon,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Result Title ──────────────────────────────────────────
                  Text(
                    result.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
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

                  const SizedBox(height: 10),

                  // ── Auto Exit Countdown Badge ─────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'Auto exit in $_remainingSeconds',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── Action Buttons ────────────────────────────────────────
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Exit / Back Button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _handleExit,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: const BorderSide(color: Colors.white, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: Colors.white.withValues(alpha: 0.12),
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

                        const SizedBox(width: 16),

                        // Play Again Button
                        Expanded(
                          child: FilledButton(
                            onPressed: _handlePlayAgain,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              backgroundColor: Colors.white,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'PLAY AGAIN',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: result.backgroundColor,
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
      ),
    );
  }
}
