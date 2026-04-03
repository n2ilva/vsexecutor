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
    List<AudioDevice> devices = [];
    try {
      devices = await _audioPlugin.getAudioDevices();
    } catch (e) {
      debugPrint('Aviso: Plugin de áudio nativo indisponível ou falhou ($e).');
    }
    
    // Virtual devices for Master buss panning enforcement
    devices.insert(0, AudioDevice(id: -1, name: 'PAN Esquerdo', type: 'virtual', isDefault: false, pan: -1.0));
    devices.insert(1, AudioDevice(id: -2, name: 'PAN Direito', type: 'virtual', isDefault: false, pan: 1.0));
    devices.insert(2, AudioDevice(id: -3, name: 'PAN Centro', type: 'virtual', isDefault: false, pan: 0.0));

    setState(() {
      _devices = devices;
      _isLoading = false;
    });
  }

  void _showDeviceMenu() {
    if (_devices.isEmpty || _isLoading) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    final screenHeight = MediaQuery.of(context).size.height;

    showMenu(
      context: context,
      position: RelativeRect.fromSize(
        position & size,
        Size(MediaQuery.of(context).size.width, screenHeight),
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
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Center(
            child: _isLoading
                ? SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                    ),
                  )
                : Icon(
                    Icons.speaker_group_rounded,
                    size: 14,
                    color: widget.color,
                  ),
          ),
        ),
      ),
    );
  }
}
