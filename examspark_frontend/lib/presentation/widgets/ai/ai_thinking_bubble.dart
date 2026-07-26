import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Professional “AI thinking” bubble for Home AI + Ask AI (while HTTP/SSE waits).
///
/// Soft brain icon + ring fill — not edu-app dots. Same widget everywhere.
class AiThinkingBubble extends StatefulWidget {
  const AiThinkingBubble({super.key});

  @override
  State<AiThinkingBubble> createState() => _AiThinkingBubbleState();
}

class _AiThinkingBubbleState extends State<AiThinkingBubble>
    with TickerProviderStateMixin {
  late final AnimationController _ring;
  late final AnimationController _pulse;
  late final AnimationController _phrase;

  static const _phrases = <String>[
    'Understanding your question…',
    'Reasoning carefully…',
    'Preparing a clear answer…',
  ];

  int _phraseIndex = 0;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _phrase = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _phraseIndex = (_phraseIndex + 1) % _phrases.length;
          });
          _phrase
            ..reset()
            ..forward();
        }
      });
    _phrase.forward();
  }

  @override
  void dispose() {
    _ring.dispose();
    _pulse.dispose();
    _phrase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secondary = AppTheme.getSecondaryText(context);
    final border = AppTheme.getCardBorder(context);
    final card = AppTheme.getCardBackground(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(MediaQuery.sizeOf(context).width * 0.88, 340),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_ring, _pulse]),
                builder: (context, _) {
                  final pulse = 0.88 + 0.12 * _pulse.value;
                  return Transform.scale(
                    scale: pulse,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CustomPaint(
                        painter: _BrainRingPainter(
                          progress: _ring.value,
                          accent: AppTheme.accentColor,
                          track: border,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.psychology_outlined,
                            size: 20,
                            color: AppTheme.accentColor.withValues(
                              alpha: 0.55 + 0.45 * _pulse.value,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _phrase,
                      builder: (context, _) {
                        // Soft fade in first half, hold, fade out last quarter.
                        final t = _phrase.value;
                        double opacity;
                        if (t < 0.12) {
                          opacity = t / 0.12;
                        } else if (t > 0.82) {
                          opacity = (1 - t) / 0.18;
                        } else {
                          opacity = 1;
                        }
                        return Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: Text(
                            _phrases[_phraseIndex],
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.25,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.getPrimaryText(context),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    // Thin fill-up bar — feels like “intelligence loading”.
                    AnimatedBuilder(
                      animation: _ring,
                      builder: (context, _) {
                        // Sweep 15% → 92% then reset (never fake 100%).
                        final fill = 0.15 + (_ring.value * 0.77);
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: fill,
                            minHeight: 3,
                            backgroundColor: border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.accentColor.withValues(alpha: 0.85),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sonaxia AI',
                      style: TextStyle(
                        fontSize: 11,
                        color: secondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft ring that fills around the brain icon.
class _BrainRingPainter extends CustomPainter {
  _BrainRingPainter({
    required this.progress,
    required this.accent,
    required this.track,
  });

  final double progress;
  final Color accent;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 1.5;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    // Sweep almost full circle, looping.
    final sweep = (0.18 + progress * 0.72) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BrainRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.track != track;
  }
}
