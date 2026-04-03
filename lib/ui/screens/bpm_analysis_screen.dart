import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import '../../core/audio/audio_engine.dart';
import '../../core/models/track_model.dart';
import '../../ui/theme/app_colors.dart';
import '../../core/utils/constants.dart';

class BpmAnalysisScreen extends StatefulWidget {
  final AudioEngine engine;
  final TrackModel track;

  const BpmAnalysisScreen({
    super.key,
    required this.engine,
    required this.track,
  });

  @override
  State<BpmAnalysisScreen> createState() => _BpmAnalysisScreenState();
}

class _BpmAnalysisScreenState extends State<BpmAnalysisScreen> {
  double _markerStartMs = 0.0;
  double _markerEndMs = 0.0;
  
  // Compasso local (iniciado do global)
  int _beatsPerBar = 4;
  int _beatUnit = 4;
  
  double _calculatedBpm = 120.0;
  double _zoomLevel = 1.0;
  bool _isPlaying = false;
  double _playbackMs = 0.0;
  Timer? _playbackTimer;
  
  List<double> _peaks = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _beatsPerBar = widget.engine.timeSignature.beatsPerBar;
    _beatUnit = widget.engine.timeSignature.beatUnit;
    
    _markerStartMs = 100.0;
    _markerEndMs = math.min(1100.0, widget.track.totalDuration.inMilliseconds.toDouble());
    _generateWaveform();
    _calculateBpm();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    if (_isPlaying) widget.engine.stopAll();
    _scrollController.dispose();
    super.dispose();
  }

  void _generateWaveform() {
    final seed = widget.track.filePath?.hashCode ?? widget.track.id.hashCode;
    final random = math.Random(seed);
    const points = 800;
    _peaks = List.generate(points, (i) {
      double base = 0.1;
      if (i % 8 == 0) base += 0.5 + random.nextDouble() * 0.4;
      if (i % 16 == 0) base += 0.2;
      double energy = math.sin(i / points * math.pi * 10) * 0.2 + 0.3;
      return (base * energy + random.nextDouble() * 0.1).clamp(0.05, 1.0);
    });
  }

  void _calculateBpm() {
    final diffMs = _markerEndMs - _markerStartMs;
    if (diffMs > 1.0) {
      setState(() {
        _calculatedBpm = (_beatsPerBar * 60000.0) / diffMs;
      });
    }
  }

  void _togglePlayback() {
    if (_isPlaying) {
      widget.engine.stopAll();
      _playbackTimer?.cancel();
    } else {
      widget.engine.playTrack(
        widget.track.id, 
        position: Duration(milliseconds: _playbackMs.toInt())
      );
      
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
        if (mounted) {
          setState(() {
            _playbackMs = widget.engine.currentPosition.inMilliseconds.toDouble();
          });
          if (_playbackMs >= widget.track.totalDuration.inMilliseconds) {
            _togglePlayback();
          }
        }
      });
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  void _showTimeSignaturePicker() {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selecione o Compasso', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kTimeSignatures.map((ts) {
                  final b = ts['beats']!;
                  final u = ts['unit']!;
                  final isSel = _beatsPerBar == b && _beatUnit == u;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _beatsPerBar = b;
                        _beatUnit = u;
                      });
                      _calculateBpm();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.accent : AppColors.surfaceLighter,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSel ? Colors.white24 : AppColors.border),
                      ),
                      child: Text('$b/$u', style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        color: isSel ? Colors.white : AppColors.textSecondary)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.track.totalDuration.inMilliseconds.toDouble();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Analisador de BPM', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Text(widget.track.name, style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildBpmBar(),
          _buildToolbar(),
          
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final waveWidth = constraints.maxWidth * _zoomLevel;
                    return SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: waveWidth,
                        height: constraints.maxHeight,
                        child: Stack(
                          children: [
                            _buildGrid(waveWidth),
                            _buildWaveformLines(constraints.maxHeight),
                            _buildPlaybackCursor(totalMs, waveWidth),
                            _buildMarker(
                              positionMs: _markerStartMs,
                              totalMs: totalMs,
                              width: waveWidth,
                              color: AppColors.playGreen,
                              label: 'INÍCIO',
                              onChanged: (ms) {
                                setState(() => _markerStartMs = ms.clamp(0, _markerEndMs - 0.1));
                                _calculateBpm();
                              },
                            ),
                            _buildMarker(
                              positionMs: _markerEndMs,
                              totalMs: totalMs,
                              width: waveWidth,
                              color: AppColors.stopRed,
                              label: 'FIM',
                              onChanged: (ms) {
                                setState(() => _markerEndMs = ms.clamp(_markerStartMs + 0.1, totalMs));
                                _calculateBpm();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildBpmBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // BPM DISPLAY
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('RESULTADO', style: TextStyle(fontSize: 9, letterSpacing: 1, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(_calculatedBpm.toStringAsFixed(1), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(width: 4),
                  const Text('BPM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent)),
                ],
              ),
            ],
          ),
          
          const Spacer(),
          Container(width: 1, height: 32, color: Colors.white10),
          const Spacer(),

          // TIME SIGNATURE PICKER
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('COMPASSO', style: TextStyle(fontSize: 9, letterSpacing: 1, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: _showTimeSignaturePicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Text('$_beatsPerBar/$_beatUnit', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accent, fontFamily: 'monospace')),
                      const Icon(Icons.arrow_drop_down_rounded, color: AppColors.accent, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildCircleBtn(
            Icons.skip_previous_rounded,
            () {
              setState(() => _playbackMs = 0.0);
              if (_isPlaying) {
                widget.engine.playTrack(widget.track.id, position: Duration.zero);
              } else {
                widget.engine.stopAll();
              }
              _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
            },
            size: 20,
            color: AppColors.surfaceLighter,
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _togglePlayback,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isPlaying ? AppColors.stopRed : AppColors.accent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: (_isPlaying ? AppColors.stopRed : AppColors.accent).withValues(alpha: 0.4), blurRadius: 8)],
              ),
              child: Icon(_isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.zoom_in_rounded, size: 16, color: AppColors.textMuted),
          Expanded(
            child: Slider(
              value: _zoomLevel,
              min: 1.0,
              max: 40.0,
              activeColor: AppColors.accent,
              onChanged: (v) => setState(() => _zoomLevel = v),
            ),
          ),
          Text('${_zoomLevel.toStringAsFixed(0)}x', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildGrid(double width) {
    return Positioned.fill(
      child: Column(
        children: List.generate(4, (i) => Expanded(
          child: Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.1))))),
        )),
      ),
    );
  }

  Widget _buildWaveformLines(double height) {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: _peaks.map((p) => Expanded(
            child: Container(
              height: p * (height - 20),
              margin: const EdgeInsets.symmetric(horizontal: 0.5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accent.withValues(alpha: 0.8), AppColors.accent.withValues(alpha: 0.2)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildPlaybackCursor(double totalMs, double waveWidth) {
    final x = (totalMs > 0) ? (_playbackMs / totalMs) * waveWidth : 0.0;
    return Positioned(
      left: x,
      top: 0,
      bottom: 0,
      child: Container(
        width: 1.5, 
        decoration: BoxDecoration(
          color: Colors.yellow,
          boxShadow: [BoxShadow(color: Colors.yellow.withValues(alpha: 0.5), blurRadius: 4)],
        ),
      ),
    );
  }

  Widget _buildMarker({
    required double positionMs,
    required double totalMs,
    required double width,
    required Color color,
    required String label,
    required Function(double) onChanged,
  }) {
    final x = (totalMs > 0) ? (positionMs / totalMs) * width : 0.0;
    return Positioned(
      left: x - 20,
      top: 0,
      bottom: 0,
      width: 40,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) {
          final newX = (x + details.delta.dx).clamp(0.0, width);
          onChanged((newX / width) * totalMs);
        },
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)]),
              child: Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
            Expanded(child: Center(child: Container(width: 2, decoration: BoxDecoration(color: color)))),
            Icon(Icons.arrow_drop_up_rounded, color: color, size: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 11)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 4,
              ),
              onPressed: () {
                final finalBpm = _calculatedBpm;
                widget.engine.setTimeSignature(_beatsPerBar, _beatUnit);
                widget.engine.setBpm(finalBpm);
                if (Navigator.canPop(context)) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Projeto Atualizado: ${finalBpm.toStringAsFixed(1)} BPM em $_beatsPerBar/$_beatUnit'),
                    backgroundColor: AppColors.playGreen,
                  ),
                );
              },
              child: const Text('APLICAR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleBtn(IconData icon, VoidCallback onTap, {double size = 22, Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: EdgeInsets.all(size / 2 - 2),
        decoration: BoxDecoration(
          color: color ?? AppColors.surfaceLighter,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: size, color: Colors.white),
      ),
    );
  }
}
