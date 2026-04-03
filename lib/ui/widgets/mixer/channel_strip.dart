import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../../core/models/track_model.dart';
import '../../../core/audio/audio_engine.dart';
import 'volume_fader.dart';
import 'vu_meter.dart';
import '../../screens/bpm_analysis_screen.dart';

/// A single channel strip in the mixer view
class ChannelStrip extends StatelessWidget {
  final TrackModel track;
  final AudioEngine engine;
  final bool isCompact;

  const ChannelStrip({
    super.key,
    required this.track,
    required this.engine,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isCompact ? 60 : 72,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: AppColors.channelStrip,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: track.isSolo
              ? AppColors.soloYellow.withValues(alpha: 0.5)
              : AppColors.border,
          width: track.isSolo ? 1.5 : 1,
        ),
        boxShadow: track.isSolo
            ? [
                BoxShadow(
                  color: AppColors.soloYellow.withValues(alpha: 0.1),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // HEADER COLORIDO QUE FUNCIONA COMO DRAG HANDLE
          ReorderableDragStartListener(
            index: engine.tracks.indexOf(track),
            child: Container(
              width: double.infinity,
              height: 18,
              decoration: BoxDecoration(
                color: track.color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ],
              ),
              child: const Icon(
                Icons.drag_handle_rounded,
                size: 14,
                color: Colors.white70,
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Track name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              track.name,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: track.isMuted
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 4),

          // Routing Button (A or B)
          GestureDetector(
            onTap: () {
              final newRouting = track.routing == 'A' ? 'B' : 'A';
              engine.setTrackRouting(track.id, newRouting);
            },
            child: Container(
              width: 24,
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: track.routing == 'A' ? AppColors.accent.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: track.routing == 'A' ? AppColors.accent : Colors.orange,
                  width: 1,
                ),
              ),
              child: Text(
                track.routing,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: track.routing == 'A' ? AppColors.accent : Colors.orange,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 4),

          // VU Meter + Fader
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   VuMeter(
                    level: track.level,
                    width: 6,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: VolumeFader(
                      value: track.volume,
                      onChanged: (val) => engine.setTrackVolume(track.id, val),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Solo / Mute buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: _MixerToggleButton(
                    label: 'S',
                    isActive: track.isSolo,
                    activeColor: AppColors.soloYellow,
                    onTap: () => engine.toggleSolo(track.id),
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: _MixerToggleButton(
                    label: 'M',
                    isActive: track.isMuted,
                    activeColor: AppColors.muteRed,
                    onTap: () => engine.toggleMute(track.id),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),
          
          // BPM Analysis "Magic" Button
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BpmAnalysisScreen(
                    engine: engine,
                    track: track,
                  ),
                ),
              );
            },
            child: Tooltip(
              message: 'Analisar BPM / Waveform',
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_fix_high_rounded,
                    size: 14,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),
          
          // Remove Track Button
          GestureDetector(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: const Text('Remover faixa?'),
                  content: Text('Deseja remover "${track.name}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Remover',
                        style: TextStyle(color: AppColors.muteRed),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                engine.removeTrack(track.id);
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.surfaceLighter,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _MixerToggleButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _MixerToggleButton({
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  })  : label = label,
        isActive = isActive,
        activeColor = activeColor,
        onTap = onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 24,
        decoration: BoxDecoration(
          color: isActive ? activeColor : AppColors.surfaceLighter,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.7)
                : AppColors.border,
            width: 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isActive ? AppColors.background : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
