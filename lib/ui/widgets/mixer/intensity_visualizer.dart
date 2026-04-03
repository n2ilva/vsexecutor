import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Modern animated intensity/waveform visualizer for audio tracks
class IntensityVisualizer extends StatefulWidget {
  final double level; // 0.0 to 1.0
  final Color trackColor;
  final Duration duration;
  final int barCount;

  const IntensityVisualizer({
    super.key,
    required this.level,
    required this.trackColor,
    this.duration = const Duration(milliseconds: 50),
    this.barCount = 16,
  });

  @override
  State<IntensityVisualizer> createState() => _IntensityVisualizerState();
}

class _IntensityVisualizerState extends State<IntensityVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final List<double> _bars = [];
  late double _smoothedLevel;

  @override
  void initState() {
    super.initState();
    _smoothedLevel = 0;
    _bars.addAll(List.filled(widget.barCount, 0.0));

    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addListener(_updateBars);

    _animationController.repeat();
  }

  void _updateBars() {
    setState(() {
      // Smooth the level with exponential moving average
      _smoothedLevel = _smoothedLevel * 0.7 + widget.level * 0.3;

      // Generate organic-looking bar heights
      for (int i = 0; i < _bars.length; i++) {
        final phase = (i / _bars.length) + _animationController.value * 2 * math.pi;
        final sinWave = (math.sin(phase) + 1) / 2; // 0-1 range

        // Mix between wave and actual level
        final targetHeight = (sinWave * 0.5 + _smoothedLevel * 0.5);
        _bars[i] = _bars[i] * 0.85 + targetHeight * 0.15; // Smooth decay
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(IntensityVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barCount != widget.barCount) {
      _bars.clear();
      _bars.addAll(List.filled(widget.barCount, 0.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 40),
      painter: _IntensityPainter(
        bars: _bars,
        trackColor: widget.trackColor,
        smoothedLevel: _smoothedLevel,
      ),
    );
  }
}

class _IntensityPainter extends CustomPainter {
  final List<double> bars;
  final Color trackColor;
  final double smoothedLevel;

  _IntensityPainter({
    required this.bars,
    required this.trackColor,
    required this.smoothedLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    final barWidth = size.width / bars.length;
    final centerY = size.height / 2;
    final maxHeight = size.height / 2;

    for (int i = 0; i < bars.length; i++) {
      final x = i * barWidth;
      final height = bars[i] * maxHeight;

      // Color gradient based on intensity
      final intensity = bars[i];
      
      Color barColor;
      if (intensity > 0.7) {
        barColor = Color.lerp(trackColor, Colors.red, (intensity - 0.7) / 0.3)!;
      } else if (intensity > 0.4) {
        barColor = Color.lerp(trackColor, Colors.yellow, (intensity - 0.4) / 0.3)!;
      } else {
        barColor = trackColor.withValues(alpha: 0.6);
      }

      // Draw top bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x + 1,
            centerY - height,
            barWidth - 2,
            height,
          ),
          const Radius.circular(2),
        ),
        Paint()
          ..color = barColor
          ..style = PaintingStyle.fill,
      );

      // Draw bottom bar (mirrored)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x + 1,
            centerY,
            barWidth - 2,
            height,
          ),
          const Radius.circular(2),
        ),
        Paint()
          ..color = barColor.withValues(alpha: 0.7)
          ..style = PaintingStyle.fill,
      );

      // Draw center line
      if (i == 0 || i == bars.length - 1) {
        canvas.drawLine(
          Offset(x + barWidth / 2, 0),
          Offset(x + barWidth / 2, size.height),
          Paint()
            ..color = Colors.grey.withValues(alpha: 0.1)
            ..strokeWidth = 0.5,
        );
      }
    }

    // Draw center line
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      Paint()
        ..color = Colors.grey.withValues(alpha: 0.1)
        ..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(covariant _IntensityPainter old) =>
      old.smoothedLevel != smoothedLevel ||
      old.bars != bars ||
      old.trackColor != trackColor;
}
