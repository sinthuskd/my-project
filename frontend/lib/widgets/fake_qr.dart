import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Demo QR look-alike (NOT scannable). Use the qr_flutter package for a real QR.
class FakeQr extends StatelessWidget {
  final int seed;
  final double size;
  const FakeQr({super.key, required this.seed, this.size = 200});

  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size(size, size), painter: _QrPainter(seed));
}

class _QrPainter extends CustomPainter {
  final int seed;
  _QrPainter(this.seed);
  static const n = 25;

  bool _finder(int r, int c) =>
      (r < 8 && c < 8) || (r < 8 && c >= n - 8) || (r >= n - 8 && c < 8);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / n;
    final dark = Paint()..color = AppColors.textDark;
    final blue = Paint()..color = AppColors.primary;
    final bg = Paint()..color = const Color(0xFFF2F3FF);
    final rnd = Random(seed);

    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (_finder(r, c)) continue;
        final v = rnd.nextDouble();
        if (v < 0.46) {
          final p = v < 0.04 ? blue : dark;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(c * cell, r * cell, cell * 0.92, cell * 0.92),
                Radius.circular(cell * 0.2)),
            p,
          );
        }
      }
    }

    void finder(int r0, int c0) {
      final x = c0 * cell, y = r0 * cell;
      RRect box(double inset, double w) => RRect.fromRectAndRadius(
          Rect.fromLTWH(x + inset * cell, y + inset * cell, w * cell, w * cell),
          Radius.circular(cell * 0.8));
      canvas.drawRRect(box(0, 7), dark);
      canvas.drawRRect(box(1, 5), bg);
      canvas.drawRRect(box(2, 3), dark);
    }

    finder(0, 0);
    finder(0, n - 7);
    finder(n - 7, 0);

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, cell * 2.6, bg);
    canvas.drawCircle(center, cell * 2.0, blue);
    final tp = TextPainter(
      text: TextSpan(
          text: '➤',
          style: TextStyle(color: Colors.white, fontSize: cell * 2.2)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _QrPainter old) => old.seed != seed;
}
