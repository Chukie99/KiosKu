import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

enum StampRole { kasir, toko }

class StampBadge extends StatelessWidget {
  final StampRole role;
  final double size;

  const StampBadge({
    super.key,
    required this.role,
    this.size = 64,
  });

  String get _label => role == StampRole.kasir ? 'KASIR' : 'TOKO';
  Color get _color => role == StampRole.kasir
      ? AppColors.primary
      : AppColors.accentGreen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StampPainter(color: _color),
        child: Center(
          child: Transform.rotate(
            angle: -12 * pi / 180,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label,
                  style: TextStyle(
                    fontSize: size * 0.2,
                    fontWeight: FontWeight.w900,
                    color: _color,
                    letterSpacing: 2,
                  ),
                ),
                Container(
                  width: size * 0.5,
                  height: 2,
                  color: _color.withOpacity(0.6),
                ),
                Text(
                  'KiosKu',
                  style: TextStyle(
                    fontSize: size * 0.13,
                    fontWeight: FontWeight.w600,
                    color: _color.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  final Color color;
  _StampPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Outer circle
    canvas.drawCircle(center, radius, paint);

    // Inner circle
    canvas.drawCircle(center, radius - 6, paint..strokeWidth = 1.2);

    // Small decorative dots
    final dotPaint = Paint()
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 12; i++) {
      final angle = (i * 30) * pi / 180;
      final dx = center.dx + (radius - 3) * cos(angle);
      final dy = center.dy + (radius - 3) * sin(angle);
      canvas.drawCircle(Offset(dx, dy), 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StampPainter oldDelegate) =>
      oldDelegate.color != color;
}
