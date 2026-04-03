import 'package:flutter/material.dart';
import 'package:vs_executor/core/audio/audio_engine.dart';
import 'package:vs_executor/core/models/session_marker.dart';
import 'package:vs_executor/ui/theme/app_colors.dart';
import 'dart:math' as math;

class InteractiveTimeline extends StatefulWidget {
  final AudioEngine engine;

  const InteractiveTimeline({super.key, required this.engine});

  @override
  State<InteractiveTimeline> createState() => _InteractiveTimelineState();
}

class _InteractiveTimelineState extends State<InteractiveTimeline> {
  String? _draggingMarkerId;
  String? _resizingMarkerId;
  bool _isDraggingLoop = false;
  double _zoomFactor = 1.0; // Nível de zoom inicial
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.engine.addListener(_onEngineUpdate);
  }

  @override
  void dispose() {
    widget.engine.removeListener(_onEngineUpdate);
    _scrollController.dispose();
    super.dispose();
  }

  void _onEngineUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.engine.totalDuration.inMilliseconds.toDouble();
    if (totalMs <= 0) return _buildEmpty();

    final currentMs = widget.engine.currentPosition.inMilliseconds.toDouble();
    final progress = (currentMs / totalMs).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // A largura total da trilha agora é influenciada pelo zoom
              final baseWidth = constraints.maxWidth;
              final contentWidth = baseWidth * _zoomFactor;
              final barMs = widget.engine.timeSignature.barDurationMs(widget.engine.bpm);
              final numBars = totalMs > 0 ? (totalMs / barMs).ceil() : 0;

              return Container(
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: contentWidth,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        // 1. Grid e Compassos
                        ...List.generate(5, (index) => Positioned(
                          left: 0, right: 0, top: 10 + (index * 10.0),
                          child: Container(height: 1, color: AppColors.border.withValues(alpha: 0.1)),
                        )),
                        ...List.generate(numBars, (index) {
                          final x = (index * barMs / totalMs) * contentWidth;
                          final barWidth = ((index + 1) * barMs / totalMs) * contentWidth - x;
                          if (x > contentWidth) return const SizedBox.shrink();
                          return Positioned(
                            left: x, width: barWidth, top: 0, bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: index % 2 == 0 ? AppColors.surfaceLighter.withValues(alpha: 0.2) : Colors.transparent,
                                border: Border(right: BorderSide(color: AppColors.border.withValues(alpha: 0.3), width: 1)),
                              ),
                            ),
                          );
                        }),

                        // 3. CAMADA DE INTERAÇÃO DE FUNDO
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (details) {
                              if (_draggingMarkerId == null && _resizingMarkerId == null && !_isDraggingLoop) {
                                _seekTo(details.localPosition.dx, contentWidth, totalMs);
                              }
                            },
                            onLongPressStart: (details) {
                              final ratio = (details.localPosition.dx / contentWidth).clamp(0.0, 1.0);
                              final posMs = ratio * totalMs;
                              final snappedMs = widget.engine.timeSignature.quantizeToNearestBar(posMs, widget.engine.bpm);
                              int colorIndex = widget.engine.markers.length % 8;
                              widget.engine.addMarkerAt('Seção ${widget.engine.markers.length + 1}', snappedMs, colorIndex: colorIndex, endMs: snappedMs + barMs);
                            },
                          ),
                        ),

                        // 4. Região de Loop
                        if (widget.engine.isLooping)
                          _buildLoopRegion(contentWidth, totalMs, barMs),

                        // 5. Marcadores de Sessão
                        ...widget.engine.markers.map((marker) => _buildMarker(marker, contentWidth, totalMs, barMs)),

                        // 6. Playhead (Visual)
                        Positioned(
                          left: progress * contentWidth - 1, top: 0, bottom: 0,
                          child: IgnorePointer(
                            child: Container(
                              width: 2, decoration: BoxDecoration(color: AppColors.accent, boxShadow: [BoxShadow(color: AppColors.accentGlow, blurRadius: 4)]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Controles de Zoom (Flutuantes na Direita)
          Positioned(
            right: 4,
            top: 4,
            bottom: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildZoomButton(Icons.add_rounded, () {
                  setState(() => _zoomFactor = (_zoomFactor * 1.4).clamp(1.0, 10.0));
                }),
                const SizedBox(height: 4),
                _buildZoomButton(Icons.remove_rounded, () {
                  setState(() => _zoomFactor = (_zoomFactor / 1.4).clamp(1.0, 10.0));
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.surfaceLighter.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(height: 60, color: AppColors.background, alignment: Alignment.bottomCenter, child: Container(height: 1, color: AppColors.border)),
    );
  }

  Widget _buildLoopRegion(double width, double totalMs, double barMs) {
    if (widget.engine.loopStartMs == null || widget.engine.loopEndMs == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) { widget.engine.setLoopZone(0.0, barMs * 4); });
      return const SizedBox.shrink();
    }

    final startMs = widget.engine.loopStartMs!;
    final endMs = widget.engine.loopEndMs!;
    final startX = (startMs / totalMs) * width;
    final endX = (endMs / totalMs) * width;

    return Positioned(
      left: startX, width: math.max(endX - startX, 10.0), top: 0, height: 18,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () { widget.engine.seekTo(Duration(milliseconds: startMs.toInt())); },
        onHorizontalDragStart: (_) => setState(() => _isDraggingLoop = true),
        onHorizontalDragUpdate: (details) {
          final deltaMs = (details.delta.dx / width) * totalMs;
          var newStart = startMs + deltaMs;
          newStart = newStart.clamp(0.0, totalMs - (endMs - startMs));
          widget.engine.setLoopZone(newStart, newStart + (endMs - startMs));
        },
        onHorizontalDragEnd: (_) {
          setState(() => _isDraggingLoop = false);
          final snappedStart = widget.engine.timeSignature.quantizeToNearestBar(widget.engine.loopStartMs!, widget.engine.bpm);
          final diff = endMs - startMs;
          widget.engine.setLoopZone(snappedStart, snappedStart + diff);
        },
        child: Container(
          decoration: BoxDecoration(color: AppColors.playGreen.withValues(alpha: 0.25), border: Border.all(color: AppColors.playGreen, width: 1.5), borderRadius: BorderRadius.circular(4)),
          child: Stack(
            children: [
              _buildResizeHandle(true, (newStart) => widget.engine.setLoopZone(newStart, endMs), () {
                 final snapped = widget.engine.timeSignature.quantizeToNearestBar(widget.engine.loopStartMs!, widget.engine.bpm);
                 widget.engine.setLoopZone(snapped, endMs);
              }, startMs, endMs, barMs, width, totalMs, AppColors.playGreen),
              const Align(alignment: Alignment.center, child: Icon(Icons.loop_rounded, size: 10, color: AppColors.playGreen)),
              _buildResizeHandle(false, (newEnd) => widget.engine.setLoopZone(startMs, newEnd), () {
                 final snapped = widget.engine.timeSignature.quantizeToNearestBar(widget.engine.loopEndMs!, widget.engine.bpm);
                 widget.engine.setLoopZone(startMs, snapped);
              }, startMs, endMs, barMs, width, totalMs, AppColors.playGreen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarker(SessionMarker marker, double width, double totalMs, double barMs) {
    final startMs = marker.positionMs;
    final durationMs = marker.durationMs ?? barMs;

    return Positioned(
      left: (startMs / totalMs) * width, top: 22, bottom: 4, width: math.max((durationMs / totalMs) * width, 10.0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () { widget.engine.seekTo(Duration(milliseconds: startMs.toInt())); },
        onHorizontalDragStart: (_) => setState(() => _draggingMarkerId = marker.id),
        onHorizontalDragUpdate: (details) {
          final deltaMs = (details.delta.dx / width) * totalMs;
          var newStart = marker.positionMs + deltaMs;
          newStart = newStart.clamp(0.0, totalMs - durationMs);
          setState(() { marker.positionMs = newStart; if (marker.endPositionMs != null) marker.endPositionMs = newStart + durationMs; });
        },
        onHorizontalDragEnd: (_) {
          setState(() => _draggingMarkerId = null);
          final snappedStart = widget.engine.timeSignature.quantizeToNearestBar(marker.positionMs, widget.engine.bpm);
          setState(() { marker.positionMs = snappedStart; marker.endPositionMs = snappedStart + durationMs; });
        },
        onLongPress: () { widget.engine.removeMarker(marker.id); },
        child: Container(
          decoration: BoxDecoration(color: marker.color.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(4), border: Border.all(color: marker.color, width: 2), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, 2))]),
          child: Stack(
            children: [
              Positioned(
                left: 6, top: 4, right: 24,
                child: GestureDetector(
                  onTap: () => _showRenameDialog(marker),
                  child: Text(marker.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: marker.color, shadows: [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 2)])),
                ),
              ),
              _buildMarkerResizeHandle(marker, width, totalMs, barMs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResizeHandle(bool isLeft, Function(double) onUpdate, VoidCallback onEnd, double startMs, double endMs, double barMs, double width, double totalMs, Color color) {
    return Positioned(
      left: isLeft ? 0 : null, right: isLeft ? null : 0, top: 0, bottom: 0, width: 30,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _isDraggingLoop = true),
        onHorizontalDragUpdate: (details) {
          final deltaMs = (details.delta.dx / width) * totalMs;
          if (isLeft) {
            onUpdate((startMs + deltaMs).clamp(0.0, endMs - barMs));
          } else {
            onUpdate((endMs + deltaMs).clamp(startMs + barMs, totalMs));
          }
        },
        onHorizontalDragEnd: (_) { setState(() => _isDraggingLoop = false); onEnd(); },
        child: Center(child: Container(width: 3, height: 10, color: color)),
      ),
    );
  }

  Widget _buildMarkerResizeHandle(SessionMarker marker, double width, double totalMs, double barMs) {
    return Positioned(
      right: 0, top: 0, bottom: 0, width: 24,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _resizingMarkerId = marker.id),
        onHorizontalDragUpdate: (details) {
          final deltaMs = (details.delta.dx / width) * totalMs;
          var newEnd = (marker.endPositionMs ?? (marker.positionMs + barMs)) + deltaMs;
          newEnd = math.max(newEnd, marker.positionMs + barMs * 0.5);
          newEnd = math.min(newEnd, totalMs);
          setState(() { marker.endPositionMs = newEnd; });
        },
        onHorizontalDragEnd: (_) {
          setState(() => _resizingMarkerId = null);
          final currentEnd = marker.endPositionMs ?? (marker.positionMs + barMs);
          final snappedEnd = widget.engine.timeSignature.quantizeToNearestBar(currentEnd, widget.engine.bpm);
          setState(() { marker.endPositionMs = math.max(snappedEnd, marker.positionMs + barMs); });
        },
        child: Center(child: Container(width: 4, height: 18, decoration: BoxDecoration(color: marker.color, borderRadius: BorderRadius.circular(2)))),
      ),
    );
  }

  void _showRenameDialog(SessionMarker marker) {
    if (_draggingMarkerId != null || _resizingMarkerId != null) return;
    final controller = TextEditingController(text: marker.name);
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface, title: const Text('Renomear Seção'),
      content: TextField(controller: controller, autofocus: true, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(labelText: 'Nome da Seção', labelStyle: TextStyle(color: AppColors.textMuted))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: () { setState(() { marker.name = controller.text; }); widget.engine.notifyListeners(); Navigator.pop(context); }, child: const Text('Salvar')),
      ],
    ));
  }

  void _seekTo(double localX, double totalWidth, double totalMs) {
    if (totalMs <= 0) return;
    final ratio = (localX / totalWidth).clamp(0.0, 1.0);
    final seekMs = ratio * totalMs;
    widget.engine.seekTo(Duration(milliseconds: seekMs.toInt()));
  }
}
