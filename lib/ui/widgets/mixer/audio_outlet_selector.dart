import 'package:flutter/material.dart';
import 'package:multi_audio_output/multi_audio_output.dart';
import 'package:vs_executor/ui/theme/app_colors.dart';

/// Widget compacto para seleção de dispositivo de saída de áudio
/// Exibe um dropdown com os dispositivos disponíveis
class AudioOutletSelector extends StatefulWidget {
  final String label;          // Ex: "A" ou "B"
  final Color color;           // Cor do indicador
  final String? selectedDeviceName;
  final ValueChanged<AudioDevice> onDeviceSelected;
  final bool enabled;

  const AudioOutletSelector({
    super.key,
    required this.label,
    required this.color,
    required this.onDeviceSelected,
    this.selectedDeviceName,
    this.enabled = true,
  });

  @override
  State<AudioOutletSelector> createState() => _AudioOutletSelectorState();
}

class _AudioOutletSelectorState extends State<AudioOutletSelector> {
  final _audioPlugin = MultiAudioOutput();
  List<AudioDevice> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await _audioPlugin.getAudioDevices();
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Erro ao carregar dispositivos: $e');
    }
  }

  void _showDeviceMenu() {
    if (_devices.isEmpty || _isLoading) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    final screenHeight = MediaQuery.of(context).size.height;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        0, // Limite superior
        position.dx + size.width,
        screenHeight - position.dy, // Distância do fundo da tela até o topo do botão
      ),
      items: [
        ..._devices.map((device) {
          final isSelected = widget.selectedDeviceName == device.name;
          return PopupMenuItem<AudioDevice>(
            value: device,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  Icon(
                    Icons.check,
                    size: 16,
                    color: widget.color,
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (device.manufacturer != null && device.manufacturer!.isNotEmpty)
                        Text(
                          device.manufacturer!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ).then((device) {
      if (device != null && widget.enabled) {
        widget.onDeviceSelected(device);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Selecionar Saída de Áudio para Master ${widget.label}',
      child: GestureDetector(
        onTap: widget.enabled ? _showDeviceMenu : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.speaker,
                size: 14,
                color: widget.color,
              ),
              const SizedBox(width: 4),
              _isLoading
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                      ),
                    )
                  : Flexible(
                      child: Text(
                        widget.selectedDeviceName ?? 'Sistema',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: widget.color,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                    ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down,
                size: 12,
                color: widget.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
