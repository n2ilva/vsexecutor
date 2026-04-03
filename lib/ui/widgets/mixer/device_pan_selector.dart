import 'package:flutter/material.dart';
import 'package:vs_executor/ui/theme/app_colors.dart';

/// Widget para seleção de PAN (Panorama) em dispositivos de saída de áudio
/// Oferece três opções: Esquerda (-1.0), Centro (0.0), Direita (1.0)
class DevicePanSelector extends StatelessWidget {
  final double pan; // -1.0 (Esquerda) a 1.0 (Direita), 0.0 (Centro)
  final ValueChanged<double> onPanChanged;
  final bool enabled;

  const DevicePanSelector({
    super.key,
    required this.pan,
    required this.onPanChanged,
    this.enabled = true,
  });

  String _getPanLabel(double pan) {
    if (pan < -0.5) {
      return 'Esquerda';
    } else if (pan > 0.5) {
      return 'Direita';
    } else {
      return 'Centro';
    }
  }

  Color _getPanColor(double pan) {
    if (pan < -0.5) {
      return Colors.blue.withValues(alpha: 0.7);
    } else if (pan > 0.5) {
      return Colors.red.withValues(alpha: 0.7);
    } else {
      return Colors.green.withValues(alpha: 0.7);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Text(
          'PAN',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        // Pan Display
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLighter,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _getPanColor(pan),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                _getPanLabel(pan),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _getPanColor(pan),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(pan * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Pan Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Esquerda
            _PanButton(
              label: 'L',
              pan: -1.0,
              isSelected: pan < -0.5,
              onPressed: enabled ? () => onPanChanged(-1.0) : null,
              color: Colors.blue,
            ),
            // Centro
            _PanButton(
              label: 'C',
              pan: 0.0,
              isSelected: pan >= -0.5 && pan <= 0.5,
              onPressed: enabled ? () => onPanChanged(0.0) : null,
              color: Colors.green,
            ),
            // Direita
            _PanButton(
              label: 'R',
              pan: 1.0,
              isSelected: pan > 0.5,
              onPressed: enabled ? () => onPanChanged(1.0) : null,
              color: Colors.red,
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Slider para ajuste fino
        Slider(
          value: pan,
          min: -1.0,
          max: 1.0,
          divisions: 20,
          onChanged: enabled ? onPanChanged : null,
          activeColor: _getPanColor(pan),
          inactiveColor: AppColors.surfaceLighter,
        ),
      ],
    );
  }
}

/// Botão individual para seleção de PAN
class _PanButton extends StatelessWidget {
  final String label;
  final double pan;
  final bool isSelected;
  final VoidCallback? onPressed;
  final Color color;

  const _PanButton({
    required this.label,
    required this.pan,
    required this.isSelected,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : AppColors.surfaceLighter,
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? color : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
