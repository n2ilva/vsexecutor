import 'package:flutter/material.dart';
import 'package:vs_executor/ui/theme/app_colors.dart';
import 'package:vs_executor/core/audio/audio_engine.dart';
import 'package:vs_executor/core/models/session_marker.dart';

/// Section bar showing quick-access buttons for song sections
class SectionBar extends StatelessWidget {
  final AudioEngine engine;

  const SectionBar({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.bookmark_rounded,
            size: 16,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 8),

          // Section buttons
          Expanded(
            child: engine.markers.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhuma seção adicionada',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: engine.markers.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final marker = engine.markers[index];
                      return _SectionButton(
                        marker: marker,
                        onTap: () => engine.jumpToMarker(marker.id),
                        onLongPress: () => _showMarkerOptions(context, marker),
                      );
                    },
                  ),
          ),

          const SizedBox(width: 8),

          // Add section button
          GestureDetector(
            onTap: () => _showAddMarkerDialog(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surfaceLighter,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 18,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMarkerDialog(BuildContext context) {
    final nameController = TextEditingController();
    int selectedColorIndex = 0;

    final sectionPresets = [
      'Intro',
      'Estrofe',
      'Pré-Refrão',
      'Refrão',
      'Ponte',
      'Solo',
      'Outro',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Adicionar Seção',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Preset buttons
                  const Text(
                    'Seções rápidas:',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: sectionPresets.asMap().entries.map((entry) {
                      final index = entry.key;
                      final name = entry.value;
                      return GestureDetector(
                        onTap: () {
                          nameController.text = name;
                          setState(() => selectedColorIndex = index % 8);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLighter,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Name input
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Nome da seção',
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Color picker
                  const Text(
                    'Cor:',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(8, (index) {
                      final colors = AppColors.sectionColors;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => selectedColorIndex = index),
                        child: Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: colors[index],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedColorIndex == index
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: selectedColorIndex == index
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Add button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isNotEmpty) {
                          engine.addMarker(
                            nameController.text,
                            colorIndex: selectedColorIndex,
                          );
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Adicionar na posição atual',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showMarkerOptions(BuildContext context, SessionMarker marker) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                marker.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.playGreen,
                ),
                title: const Text('Ir para esta seção'),
                onTap: () {
                  engine.jumpToMarker(marker.id);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_rounded,
                  color: AppColors.muteRed,
                ),
                title: const Text('Remover seção'),
                onTap: () {
                  engine.removeMarker(marker.id);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionButton extends StatelessWidget {
  final SessionMarker marker;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SectionButton({
    required this.marker,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: marker.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: marker.color.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: marker.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              marker.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: marker.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
