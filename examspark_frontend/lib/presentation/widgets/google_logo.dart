import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Google's four-colour "G" mark, drawn with [CustomPainter] so the app
/// doesn't need an image asset or an extra icon-font dependency just for
/// the "Continue with Google" button.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.24;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, _deg(-40), _deg(100), false, ringPaint..color = _blue);
    canvas.drawArc(rect, _deg(60), _deg(85), false, ringPaint..color = _green);
    canvas.drawArc(rect, _deg(145), _deg(75), false, ringPaint..color = _yellow);
    canvas.drawArc(rect, _deg(220), _deg(100), false, ringPaint..color = _red);

    final barPaint = Paint()..color = _blue;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - strokeWidth / 2,
        radius + strokeWidth / 2,
        strokeWidth,
      ),
      barPaint,
    );
  }

  double _deg(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
