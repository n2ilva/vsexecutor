import 'package:flutter/material.dart';
import 'package:vs_executor/ui/theme/app_colors.dart';
import 'package:vs_executor/core/utils/audio_utils.dart';

/// Vertical volume fader widget for channel strips
class VolumeFader extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double height;

  const VolumeFader({
    super.key,
    required this.value,
    required this.onChanged,
    this.height = 180,
  });

  @override
  State<VolumeFader> createState() => _VolumeFaderState();
}

class _VolumeFaderState extends State<VolumeFader> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // dB label
        Text(
          AudioUtils.formatDb(widget.value),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: _isDragging ? AppColors.accent : AppColors.textSecondary,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 4),
        // Fader track
        Expanded(
          child: SizedBox(
            width: 40,
            child: GestureDetector(
              onVerticalDragStart: (_) => setState(() => _isDragging = true),
              onVerticalDragEnd: (_) => setState(() => _isDragging = false),
              onVerticalDragUpdate: (details) {
                final box = context.findRenderObject() as RenderBox;
                final localY = box.globalToLocal(details.globalPosition).dy;
                // Subtract the label height + spacing (~16px)
                final adjustedY = localY - 16;
                // Use actual rendered space height for the slider track
                final sliderHeight = box.size.height - 16;
                final normalized =
                    1.0 - (adjustedY / sliderHeight).clamp(0.0, 1.0);
                widget.onChanged(normalized);
              },
              onDoubleTap: () => widget.onChanged(0.8), // Reset to default
              child: CustomPaint(
                painter: _FaderPainter(
                  value: widget.value,
                  isDragging: _isDragging,
                ),
                size: Size(40, widget.height),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FaderPainter extends CustomPainter {
  final double value;
  final bool isDragging;

  _FaderPainter({required this.value, required this.isDragging});

  @override
  void paint(Canvas canvas, Size size) {
    final trackWidth = 4.0;
    final trackX = size.width / 2;
    final trackTop = 8.0;
    final trackBottom = size.height - 8.0;
    final trackHeight = trackBottom - trackTop;

    // Draw tick marks
    final tickPaint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    for (double db = 0; db >= -48; db -= 6) {
      final normalized = AudioUtils.dbToLinear(db);
      final y = trackBottom - (normalized * trackHeight);
      canvas.drawLine(Offset(trackX - 12, y), Offset(trackX - 6, y), tickPaint);
      canvas.drawLine(Offset(trackX + 6, y), Offset(trackX + 12, y), tickPaint);
    }

    // Track background
    final bgPaint = Paint()
      ..color = AppColors.surfaceLighter
      ..strokeWidth = trackWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(trackX, trackTop),
      Offset(trackX, trackBottom),
      bgPaint,
    );

    // Active track (filled part)
    final thumbY = trackBottom - (value * trackHeight);
    final activeGradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [AppColors.accent.withValues(alpha: 0.3), AppColors.accent],
    );

    final activePaint = Paint()
      ..shader = activeGradient.createShader(
        Rect.fromLTRB(trackX - 2, thumbY, trackX + 2, trackBottom),
      )
      ..strokeWidth = trackWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(trackX, thumbY),
      Offset(trackX, trackBottom),
      activePaint,
    );

    // Thumb
    final thumbPaint = Paint()
      ..color = isDragging ? AppColors.accent : AppColors.textPrimary;

    // Thumb glow
    if (isDragging) {
      final glowPaint = Paint()
        ..color = AppColors.accentGlow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(trackX, thumbY),
            width: 28,
            height: 12,
          ),
          const Radius.circular(4),
        ),
        glowPaint,
      );
    }

    // Draw thumb knob
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(trackX, thumbY), width: 24, height: 8),
        const Radius.circular(3),
      ),
      thumbPaint,
    );

    // Center line on thumb
    final centerLinePaint = Paint()
      ..color = isDragging ? AppColors.background : AppColors.surfaceLighter
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(trackX - 6, thumbY),
      Offset(trackX + 6, thumbY),
      centerLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FaderPainter old) =>
      old.value != value || old.isDragging != isDragging;
}
