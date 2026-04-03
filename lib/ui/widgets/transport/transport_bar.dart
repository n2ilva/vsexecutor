import 'package:flutter/material.dart';
import 'package:vs_executor/ui/theme/app_colors.dart';
import 'package:vs_executor/core/audio/audio_engine.dart';
import 'package:vs_executor/core/utils/audio_utils.dart';

/// Transport bar with play/pause/stop, position display, loop toggle
class TransportBar extends StatelessWidget {
  final AudioEngine engine;

  const TransportBar({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Left side: Position displays
            _PositionDisplay(engine: engine),
            const SizedBox(width: 12),
            Container(width: 1, height: 32, color: AppColors.border),
            const SizedBox(width: 12),
            _BarBeatDisplay(engine: engine),
            
            const SizedBox(width: 24),

            // Controls: Rewind, Stop, Play
            _TransportButton(
              icon: Icons.skip_previous_rounded,
              onTap: engine.goToStart,
              tooltip: 'Ir ao começo',
            ),
            const SizedBox(width: 8),
            _TransportButton(
              icon: Icons.stop_rounded,
              onTap: () => engine.stopAll(),
              tooltip: 'Parar',
              color: engine.isPlaying ? AppColors.stopRed : null,
            ),
            const SizedBox(width: 8),
            _PlayButton(engine: engine),
            
            const SizedBox(width: 16),
            Container(width: 1, height: 32, color: AppColors.border),
            const SizedBox(width: 16),

            // Loop & Metronome & Add Section
            _TransportButton(
              icon: Icons.repeat_rounded,
              onTap: engine.toggleLoop,
              tooltip: 'Ativar Loop na Região',
              color: engine.isLooping ? AppColors.accent : null,
              isActive: engine.isLooping,
            ),
            const SizedBox(width: 8),
            _TransportButton(
              icon: Icons.timer_outlined,
              onTap: engine.toggleMetronome,
              tooltip: 'Metrônomo',
              color: engine.metronomeEnabled ? AppColors.accent : null,
              isActive: engine.metronomeEnabled,
            ),
            const SizedBox(width: 8),
            _TransportButton(
              icon: Icons.bookmark_add_rounded,
              onTap: () {
                final snappedMs = engine.timeSignature.quantizeToNearestBar(engine.currentPosition.inMilliseconds.toDouble(), engine.bpm);
                final barMs = engine.timeSignature.barDurationMs(engine.bpm);
                int colorIndex = engine.markers.length % 8;
                engine.addMarkerAt('Seção ${engine.markers.length + 1}', snappedMs, colorIndex: colorIndex, endMs: snappedMs + barMs);
              },
              tooltip: 'Adicionar Seção no Playhead',
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final AudioEngine engine;

  const _PlayButton({required this.engine});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => engine.togglePlayPause(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: engine.isPlaying
              ? null
              : const LinearGradient(
                  colors: [AppColors.playGreen, Color(0xFF00CC6A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: engine.isPlaying ? AppColors.surfaceLighter : null,
          border: Border.all(
            color: engine.isPlaying
                ? AppColors.accent
                : AppColors.playGreen.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (engine.isPlaying ? AppColors.accent : AppColors.playGreen)
                  .withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Icon(
          engine.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: engine.isPlaying ? AppColors.accent : AppColors.background,
          size: 24,
        ),
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color? color;
  final bool isActive;

  const _TransportButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive
                ? (color ?? AppColors.accent).withValues(alpha: 0.15)
                : AppColors.surfaceLighter,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? (color ?? AppColors.accent).withValues(alpha: 0.5)
                  : AppColors.border,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: color ?? AppColors.textSecondary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _PositionDisplay extends StatelessWidget {
  final AudioEngine engine;

  const _PositionDisplay({required this.engine});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180, // Fixed width to prevent resize (increased extra to avoid wrap)
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TIME',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          Text(
            '${AudioUtils.formatDuration(engine.currentPosition)} / ${AudioUtils.formatDuration(engine.totalDuration)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarBeatDisplay extends StatelessWidget {
  final AudioEngine engine;

  const _BarBeatDisplay({required this.engine});

  @override
  Widget build(BuildContext context) {
    final pos = engine.currentBarBeat;
    return Container(
      width: 130, // Fixed width to prevent resize (increased more for safe measure)
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${engine.timeSignature}',
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          Text(
            AudioUtils.formatBarBeatTick(pos.bar, pos.beat, pos.tick),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryLight,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
