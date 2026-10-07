import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The iBeLucky mark from `includes/mark.php` and `assets/images/logo.svg`.
/// Five rounded strokes of `M20 22.5 32 8.5 44 22.5`, rotated by 72 degrees.
class IbeLuckyMark extends StatelessWidget {
  const IbeLuckyMark({
    super.key,
    this.size = 40,
    this.color = const Color(0xFF4B66D8),
    this.background,
  });

  final double size;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: background == null ? null : BorderRadius.circular(size * 0.22),
        ),
        child: CustomPaint(
          painter: _IbeLuckyMarkPainter(color),
        ),
      ),
    );
  }
}

class _IbeLuckyMarkPainter extends CustomPainter {
  _IbeLuckyMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 64;
    canvas.save();
    canvas.scale(scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final ray = Path()
      ..moveTo(20, 22.5)
      ..lineTo(32, 8.5)
      ..lineTo(44, 22.5);
    for (var turn = 0; turn < 5; turn++) {
      canvas.save();
      canvas.translate(32, 32);
      canvas.rotate(turn * 72 * math.pi / 180);
      canvas.translate(-32, -32);
      canvas.drawPath(ray, paint);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IbeLuckyMarkPainter oldDelegate) => oldDelegate.color != color;
}
