import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Compact AI thinking bubble — small, black/white, no heavy orbit animation.
class AiThinkingBubble extends StatefulWidget {
  const AiThinkingBubble({super.key});

  @override
  State<AiThinkingBubble> createState() => _AiThinkingBubbleState();
}

class _AiThinkingBubbleState extends State<AiThinkingBubble>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _bar;
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

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _bar = AnimationController(
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
    _pulse.dispose();
    _bar.dispose();
    _phrase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = AppTheme.getSecondaryText(context);
    final border = AppTheme.getCardBorder(context);
    final card = AppTheme.getCardBackground(context);
    final primary = AppTheme.getPrimaryText(context);

    // Black/white — dark on light bg, light on dark bg
    final dotColor = isDark ? Colors.white70 : Colors.black54;
    final barColor = isDark ? Colors.white60 : Colors.black38;

    return Align(
      alignment: Alignment.centerLeft,
      child: IntrinsicWidth(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Three pulsing dots — replaces heavy orbit animation
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  return _ThinkingDots(pulse: _pulse.value, color: dotColor);
                },
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rotating phrase
                  AnimatedBuilder(
                    animation: _phrase,
                    builder: (context, _) {
                      final t = _phrase.value;
                      double opacity;
                      if (t < 0.14) {
                        opacity = t / 0.14;
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
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: primary,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 5),
                  // Progress bar — neutral black/white
                  AnimatedBuilder(
                    animation: _bar,
                    builder: (context, _) {
                      final fill = 0.2 + (_bar.value * 0.65);
                      return SizedBox(
                        width: 140,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: fill,
                            minHeight: 2.5,
                            backgroundColor: border,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(barColor),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sonaxia AI',
                    style: TextStyle(
                      fontSize: 10,
                      color: secondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three small staggered pulsing dots.
class _ThinkingDots extends StatelessWidget {
  final double pulse;
  final Color color;

  const _ThinkingDots({required this.pulse, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final offset = ((pulse + i * 0.33) % 1.0).clamp(0.0, 1.0);
        final size = 5.0 + offset * 2.5;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.35 + offset * 0.55),
            ),
          ),
        );
      }),
    );
  }
}
