import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Compact AI thinking bubble — book-scan animation, adaptive B/W cover.
class AiThinkingBubble extends StatefulWidget {
  const AiThinkingBubble({super.key});

  @override
  State<AiThinkingBubble> createState() => _AiThinkingBubbleState();
}

class _AiThinkingBubbleState extends State<AiThinkingBubble>
    with TickerProviderStateMixin {
  late final AnimationController _scan;
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

    _scan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

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
    _scan.dispose();
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

    // Adaptive book cover — dark cover on light bg, light cover on dark bg.
    final coverColor = isDark ? const Color(0xFFE8E6E1) : const Color(0xFF2C2C2A);
    final pageColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFDFCFA);
    final lineColor = isDark ? Colors.white24 : Colors.black26;
    final barColor = isDark ? Colors.white60 : Colors.black38;
    final scanColor = AppTheme.accentColor;

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
              _BookIcon(
                scanAnimation: _scan,
                coverColor: coverColor,
                pageColor: pageColor,
                lineColor: lineColor,
                scanColor: scanColor,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
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

/// Small realistic open-book icon with a moving scan line — mobile-sized (28px).
class _BookIcon extends StatelessWidget {
  final Animation<double> scanAnimation;
  final Color coverColor;
  final Color pageColor;
  final Color lineColor;
  final Color scanColor;

  const _BookIcon({
    required this.scanAnimation,
    required this.coverColor,
    required this.pageColor,
    required this.lineColor,
    required this.scanColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: const Size(28, 28),
            painter: _BookPainter(
              coverColor: coverColor,
              pageColor: pageColor,
              lineColor: lineColor,
            ),
          ),
          AnimatedBuilder(
            animation: scanAnimation,
            builder: (context, _) {
              // 0 → 1 loop: fade in, move down, fade out.
              final t = scanAnimation.value;
              final opacity = t < 0.1
                  ? t / 0.1
                  : t > 0.9
                      ? (1 - t) / 0.1
                      : 1.0;
              final top = 4 + (t * 16);
              return Positioned(
                left: 3,
                right: 3,
                top: top,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      color: scanColor,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: scanColor.withValues(alpha: 0.6),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BookPainter extends CustomPainter {
  final Color coverColor;
  final Color pageColor;
  final Color lineColor;

  _BookPainter({
    required this.coverColor,
    required this.pageColor,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final coverPaint = Paint()..color = coverColor;
    final pagePaint = Paint()..color = pageColor;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.6;
    final spinePaint = Paint()
      ..color = coverColor.withValues(alpha: 0.9)
      ..strokeWidth = 1.2;

    // Left cover (outer)
    final leftCover = Path()
      ..moveTo(w * 0.12, h * 0.20)
      ..cubicTo(w * 0.12, h * 0.14, w * 0.17, h * 0.12, w * 0.21, h * 0.14)
      ..lineTo(w * 0.46, h * 0.20)
      ..lineTo(w * 0.46, h * 0.84)
      ..lineTo(w * 0.21, h * 0.78)
      ..cubicTo(w * 0.17, h * 0.76, w * 0.12, h * 0.74, w * 0.12, h * 0.68)
      ..close();
    canvas.drawPath(leftCover, coverPaint);

    // Left page (inner, slightly smaller)
    final leftPage = Path()
      ..moveTo(w * 0.17, h * 0.23)
      ..cubicTo(w * 0.17, h * 0.19, w * 0.19, h * 0.17, w * 0.22, h * 0.18)
      ..lineTo(w * 0.42, h * 0.22)
      ..lineTo(w * 0.42, h * 0.80)
      ..lineTo(w * 0.22, h * 0.75)
      ..cubicTo(w * 0.19, h * 0.74, w * 0.17, h * 0.71, w * 0.17, h * 0.67)
      ..close();
    canvas.drawPath(leftPage, pagePaint);

    // Right cover (outer)
    final rightCover = Path()
      ..moveTo(w * 0.88, h * 0.20)
      ..cubicTo(w * 0.88, h * 0.14, w * 0.83, h * 0.12, w * 0.79, h * 0.14)
      ..lineTo(w * 0.54, h * 0.20)
      ..lineTo(w * 0.54, h * 0.84)
      ..lineTo(w * 0.79, h * 0.78)
      ..cubicTo(w * 0.83, h * 0.76, w * 0.88, h * 0.74, w * 0.88, h * 0.68)
      ..close();
    canvas.drawPath(rightCover, coverPaint);

    // Right page (inner)
    final rightPage = Path()
      ..moveTo(w * 0.83, h * 0.23)
      ..cubicTo(w * 0.83, h * 0.19, w * 0.81, h * 0.17, w * 0.78, h * 0.18)
      ..lineTo(w * 0.58, h * 0.22)
      ..lineTo(w * 0.58, h * 0.80)
      ..lineTo(w * 0.78, h * 0.75)
      ..cubicTo(w * 0.81, h * 0.74, w * 0.83, h * 0.71, w * 0.83, h * 0.67)
      ..close();
    canvas.drawPath(rightPage, pagePaint);

    // Text lines on pages (suggesting written content)
    for (final frac in [0.34, 0.44, 0.54]) {
      canvas.drawLine(
        Offset(w * 0.20, h * frac),
        Offset(w * 0.39, h * (frac + 0.02)),
        linePaint,
      );
      canvas.drawLine(
        Offset(w * 0.61, h * (frac + 0.02)),
        Offset(w * 0.80, h * frac),
        linePaint,
      );
    }

    // Spine
    canvas.drawLine(
      Offset(w * 0.5, h * 0.13),
      Offset(w * 0.5, h * 0.85),
      spinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BookPainter oldDelegate) {
    return oldDelegate.coverColor != coverColor ||
        oldDelegate.pageColor != pageColor ||
        oldDelegate.lineColor != lineColor;
  }
}