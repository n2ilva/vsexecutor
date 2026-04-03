import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vs_executor/ui/theme/app_colors.dart';
import 'package:vs_executor/core/utils/audio_utils.dart';

/// Pan knob widget for channel strips
class PanKnob extends StatefulWidget {
  final double value; // -1.0 (Left) to 1.0 (Right)
  final ValueChanged<double> onChanged;
  final double size;

  const PanKnob({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 36,
  });

  @override
  State<PanKnob> createState() => _PanKnobState();
}

class _PanKnobState extends State<PanKnob> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AudioUtils.formatPan(widget.value),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: _isDragging ? AppColors.accent : AppColors.textSecondary,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 2),
        GestureDetector(
          onHorizontalDragStart: (_) => setState(() => _isDragging = true),
          onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
          onHorizontalDragUpdate: (details) {
            final delta = details.delta.dx / 100;
            final newVal = (widget.value + delta).clamp(-1.0, 1.0);
            widget.onChanged(newVal);
          },
          onDoubleTap: () => widget.onChanged(0.0), // Reset to center
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _PanKnobPainter(
              value: widget.value,
              isDragging: _isDragging,
            ),
          ),
        ),
      ],
    );
  }
}

class _PanKnobPainter extends CustomPainter {
  final double value;
  final bool isDragging;

  _PanKnobPainter({required this.value, required this.isDragging});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Background circle
    final bgPaint = Paint()
      ..color = AppColors.surfaceLighter
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Border
    final borderPaint = Paint()
      ..color = isDragging ? AppColors.accent : AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);

    // Arc showing pan position
    final arcPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Arc from center (top) to value position
    const startAngle = -math.pi / 2; // top
    final sweepAngle = value * (math.pi * 0.75);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 3),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    // Indicator dot
    final angle = startAngle + sweepAngle;
    final dotX = center.dx + (radius - 3) * math.cos(angle);
    final dotY = center.dy + (radius - 3) * math.sin(angle);

    final dotPaint = Paint()
      ..color = isDragging ? AppColors.accent : AppColors.textPrimary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(dotX, dotY), 2.5, dotPaint);

    // Center mark
    final centerMark = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx, center.dy - radius + 5),
      Offset(center.dx, center.dy - radius + 9),
      centerMark,
    );

    // L and R indicators
    final lMark = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    final lAngle = startAngle - math.pi * 0.75;
    canvas.drawLine(
      Offset(
        center.dx + (radius - 5) * math.cos(lAngle),
        center.dy + (radius - 5) * math.sin(lAngle),
      ),
      Offset(
        center.dx + (radius - 1) * math.cos(lAngle),
        center.dy + (radius - 1) * math.sin(lAngle),
      ),
      lMark,
    );
    final rAngle = startAngle + math.pi * 0.75;
    canvas.drawLine(
      Offset(
        center.dx + (radius - 5) * math.cos(rAngle),
        center.dy + (radius - 5) * math.sin(rAngle),
      ),
      Offset(
        center.dx + (radius - 1) * math.cos(rAngle),
        center.dy + (radius - 1) * math.sin(rAngle),
      ),
      lMark,
    );
  }

  @override
  bool shouldRepaint(covariant _PanKnobPainter old) =>
      old.value != value || old.isDragging != isDragging;
}
