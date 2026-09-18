import 'dart:async';
import 'package:flutter/material.dart';

/// Reusable Game Result dialog/screen component with automatic exit countdown.
///
/// Designed for 2-player games across the platform.
class GameResultDialog extends StatefulWidget {
  final String title;
  final Color themeColor;
  final IconData icon;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;
  final int autoExitSeconds;

  const GameResultDialog({
    super.key,
    required this.title,
    required this.themeColor,
    required this.icon,
    required this.onPlayAgain,
    required this.onExit,
    this.autoExitSeconds = 3,
  });

  /// Helper to show this result dialog as a modal over the game screen.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required Color themeColor,
    required IconData icon,
    required VoidCallback onPlayAgain,
    required VoidCallback onExit,
    int autoExitSeconds = 3,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GameResultDialog(
        title: title,
        themeColor: themeColor,
        icon: icon,
        onPlayAgain: onPlayAgain,
        onExit: onExit,
        autoExitSeconds: autoExitSeconds,
      ),
    );
  }

  @override
  State<GameResultDialog> createState() => _GameResultDialogState();
}

class _GameResultDialogState extends State<GameResultDialog> {
  late int _remainingSeconds;
  Timer? _countdownTimer;
  bool _actionHandled = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.autoExitSeconds;
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
    Navigator.of(context, rootNavigator: true).pop();
    widget.onPlayAgain();
  }

  void _handleExit() {
    if (_actionHandled) return;
    _actionHandled = true;
    _cancelTimer();
    Navigator.of(context, rootNavigator: true).pop();
    widget.onExit();
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleExit();
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 12,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Trophy / Result Icon ──────────────────────────────────
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: widget.themeColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.themeColor.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 34,
                    color: widget.themeColor,
                  ),
                ),

                const SizedBox(height: 14),

                // ── Result Title ──────────────────────────────────────────
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: widget.themeColor,
                  ),
                ),

                const SizedBox(height: 8),

                // ── Auto Exit Countdown Badge ─────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Auto exit in $_remainingSeconds',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Action Buttons ────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _handleExit,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: const Text(
                          'Exit',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _handlePlayAgain,
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Play Again',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
