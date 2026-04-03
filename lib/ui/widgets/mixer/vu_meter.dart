import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vs_executor/ui/theme/app_colors.dart';

/// Animated VU meter for channel strips
class VuMeter extends StatefulWidget {
  final double level; // 0.0 to 1.0
  final double width;
  final double height;

  const VuMeter({
    super.key,
    required this.level,
    this.width = 8,
    this.height = 120,
  });

  @override
  State<VuMeter> createState() => _VuMeterState();
}

class _VuMeterState extends State<VuMeter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _displayLevel = 0;
  double _peakLevel = 0;
  int _peakHoldFrames = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_tick);
    _controller.repeat();
  }

  void _tick() {
    setState(() {
      // Smooth falloff
      final target = widget.level;
      if (target > _displayLevel) {
        _displayLevel = target; // Instant attack
      } else {
        _displayLevel = _displayLevel * 0.92 + target * 0.08; // Smooth decay
      }

      // Peak hold
      if (_displayLevel > _peakLevel) {
        _peakLevel = _displayLevel;
        _peakHoldFrames = 30; // Hold for ~30 frames
      } else if (_peakHoldFrames > 0) {
        _peakHoldFrames--;
      } else {
        _peakLevel = math.max(_peakLevel * 0.98, _displayLevel);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(widget.width, widget.height),
      painter: _VuMeterPainter(
        level: _displayLevel,
        peakLevel: _peakLevel,
      ),
    );
  }
}

class _VuMeterPainter extends CustomPainter {
  final double level;
  final double peakLevel;

  _VuMeterPainter({required this.level, required this.peakLevel});

  @override
  void paint(Canvas canvas, Size size) {
    final segmentCount = 24;
    final segmentHeight = (size.height - segmentCount + 1) / segmentCount;
    final segmentWidth = size.width;

    for (int i = 0; i < segmentCount; i++) {
      final normalizedPos = i / segmentCount;
      final y = size.height - (i + 1) * (segmentHeight + 1);

      Color segColor;
      if (normalizedPos > 0.85) {
        segColor = AppColors.vuHigh;
      } else if (normalizedPos > 0.65) {
        segColor = AppColors.vuMid;
      } else {
        segColor = AppColors.vuLow;
      }

      final isActive = normalizedPos < level;
      final isPeak = (normalizedPos - peakLevel).abs() < (1.0 / segmentCount);

      Paint paint;
      if (isActive) {
        paint = Paint()
          ..color = segColor
          ..style = PaintingStyle.fill;
      } else if (isPeak && peakLevel > 0.01) {
        paint = Paint()
          ..color = segColor.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;
      } else {
        paint = Paint()
          ..color = segColor.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill;
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, y, segmentWidth, segmentHeight),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VuMeterPainter old) =>
      old.level != level || old.peakLevel != peakLevel;
}
