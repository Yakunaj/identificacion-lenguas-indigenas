import 'package:flutter/material.dart';

class WaveformWidget extends StatelessWidget {
  final List<double> amplitudes;
  final double height;

  const WaveformWidget({
    super.key,
    required this.amplitudes,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveformPainter(
          amplitudes: amplitudes,
          color1: colorScheme.secondary,
          color2: colorScheme.tertiary,
        ),
      ),
    );
  }
}


class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color1;
  final Color color2;

  _WaveformPainter({
    required this.amplitudes,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (amplitudes.isEmpty) {
      return;
    }

    final centerY = size.height / 2;

    final anchoBarra =
        size.width / (amplitudes.length/ 1.2);

    for (int i = 0; i < amplitudes.length; i++) {
      final amplitud =
          amplitudes[i].clamp(0.0, 1.0);

      final altura =
          amplitud * size.height * 5;

      final x =
          i * anchoBarra +
          anchoBarra / 2;

      final color =
          i % 2 == 0
              ? color1
              : color2;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(
          x,
          centerY - altura,
        ),
        Offset(
          x,
          centerY + altura,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _WaveformPainter oldDelegate,
  ) {
    return true;
  }
}