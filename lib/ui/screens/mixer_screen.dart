import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:vs_executor/ui/theme/app_colors.dart';
import 'package:vs_executor/core/audio/audio_engine.dart';
import 'package:vs_executor/core/services/project_service.dart';
import 'package:vs_executor/core/utils/constants.dart';
import 'package:vs_executor/ui/widgets/mixer/channel_strip.dart';
import 'package:vs_executor/ui/widgets/mixer/audio_outlet_selector.dart';
import 'package:vs_executor/ui/widgets/transport/transport_bar.dart';
import 'package:vs_executor/ui/widgets/transport/bpm_control.dart';
import 'package:vs_executor/ui/widgets/transport/time_signature_selector.dart';
import 'package:vs_executor/ui/widgets/transport/interactive_timeline.dart';

class MixerScreen extends StatefulWidget {
  final AudioEngine engine;

  const MixerScreen({super.key, required this.engine});

  @override
  State<MixerScreen> createState() => _MixerScreenState();
}

class _MixerScreenState extends State<MixerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  bool _isLoading = false;
  final GlobalKey _recentButtonKey = GlobalKey();

  AudioEngine get engine => widget.engine;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    engine.addListener(_onEngineUpdate);
  }

  @override
  void dispose() {
    engine.removeListener(_onEngineUpdate);
    _fadeController.dispose();
    super.dispose();
  }

  void _onEngineUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _addTrack() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result == null) return;

      setState(() => _isLoading = true);

      for (final file in result.files) {
        if (file.path != null) {
          await engine.addTrack(file.path!);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar: $e'),
            backgroundColor: AppColors.muteRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRecentProjectsMenu(BuildContext context, GlobalKey buttonKey) async {
    if (buttonKey.currentContext == null) return;
    final RenderBox renderBox = buttonKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    final recent = await ProjectService.getRecentProjects();
    if (!context.mounted) return;

    if (recent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum projeto recente'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final selectedPath = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + size.height + 8,
        position.dx + size.width,
        0,
      ),
      color: AppColors.surface,
      items: recent.map((item) {
        return PopupMenuItem<String>(
          value: item['path'],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['name'] ?? 'Unknown',
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              ),
              Text(
                item['path'] ?? '',
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
    );

    if (selectedPath != null && mounted) {
      setState(() => _isLoading = true);
      final success = await ProjectService.loadProjectFromPath(engine, selectedPath);
      if (mounted) {
        setState(() => _isLoading = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Projeto carregado!' : 'Erro ao carregar ou arquivo não encontrado'),
              backgroundColor: success ? AppColors.playGreen : AppColors.muteRed,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;
    final isMobileApp = Theme.of(context).platform == TargetPlatform.android ||
                        Theme.of(context).platform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            FadeTransition(
              opacity: _fadeController,
              child: Column(
                children: [
              // Header
              _buildHeader(isWideScreen),

              // Transport bar
              TransportBar(engine: engine),

              // Interactive Timeline (Sections & Playhead)
              InteractiveTimeline(engine: engine),

              // Mixer area
              Expanded(
                child: engine.tracks.isEmpty
                    ? _buildEmptyState()
                    : (isMobileApp 
                        ? _buildMobileMixerButton() 
                        : _buildMixerArea(isWideScreen)),
              ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isWide) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // Project Actions (Left) - Scrollable if tight
          // Project Actions (Left)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
                // New Project
                _buildHeaderButton(
                  icon: Icons.note_add_rounded,
                  label: 'Novo',
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text('Novo Projeto?'),
                        content: const Text('Isso irá limpar o projeto atual. Deseja continuar?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Limpar Tudo', style: TextStyle(color: AppColors.muteRed)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await engine.resetProject();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Novo projeto criado!'),
                            backgroundColor: AppColors.playGreen,
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(width: 8),

                // Save Project
                _buildHeaderButton(
                  icon: Icons.save_rounded,
                  label: 'Salvar',
                  onTap: () async {
                    String? projectName;
                    
                    // No mobile, pedimos o nome via diálogo customizado antes de enviar para o ProjectService
                    if (Theme.of(context).platform == TargetPlatform.android || 
                        Theme.of(context).platform == TargetPlatform.iOS) {
                      projectName = await _showSaveProjectDialog(context);
                      if (projectName == null || projectName.trim().isEmpty) return;
                      // Adicionar extensão se não tiver
                      if (!projectName.endsWith('.vsexec')) projectName += '.vsexec';
                    }

                    final success = await ProjectService.saveProject(engine, fileName: projectName);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success ? 'Projeto salvo!' : 'Erro ao salvar',
                          ),
                          backgroundColor: success
                              ? AppColors.playGreen
                              : AppColors.muteRed,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),

                // Open Project
                _buildHeaderButton(
                  icon: Icons.folder_open_rounded,
                  label: 'Abrir',
                  onTap: () async {
                    setState(() => _isLoading = true);
                    final success = await ProjectService.loadProject(engine);
                    setState(() => _isLoading = false);
                    if (mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Projeto carregado!'),
                          backgroundColor: AppColors.playGreen,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),

                // Recent Projects
                _buildHeaderButton(
                  key: _recentButtonKey,
                  icon: Icons.history_rounded,
                  label: 'Recentes',
                  onTap: () => _showRecentProjectsMenu(context, _recentButtonKey),
                ),
                ],
              ),

          const SizedBox(width: 12),

          // Centralized Audio Options - Expanded to take remaining space
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
              BpmControl(engine: engine),
              const SizedBox(width: 8),
              TimeSignatureSelector(engine: engine),
              if (isWide) ...[
                const SizedBox(width: 12),
                Container(width: 1, height: 28, color: AppColors.border),
                const SizedBox(width: 12),
                // Audio Devices Button
                Tooltip(
                  message: 'Gerenciar Dispositivos de Áudio',
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/audio-devices');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.speaker_phone_rounded,
                            size: 16,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Áudio',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),

          const SizedBox(width: 8),

          // Logo / Title (Right) - Hide if narrow
          if (isWide || MediaQuery.of(context).size.width > 440)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: ShaderMask(
                shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                child: const Text(
                  'VS EXECUTOR',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Key? key,
  }) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceLighter,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 16, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildMuteButton({
    required bool isMuted,
    required Color color,
    required VoidCallback onTap,
    double size = 28,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isMuted 
              ? color.withValues(alpha: 0.2)
              : AppColors.surfaceLighter,
          border: Border.all(
            color: isMuted ? color : AppColors.border,
            width: isMuted ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Icon(
            isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            size: size * 0.45,
            color: isMuted ? color : AppColors.textMuted,
          ),
        ),
      ),
    );
  }



  Widget _buildMobileMixerButton() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Mixer Completo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gerencie níveis e canais em uma tela focada',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      backgroundColor: AppColors.background,
                      appBar: AppBar(
                        backgroundColor: AppColors.surface,
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTransportAction(
                              icon: Icons.skip_previous_rounded,
                              onTap: () => engine.goToStart(),
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            _buildTransportAction(
                              icon: Icons.stop_rounded,
                              onTap: () => engine.stopAll(),
                              color: engine.isPlaying ? AppColors.stopRed : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            _buildQuickPlayButton(),
                          ],
                        ),
                        centerTitle: true,
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      body: SafeArea(
                        child: AnimatedBuilder(
                          animation: engine,
                          builder: (context, _) => _buildMixerArea(false),
                        ),
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Abrir Sala de Mixagem'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nenhuma faixa adicionada',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Adicione arquivos de áudio para começar a mixar',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _addTrack,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(_isLoading ? 'Carregando...' : 'Adicionar Faixas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMixerArea(bool isWide) {
    return Column(
      children: [
        // Mixer strips
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                // Channel strips (horizontally scrollable)
                Expanded(
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: false,
                    itemCount: engine.tracks.length,
                    onReorder: (oldIndex, newIndex) {
                      engine.reorderTrack(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final track = engine.tracks[index];
                      return Dismissible(
                        key: Key(track.id),
                        direction: DismissDirection.up,
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: AppColors.surface,
                              title: const Text('Remover faixa?'),
                              content: Text('Deseja remover "${track.name}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
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
                        },
                        onDismissed: (_) => engine.removeTrack(track.id),
                        child: ChannelStrip(
                          track: track,
                          engine: engine,
                          isCompact: !isWide,
                        ),
                      );
                    },
                  ),
                ),

                // Add track button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: _isLoading ? null : _addTrack,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLighter,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                            ),
                            child: _isLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.accent,
                                    ),
                                  )
                                : const Icon(
                                    Icons.add_rounded,
                                    size: 18,
                                    color: AppColors.accent,
                                  ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${engine.trackCount}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMuted,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Master volume
        _buildMasterStrip(),
      ],
    );
  }

  Widget _buildMasterStrip() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const SizedBox(width: 8),
            // MASTER A
            const Text(
              'A',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  activeTrackColor: AppColors.accent,
                  inactiveTrackColor: AppColors.surfaceLighter,
                  thumbColor: AppColors.accent,
                ),
                child: Slider(
                  value: engine.masterAVolume,
                  onChanged: (val) => engine.setMasterAVolume(val),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Master A Mute Button
            _buildMuteButton(
              isMuted: engine.masterAMuted,
              color: AppColors.accent,
              onTap: () => engine.toggleMasterAMute(),
              size: 24,
            ),
            const SizedBox(width: 12),
            // Master A Output Device Selector
            SizedBox(
              width: 140,
              height: 40,
              child: AudioOutletSelector(
                label: 'A',
                color: AppColors.accent,
                selectedDeviceName: engine.masterADeviceName,
                onDeviceSelected: (device) {
                  engine.setMasterAOutputDevice(device.name, pan: device.pan, deviceId: device.id);
                },
              ),
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 24, color: AppColors.border),
            const SizedBox(width: 12),
            
            // MASTER B
            const Text(
              'B',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.orange,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  activeTrackColor: Colors.orange,
                  inactiveTrackColor: AppColors.surfaceLighter,
                  thumbColor: Colors.orange,
                ),
                child: Slider(
                  value: engine.masterBVolume,
                  onChanged: (val) => engine.setMasterBVolume(val),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Master B Mute Button
            _buildMuteButton(
              isMuted: engine.masterBMuted,
              color: Colors.orange,
              onTap: () => engine.toggleMasterBMute(),
              size: 24,
            ),
            const SizedBox(width: 12),
            // Master B Output Device Selector
            SizedBox(
              width: 140,
              height: 40,
              child: AudioOutletSelector(
                label: 'B',
                color: Colors.orange,
                selectedDeviceName: engine.masterBDeviceName,
                onDeviceSelected: (device) {
                  engine.setMasterBOutputDevice(device.name, pan: device.pan, deviceId: device.id);
                },
              ),
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 24, color: AppColors.border),
            const SizedBox(width: 12),
            
            // Metronome
            const Icon(
              Icons.timer_outlined,
              size: 16,
              color: AppColors.soloYellow,
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 80,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: AppColors.soloYellow,
                  inactiveTrackColor: AppColors.surfaceLighter,
                  thumbColor: AppColors.soloYellow,
                ),
                child: Slider(
                  value: engine.metronomeVolume,
                  onChanged: (val) => engine.setMetronomeVolume(val),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Future<String?> _showSaveProjectDialog(BuildContext context) async {
    String name = "";
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Salvar Projeto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Digite o nome do seu projeto:'),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                onChanged: (value) => name = value,
                decoration: const InputDecoration(
                  hintText: 'ex: meu_projeto',
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, name),
              child: const Text('Salvar', style: TextStyle(color: AppColors.accent)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransportAction({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceLighter,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildQuickPlayButton() {
    final isPlaying = engine.isPlaying;
    return GestureDetector(
      onTap: () => engine.togglePlayPause(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isPlaying ? AppColors.surfaceLighter : AppColors.playGreen,
          shape: BoxShape.circle,
          border: Border.all(
            color: isPlaying ? AppColors.accent : AppColors.playGreen,
            width: 1.5,
          ),
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: isPlaying ? AppColors.accent : AppColors.background,
          size: 20,
        ),
      ),
    );
  }
}
