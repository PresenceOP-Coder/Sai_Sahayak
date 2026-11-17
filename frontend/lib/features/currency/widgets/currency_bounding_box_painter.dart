import 'package:flutter/material.dart';

class CurrencyBoundingBoxPainter extends CustomPainter {
  final Rect? normalizedRect;
  final String label;
  final double confidence;

  CurrencyBoundingBoxPainter({
    required this.normalizedRect,
    required this.label,
    required this.confidence,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (normalizedRect == null) return;

    final rect = Rect.fromLTRB(
      normalizedRect!.left * size.width,
      normalizedRect!.top * size.height,
      normalizedRect!.right * size.width,
      normalizedRect!.bottom * size.height,
    );

    // Box border paint
    final borderPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Fill highlight paint
    final fillPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    // Draw box
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), fillPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), borderPaint);

    // Draw label badge
    final badgeText = '$label ${(confidence * 100).toInt()}%';
    final textSpan = TextSpan(
      text: badgeText,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeRect = Rect.fromLTWH(
      rect.left,
      (rect.top - 26).clamp(0.0, size.height - 26),
      textPainter.width + 16,
      24,
    );

    final badgePaint = Paint()..color = const Color(0xFF00E676);
    canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(6)), badgePaint);

    textPainter.paint(
      canvas,
      Offset(badgeRect.left + 8, badgeRect.top + (badgeRect.height - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CurrencyBoundingBoxPainter oldDelegate) {
    return oldDelegate.normalizedRect != normalizedRect ||
        oldDelegate.label != label ||
        oldDelegate.confidence != confidence;
  }
}
