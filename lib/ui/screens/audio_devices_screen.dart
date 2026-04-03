import 'package:flutter/material.dart';
import 'package:multi_audio_output/multi_audio_output.dart';
import 'package:vs_executor/ui/theme/app_colors.dart';
import 'package:vs_executor/ui/widgets/mixer/device_pan_selector.dart';
import 'package:vs_executor/core/audio/audio_engine.dart';

class AudioDevicesScreen extends StatefulWidget {
  final AudioEngine engine;
  const AudioDevicesScreen({super.key, required this.engine});

  @override
  State<AudioDevicesScreen> createState() => _AudioDevicesScreenState();
}

class _AudioDevicesScreenState extends State<AudioDevicesScreen> {
  final _audioPlugin = MultiAudioOutput();
  List<AudioDevice> _devices = [];
  final Map<int, double> _devicePans = {}; // Armazenar pan de cada dispositivo
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
        // Inicializar pans com valores dos dispositivos, priorizando o que está no AudioEngine
        for (final device in devices) {
          _devicePans[device.id] = widget.engine.allKnownDevicePans[device.id] ?? device.pan;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dispositivos: $e'),
            backgroundColor: AppColors.muteRed,
          ),
        );
      }
    }
  }

  Future<void> _setPan(int deviceId, double pan) async {
    try {
      final success = await _audioPlugin.setDevicePan(deviceId, pan);
      if (success) {
        setState(() {
          _devicePans[deviceId] = pan;
        });
        
        // Sincronizar com o AudioEngine
        final device = _devices.firstWhere((d) => d.id == deviceId);
        widget.engine.syncDevicePan(device.name, pan, deviceId: device.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao definir PAN: $e'),
            backgroundColor: AppColors.muteRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivos de Áudio'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.speaker_notes_off,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Nenhum dispositivo encontrado',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    final currentPan = _devicePans[device.id] ?? 0.0;

                    return Card(
                      color: AppColors.channelStrip,
                      elevation: 1,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header compacto
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        device.name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        device.manufacturer ?? 'Sistema de Áudio',
                                        style: const TextStyle(
                                          fontSize: 10,
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

                            const SizedBox(height: 8),

                            // PAN Selector Compacto
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.border.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Transform.scale(
                                  scale: 0.85,
                                  child: DevicePanSelector(
                                    pan: currentPan,
                                    onPanChanged: (newPan) {
                                      _setPan(device.id, newPan);
                                    },
                                    enabled: true,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
