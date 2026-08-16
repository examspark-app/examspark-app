import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Professional AI thinking bubble for Home AI + Ask AI.
///
/// Center:
///   📖 Open book stays stable.
///
/// Around the book:
///   🌍 Earth rotates on an outer circular orbit.
///   • Small particles travel on the same orbit.
///
/// Right:
///   Rotating AI status phrases.
///
/// Bottom:
///   Soft looping intelligence/loading bar.
class AiThinkingBubble extends StatefulWidget {
  const AiThinkingBubble({super.key});

  @override
  State<AiThinkingBubble> createState() => _AiThinkingBubbleState();
}

class _AiThinkingBubbleState extends State<AiThinkingBubble>
    with TickerProviderStateMixin {
  late final AnimationController _orbit;
  late final AnimationController _pulse;
  late final AnimationController _phrase;

  static const _phrases = <String>[
    'Understanding your question…',
    'Searching knowledge…',
    'Analyzing context…',
    'Preparing your answer…',
  ];

  int _phraseIndex = 0;

  @override
  void initState() {
    super.initState();

    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _phrase = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
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
    _orbit.dispose();
    _pulse.dispose();
    _phrase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secondary = AppTheme.getSecondaryText(context);
    final border = AppTheme.getCardBorder(context);
    final card = AppTheme.getCardBackground(context);
    final primary = AppTheme.getPrimaryText(context);
    final accent = AppTheme.accentColor;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(
            MediaQuery.sizeOf(context).width * 0.90,
            420,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_orbit, _pulse]),
                builder: (context, _) {
                  final pulse =
                      0.96 + (_pulse.value * 0.04);

                  return Transform.scale(
                    scale: pulse,
                    child: SizedBox(
                      width: 94,
                      height: 76,
                      child: CustomPaint(
                        painter: _KnowledgeOrbitPainter(
                          progress: _orbit.value,
                          accent: accent,
                          track: border,
                          glowAlpha:
                              0.14 + (_pulse.value * 0.10),
                        ),
                        child: Center(
                          child: Container(
                            width: 46,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '📖',
                              style: TextStyle(
                                fontSize: 25,
                              ),
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
                        final t = _phrase.value;

                        double opacity;
                        double slide;

                        if (t < 0.14) {
                          opacity = t / 0.14;
                          slide = 6 * (1 - opacity);
                        } else if (t > 0.82) {
                          opacity = (1 - t) / 0.18;
                          slide = 6 * (1 - opacity);
                        } else {
                          opacity = 1;
                          slide = 0;
                        }

                        return Transform.translate(
                          offset: Offset(slide, 0),
                          child: Opacity(
                            opacity: opacity.clamp(0.0, 1.0),
                            child: Text(
                              _phrases[_phraseIndex],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                                color: primary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _Dot(
                          color: accent,
                          pulse: _pulse.value,
                          size: 4,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Knowledge + reasoning',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: _orbit,
                      builder: (context, _) {
                        final raw = _orbit.value;

                        // Never shows fake 100%.
                        final fill =
                            0.18 + (raw * 0.68);

                        return ClipRRect(
                          borderRadius:
                              BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: fill,
                            minHeight: 3,
                            backgroundColor: border,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(
                              accent.withValues(alpha: 0.85),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sonaxia AI',
                      style: TextStyle(
                        fontSize: 10.5,
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

class _Dot extends StatelessWidget {
  final Color color;
  final double pulse;
  final double size;

  const _Dot({
    required this.color,
    required this.pulse,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + pulse * 1.5,
      height: size + pulse * 1.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(
          alpha: 0.55 + pulse * 0.35,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 5 + pulse * 3,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _KnowledgeOrbitPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final Color track;
  final double glowAlpha;

  _KnowledgeOrbitPainter({
    required this.progress,
    required this.accent,
    required this.track,
    required this.glowAlpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final orbitRx = size.width * 0.39;
    final orbitRy = size.height * 0.34;

    final orbitRect = Rect.fromCenter(
      center: center,
      width: orbitRx * 2,
      height: orbitRy * 2,
    );

    // Soft outer glow.
    final glowPaint = Paint()
      ..color = accent.withValues(alpha: glowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    canvas.drawOval(orbitRect, glowPaint);

    // Main orbit track.
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawOval(orbitRect, trackPaint);

    // Rotating Earth position.
    final angle =
        (-math.pi / 2) + (progress * math.pi * 2);

    final earthCenter = Offset(
      center.dx + math.cos(angle) * orbitRx,
      center.dy + math.sin(angle) * orbitRy,
    );

    // Earth glow.
    final earthGlow = Paint()
      ..color = accent.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        6,
      );

    canvas.drawCircle(
      earthCenter,
      9,
      earthGlow,
    );

    // Earth.
    final earthPaint = Paint()
      ..color = accent.withValues(alpha: 0.9);

    canvas.drawCircle(
      earthCenter,
      6,
      earthPaint,
    );

    // Simple "land" marks.
    final landPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(
        center: earthCenter.translate(-1.5, -1),
        width: 4,
        height: 2.5,
      ),
      landPaint,
    );

    canvas.drawCircle(
      earthCenter.translate(2, 2),
      1.2,
      landPaint,
    );

    // Three small orbit particles.
    for (int i = 0; i < 3; i++) {
      final particleAngle =
          angle + ((math.pi * 2 / 3) * (i + 1));

      final particleCenter = Offset(
        center.dx +
            math.cos(particleAngle) * orbitRx,
        center.dy +
            math.sin(particleAngle) * orbitRy,
      );

      final particlePaint = Paint()
        ..color = accent.withValues(
          alpha: 0.28 + (0.18 * (i + 1)),
        );

      canvas.drawCircle(
        particleCenter,
        i == 1 ? 2.2 : 1.6,
        particlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _KnowledgeOrbitPainter oldDelegate,
  ) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.track != track ||
        oldDelegate.glowAlpha != glowAlpha;
  }
}