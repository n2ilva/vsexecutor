import 'dart:math';
import 'dart:typed_data';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE DADOS DO WAVEFORM
// ─────────────────────────────────────────────────────────────────────────────

class WaveformData {
  /// Picos positivos por pixel/coluna
  final Float32List peaks;

  /// Picos negativos por pixel/coluna (valores negativos)
  final Float32List troughs;

  /// RMS por coluna (energia real — mais fiel ao som percebido)
  final Float32List rms;

  /// Duração total em segundos
  final double duration;

  /// Sample rate original
  final int sampleRate;

  const WaveformData({
    required this.peaks,
    required this.troughs,
    required this.rms,
    required this.duration,
    required this.sampleRate,
  });

  int get length => peaks.length;
}

// ─────────────────────────────────────────────────────────────────────────────
// PROCESSADOR — roda em Isolate para não travar a UI
// ─────────────────────────────────────────────────────────────────────────────

class WaveformProcessor {
  /// Processa PCM Float32 em isolate separado.
  /// [pcmSamples]  : amostras Float32 normalizadas [-1.0, 1.0]
  /// [sampleRate]  : ex. 44100, 48000
  /// [resolution]  : número de colunas desejadas (geralmente largura em pixels)
  /// [channels]    : 1 = mono, 2 = stereo
  static Future<WaveformData> process({
    required Float32List pcmSamples,
    required int sampleRate,
    required int resolution,
    int channels = 2,
  }) async {
    return await Isolate.run(() {
      return _processSync(
        pcmSamples: pcmSamples,
        sampleRate: sampleRate,
        resolution: resolution,
        channels: channels,
      );
    });
  }

  static WaveformData _processSync({
    required Float32List pcmSamples,
    required int sampleRate,
    required int resolution,
    required int channels,
  }) {
    // Se stereo, faz downmix para mono antes de processar
    final mono = channels == 2
        ? _downmixToMono(pcmSamples)
        : pcmSamples;

    final totalFrames = mono.length;
    final framesPerColumn = totalFrames / resolution;

    final peaks   = Float32List(resolution);
    final troughs = Float32List(resolution);
    final rms     = Float32List(resolution);

    for (int col = 0; col < resolution; col++) {
      final start = (col * framesPerColumn).floor();
      final end   = ((col + 1) * framesPerColumn).ceil().clamp(0, totalFrames);

      if (start >= totalFrames) break;

      double maxPeak   = 0.0;
      double minTrough = 0.0;
      double sumSq     = 0.0;
      int    count     = end - start;

      for (int i = start; i < end; i++) {
        final s = mono[i];
        if (s > maxPeak)   maxPeak   = s;
        if (s < minTrough) minTrough = s;
        sumSq += s * s;
      }

      peaks[col]   = maxPeak;
      troughs[col] = minTrough;
      rms[col]     = sqrt(sumSq / count);
    }

    final duration = totalFrames / sampleRate.toDouble();

    return WaveformData(
      peaks: peaks,
      troughs: troughs,
      rms: rms,
      duration: duration,
      sampleRate: sampleRate,
    );
  }

  static Float32List _downmixToMono(Float32List stereo) {
    final frames = stereo.length ~/ 2;
    final mono   = Float32List(frames);
    for (int i = 0; i < frames; i++) {
      mono[i] = (stereo[i * 2] + stereo[i * 2 + 1]) * 0.5;
    }
    return mono;
  }

  // Gera dados fake para preview/teste sem arquivo real
  static WaveformData generateFake({int resolution = 800}) {
    final rng     = Random();
    final peaks   = Float32List(resolution);
    final troughs = Float32List(resolution);
    final rms     = Float32List(resolution);

    double energy = 0.3;
    for (int i = 0; i < resolution; i++) {
      // Simula envelope natural com variação suave
      energy += (rng.nextDouble() - 0.5) * 0.05;
      energy  = energy.clamp(0.05, 0.95);

      final peak = energy * (0.7 + rng.nextDouble() * 0.3);
      peaks[i]   =  peak;
      troughs[i] = -peak * (0.8 + rng.nextDouble() * 0.2);
      rms[i]     =  peak * 0.6;
    }

    return WaveformData(
      peaks: peaks,
      troughs: troughs,
      rms: rms,
      duration: 180.0,
      sampleRate: 44100,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ESTILOS VISUAIS
// ─────────────────────────────────────────────────────────────────────────────

enum WaveformStyle {
  /// Picos + troughs simétricos — estilo clássico DAW (Ableton, Logic)
  classic,

  /// Apenas RMS preenchido — estilo "solid" (Serato, rekordbox)
  solid,

  /// Espelho: canal superior = peak, inferior = RMS
  mirror,

  /// Barras verticais por coluna — estilo retro
  bars,
}

class WaveformColors {
  final Color played;       // região já tocada
  final Color unplayed;     // região ainda não tocada
  final Color rmsPlayed;    // RMS da região tocada
  final Color rmsUnplayed;  // RMS da região não tocada
  final Color playhead;     // linha do playhead
  final Color background;   // fundo do waveform

  const WaveformColors({
    this.played      = const Color(0xFFFF6B35),
    this.unplayed    = const Color(0xFF4A9EFF),
    this.rmsPlayed   = const Color(0xFFFF9A6C),
    this.rmsUnplayed = const Color(0xFF82C4FF),
    this.playhead    = const Color(0xFFFFFFFF),
    this.background  = const Color(0xFF1A1A2E),
  });

  // Preset: estilo Ableton
  static const ableton = WaveformColors(
    played:      Color(0xFFFF8C00),
    unplayed:    Color(0xFF888888),
    rmsPlayed:   Color(0xFFFFAA44),
    rmsUnplayed: Color(0xFFAAAAAA),
    playhead:    Color(0xFFFFFFFF),
    background:  Color(0xFF1E1E1E),
  );

  // Preset: estilo Logic Pro
  static const logic = WaveformColors(
    played:      Color(0xFF00C2FF),
    unplayed:    Color(0xFF3D7EAA),
    rmsPlayed:   Color(0xFF66D9FF),
    rmsUnplayed: Color(0xFF5A9EC4),
    playhead:    Color(0xFFFF3B30),
    background:  Color(0xFF2C2C2E),
  );

  // Preset: estilo rekordbox
  static const rekordbox = WaveformColors(
    played:      Color(0xFFFF2D55),
    unplayed:    Color(0xFF1DB954),
    rmsPlayed:   Color(0xFFFF6B81),
    rmsUnplayed: Color(0xFF57E389),
    playhead:    Color(0xFFFFFFFF),
    background:  Color(0xFF121212),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTER — núcleo do waveform
// ─────────────────────────────────────────────────────────────────────────────

class WaveformPainter extends CustomPainter {
  final WaveformData data;

  /// Posição atual de playback [0.0 – 1.0]
  final double progress;

  /// Posição de zoom: início [0.0 – 1.0]
  final double viewStart;

  /// Posição de zoom: fim [0.0 – 1.0]
  final double viewEnd;

  final WaveformStyle style;
  final WaveformColors colors;

  /// Fator de amplificação visual [0.5 – 3.0]
  final double gain;

  /// Se true, desenha linha de centro
  final bool showCenterLine;

  /// Se true, exibe reflexo espelhado na metade inferior
  final bool showReflection;

  WaveformPainter({
    required this.data,
    required this.progress,
    this.viewStart      = 0.0,
    this.viewEnd        = 1.0,
    this.style          = WaveformStyle.classic,
    this.colors         = const WaveformColors(),
    this.gain           = 1.0,
    this.showCenterLine = true,
    this.showReflection = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fundo
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = colors.background,
    );

    if (data.length == 0) return;

    final mid = size.height / 2;

    // Linha central
    if (showCenterLine) {
      canvas.drawLine(
        Offset(0, mid),
        Offset(size.width, mid),
        Paint()
          ..color       = colors.unplayed.withOpacity(0.15)
          ..strokeWidth = 0.5,
      );
    }

    // Região visível do waveform
    final viewRange   = viewEnd - viewStart;
    final playheadX   = ((progress - viewStart) / viewRange) * size.width;

    switch (style) {
      case WaveformStyle.classic:
        _paintClassic(canvas, size, mid, playheadX, viewRange);
      case WaveformStyle.solid:
        _paintSolid(canvas, size, mid, playheadX, viewRange);
      case WaveformStyle.mirror:
        _paintMirror(canvas, size, mid, playheadX, viewRange);
      case WaveformStyle.bars:
        _paintBars(canvas, size, mid, playheadX, viewRange);
    }

    // Reflexo (opcional)
    if (showReflection) {
      _paintReflection(canvas, size, mid, playheadX, viewRange);
    }

    // Playhead
    _paintPlayhead(canvas, size, playheadX);
  }

  // ── Classic: peak + trough simétricas ──────────────────────────────────────
  void _paintClassic(Canvas canvas, Size size, double mid,
      double playheadX, double viewRange) {
    for (int x = 0; x < size.width; x++) {
      final dataIdx = _xToDataIndex(x, size.width, viewRange);
      if (dataIdx >= data.length) break;

      final isPlayed = x < playheadX;
      final peakColor = isPlayed ? colors.played    : colors.unplayed;
      final rmsColor  = isPlayed ? colors.rmsPlayed : colors.rmsUnplayed;

      final peak    = (data.peaks[dataIdx]   * gain).clamp(0.0, 1.0);
      final trough  = (data.troughs[dataIdx] * gain).clamp(-1.0, 0.0);
      final rmsVal  = (data.rms[dataIdx]     * gain).clamp(0.0, 1.0);

      final peakY   = mid - peak   * mid;
      final troughY = mid - trough * mid;
      final rmsTopY = mid - rmsVal * mid;
      final rmsBotY = mid + rmsVal * mid;

      final xd = x.toDouble();

      // Peak/trough (mais transparente)
      canvas.drawLine(
        Offset(xd, peakY),
        Offset(xd, troughY),
        Paint()
          ..color       = peakColor.withOpacity(0.45)
          ..strokeWidth = 1.0,
      );

      // RMS (mais sólido — representa o que o ouvido percebe)
      canvas.drawLine(
        Offset(xd, rmsTopY),
        Offset(xd, rmsBotY),
        Paint()
          ..color       = rmsColor.withOpacity(0.9)
          ..strokeWidth = 1.0,
      );
    }
  }

  // ── Solid: área preenchida com RMS ─────────────────────────────────────────
  void _paintSolid(Canvas canvas, Size size, double mid,
      double playheadX, double viewRange) {
    final playedPath   = Path();
    final unplayedPath = Path();

    bool playedStarted   = false;
    bool unplayedStarted = false;

    for (int x = 0; x < size.width; x++) {
      final dataIdx = _xToDataIndex(x, size.width, viewRange);
      if (dataIdx >= data.length) break;

      final rmsVal = (data.rms[dataIdx] * gain).clamp(0.0, 1.0);
      final topY   = mid - rmsVal * mid;
      final botY   = mid + rmsVal * mid;
      final xd     = x.toDouble();

      if (x < playheadX) {
        if (!playedStarted) {
          playedPath.moveTo(xd, mid);
          playedStarted = true;
        }
        playedPath.lineTo(xd, topY);
      } else {
        if (!unplayedStarted) {
          unplayedPath.moveTo(xd, mid);
          unplayedStarted = true;
        }
        unplayedPath.lineTo(xd, topY);
      }
    }

    // Fecha os caminhos pela parte inferior (espelho)
    for (int x = size.width.toInt() - 1; x >= 0; x--) {
      final dataIdx = _xToDataIndex(x, size.width, viewRange);
      if (dataIdx >= data.length) continue;

      final rmsVal = (data.rms[dataIdx] * gain).clamp(0.0, 1.0);
      final botY   = mid + rmsVal * mid;
      final xd     = x.toDouble();

      if (x < playheadX) {
        playedPath.lineTo(xd, botY);
      } else {
        unplayedPath.lineTo(xd, botY);
      }
    }

    playedPath.close();
    unplayedPath.close();

    canvas.drawPath(
      playedPath,
      Paint()
        ..color = colors.played.withOpacity(0.8)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      unplayedPath,
      Paint()
        ..color = colors.unplayed.withOpacity(0.7)
        ..style = PaintingStyle.fill,
    );
  }

  // ── Mirror: peak em cima, RMS embaixo ──────────────────────────────────────
  void _paintMirror(Canvas canvas, Size size, double mid,
      double playheadX, double viewRange) {
    for (int x = 0; x < size.width; x++) {
      final dataIdx = _xToDataIndex(x, size.width, viewRange);
      if (dataIdx >= data.length) break;

      final isPlayed = x < playheadX;
      final topColor = isPlayed ? colors.played    : colors.unplayed;
      final botColor = isPlayed ? colors.rmsPlayed : colors.rmsUnplayed;

      final peak   = (data.peaks[dataIdx] * gain).clamp(0.0, 1.0);
      final rmsVal = (data.rms[dataIdx]   * gain).clamp(0.0, 1.0);

      final xd = x.toDouble();

      // Metade superior: peak
      canvas.drawLine(
        Offset(xd, mid),
        Offset(xd, mid - peak * mid),
        Paint()
          ..color       = topColor.withOpacity(0.9)
          ..strokeWidth = 1.0,
      );

      // Metade inferior: RMS
      canvas.drawLine(
        Offset(xd, mid),
        Offset(xd, mid + rmsVal * mid),
        Paint()
          ..color       = botColor.withOpacity(0.7)
          ..strokeWidth = 1.0,
      );
    }
  }

  // ── Bars: blocos verticais estilo retro ────────────────────────────────────
  void _paintBars(Canvas canvas, Size size, double mid,
      double playheadX, double viewRange) {
    const barWidth  = 3.0;
    const barGap    = 1.0;
    const barStride = barWidth + barGap;

    for (double x = 0; x < size.width; x += barStride) {
      final dataIdx = _xToDataIndex(x.toInt(), size.width, viewRange);
      if (dataIdx >= data.length) break;

      final isPlayed = x < playheadX;
      final color    = isPlayed ? colors.played : colors.unplayed;

      final peak = (data.peaks[dataIdx] * gain).clamp(0.0, 1.0);
      final h    = peak * mid * 2;

      canvas.drawRect(
        Rect.fromLTWH(x, mid - h / 2, barWidth, h),
        Paint()
          ..color = color.withOpacity(0.85)
          ..style = PaintingStyle.fill,
      );
    }
  }

  // ── Reflexo suave na metade inferior ──────────────────────────────────────
  void _paintReflection(Canvas canvas, Size size, double mid,
      double playheadX, double viewRange) {
    for (int x = 0; x < size.width; x++) {
      final dataIdx = _xToDataIndex(x, size.width, viewRange);
      if (dataIdx >= data.length) break;

      final isPlayed = x < playheadX;
      final color    = isPlayed ? colors.played : colors.unplayed;
      final rmsVal   = (data.rms[dataIdx] * gain * 0.4).clamp(0.0, 1.0);
      final xd       = x.toDouble();

      // Reflexo abaixo com gradiente de opacidade
      for (int dy = 0; dy < (rmsVal * mid).toInt(); dy++) {
        final opacity = (1.0 - dy / (rmsVal * mid)) * 0.25;
        canvas.drawPoints(
          PointMode.points,
          [Offset(xd, mid + dy)],
          Paint()
            ..color       = color.withOpacity(opacity)
            ..strokeWidth = 1.0,
        );
      }
    }
  }

  // ── Playhead ───────────────────────────────────────────────────────────────
  void _paintPlayhead(Canvas canvas, Size size, double x) {
    if (x < 0 || x > size.width) return;

    // Sombra
    canvas.drawLine(
      Offset(x + 1, 0),
      Offset(x + 1, size.height),
      Paint()
        ..color       = Colors.black.withOpacity(0.4)
        ..strokeWidth = 2.0,
    );

    // Linha principal
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color       = colors.playhead
        ..strokeWidth = 1.5,
    );

    // Triângulo superior
    final tri = Path()
      ..moveTo(x - 5, 0)
      ..lineTo(x + 5, 0)
      ..lineTo(x, 8)
      ..close();

    canvas.drawPath(tri, Paint()..color = colors.playhead);
  }

  // ── Utilitário: converte pixel X → índice no array de dados ───────────────
  int _xToDataIndex(int x, double width, double viewRange) {
    final progress = x / width;
    final dataProgress = viewStart + progress * viewRange;
    return (dataProgress * data.length).floor().clamp(0, data.length - 1);
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.progress  != progress  ||
      old.viewStart != viewStart ||
      old.viewEnd   != viewEnd   ||
      old.data      != data      ||
      old.style     != style;
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET COMPLETO — pronto para usar no seu app
// ─────────────────────────────────────────────────────────────────────────────

class WaveformWidget extends StatefulWidget {
  final WaveformData? data;
  final double progress;        // 0.0 – 1.0
  final double height;
  final WaveformStyle style;
  final WaveformColors colors;
  final double gain;
  final bool showReflection;
  final bool showTimeRuler;
  final ValueChanged<double>? onSeek;   // callback ao clicar para seekar

  const WaveformWidget({
    super.key,
    this.data,
    required this.progress,
    this.height        = 80,
    this.style         = WaveformStyle.classic,
    this.colors        = const WaveformColors(),
    this.gain          = 1.0,
    this.showReflection = false,
    this.showTimeRuler  = true,
    this.onSeek,
  });

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget> {
  double _viewStart = 0.0;
  double _viewEnd   = 1.0;
  double _scaleStart = 0.0;
  double _scaleEnd   = 1.0;

  void _onTapDown(TapDownDetails details, double width) {
    if (widget.onSeek == null || widget.data == null) return;
    final viewRange  = _viewEnd - _viewStart;
    final tappedFrac = details.localPosition.dx / width;
    final seekPos    = _viewStart + tappedFrac * viewRange;
    widget.onSeek!(seekPos.clamp(0.0, 1.0));
  }

  void _onScaleStart(ScaleStartDetails d) {
    _scaleStart = _viewStart;
    _scaleEnd   = _viewEnd;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount < 2) {
      // Pan
      final viewRange = _viewEnd - _viewStart;
      final delta = -d.focalPointDelta.dx /
          (context.size?.width ?? 1) * viewRange;
      setState(() {
        _viewStart = (_viewStart + delta).clamp(0.0, 1.0 - viewRange);
        _viewEnd   = _viewStart + viewRange;
      });
    } else {
      // Pinch zoom
      final center = (_scaleStart + _scaleEnd) / 2;
      final range  = (_scaleEnd - _scaleStart) / d.scale;
      setState(() {
        _viewStart = (center - range / 2).clamp(0.0, 1.0);
        _viewEnd   = (center + range / 2).clamp(0.0, 1.0);
        if (_viewEnd - _viewStart < 0.01) {
          _viewEnd = _viewStart + 0.01;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTapDown: (d) {
            final w = context.size?.width ?? 1;
            _onTapDown(d, w);
          },
          onScaleStart:  _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: widget.height,
              child: widget.data == null
                  ? _buildLoading()
                  : CustomPaint(
                      painter: WaveformPainter(
                        data:           widget.data!,
                        progress:       widget.progress,
                        viewStart:      _viewStart,
                        viewEnd:        _viewEnd,
                        style:          widget.style,
                        colors:         widget.colors,
                        gain:           widget.gain,
                        showReflection: widget.showReflection,
                      ),
                    ),
            ),
          ),
        ),
        if (widget.showTimeRuler && widget.data != null)
          _TimeRuler(
            data:      widget.data!,
            viewStart: _viewStart,
            viewEnd:   _viewEnd,
            progress:  widget.progress,
            color:     widget.colors.unplayed.withOpacity(0.5),
          ),
      ],
    );
  }

  Widget _buildLoading() {
    return Container(
      color: widget.colors.background,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: widget.colors.unplayed,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RÉGUA DE TEMPO
// ─────────────────────────────────────────────────────────────────────────────

class _TimeRuler extends StatelessWidget {
  final WaveformData data;
  final double viewStart;
  final double viewEnd;
  final double progress;
  final Color color;

  const _TimeRuler({
    required this.data,
    required this.viewStart,
    required this.viewEnd,
    required this.progress,
    required this.color,
  });

  String _formatTime(double seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).floor().toString().padLeft(2, '0');
    final ms = ((seconds % 1) * 10).floor().toString();
    return '$m:$s.$ms';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w         = constraints.maxWidth;
        final viewRange = viewEnd - viewStart;
        final visibleDur = data.duration * viewRange;

        // Intervalo de marcadores adaptativo
        double interval = 1.0;
        if (visibleDur > 120) interval = 30;
        else if (visibleDur > 60) interval = 15;
        else if (visibleDur > 30) interval = 10;
        else if (visibleDur > 10) interval = 5;
        else if (visibleDur > 5)  interval = 2;

        final markers = <Widget>[];
        double t = (viewStart * data.duration / interval).ceil() * interval;

        while (t <= viewEnd * data.duration) {
          final frac = t / data.duration;
          final x    = ((frac - viewStart) / viewRange * w).clamp(0.0, w);
          markers.add(Positioned(
            left: x,
            child: Text(
              _formatTime(t),
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontFamily: 'monospace',
              ),
            ),
          ));
          t += interval;
        }

        return SizedBox(
          height: 16,
          child: Stack(children: markers),
        );
      },
    );
  }
}
