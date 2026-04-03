import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vs_executor/ui/theme/app_colors.dart';
import 'package:vs_executor/core/audio/audio_engine.dart';
import 'package:vs_executor/core/utils/constants.dart';

/// BPM control widget with tap tempo
class BpmControl extends StatefulWidget {
  final AudioEngine engine;

  const BpmControl({super.key, required this.engine});

  @override
  State<BpmControl> createState() => _BpmControlState();
}

class _BpmControlState extends State<BpmControl> {
  final _bpmController = TextEditingController();
  final _focusNode = FocusNode();
  final List<DateTime> _tapTimes = [];

  @override
  void initState() {
    super.initState();
    _bpmController.text = widget.engine.bpm.toStringAsFixed(1);
    widget.engine.addListener(_onEngineChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onEngineChanged() {
    if (mounted && !_focusNode.hasFocus) {
      final newBpm = widget.engine.bpm.toStringAsFixed(1);
      if (_bpmController.text != newBpm) {
        setState(() {
          _bpmController.text = newBpm;
        });
      }
    }
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // Quando perde o foco, tentamos aplicar o que foi formatado se o user não clicou Enter
      final bpm = double.tryParse(_bpmController.text);
      if (bpm != null) {
        widget.engine.setBpm(bpm);
      }

      // Re-formata para o padrão correto do engine (ex: 120 -> 120.0)
      setState(() {
        _bpmController.text = widget.engine.bpm.toStringAsFixed(1);
      });
    }
  }

  @override
  void dispose() {
    widget.engine.removeListener(_onEngineChanged);
    _focusNode.removeListener(_onFocusChanged);
    _bpmController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTapTempo() {
    final now = DateTime.now();
    _tapTimes.add(now);

    // Keep only last 4 taps
    if (_tapTimes.length > 4) {
      _tapTimes.removeAt(0);
    }

    if (_tapTimes.length >= 2) {
      double totalMs = 0;
      for (int i = 1; i < _tapTimes.length; i++) {
        totalMs += _tapTimes[i].difference(_tapTimes[i - 1]).inMilliseconds;
      }
      final avgMs = totalMs / (_tapTimes.length - 1);
      final bpm = (60000 / avgMs).clamp(kMinBpm, kMaxBpm);
      widget.engine.setBpm(bpm);
      _bpmController.text = bpm.toInt().toString();
    }

    // Reset if too much time between taps
    if (_tapTimes.length >= 2) {
      final lastInterval = _tapTimes.last
          .difference(_tapTimes[_tapTimes.length - 2])
          .inMilliseconds;
      if (lastInterval > 3000) {
        _tapTimes.clear();
        _tapTimes.add(now);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sincroniza o texto caso tenha mudado externamente (apenas se nao estiver focado)
    if (!_focusNode.hasFocus) {
      final engineBpmText = widget.engine.bpm.toStringAsFixed(1);
      if (_bpmController.text != engineBpmText) {
        _bpmController.text = engineBpmText;
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // BPM label and value
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.speed_rounded,
                size: 14,
                color: AppColors.accent,
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 55,
                child: TextField(
                  controller: _bpmController,
                  focusNode: _focusNode,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'monospace',
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  onSubmitted: (val) {
                    final bpm = double.tryParse(val);
                    if (bpm != null) {
                      widget.engine.setBpm(bpm);
                      _focusNode.unfocus();
                    }
                  },
                ),
              ),
              const Text(
                'BPM',
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),

        // -/+ buttons
        _BpmStepButton(
          icon: Icons.remove,
          onTap: () {
            widget.engine.setBpm(widget.engine.bpm - 1);
            _bpmController.text = widget.engine.bpm.toStringAsFixed(1);
          },
        ),
        const SizedBox(width: 2),
        _BpmStepButton(
          icon: Icons.add,
          onTap: () {
            widget.engine.setBpm(widget.engine.bpm + 1);
            _bpmController.text = widget.engine.bpm.toStringAsFixed(1);
          },
        ),
        const SizedBox(width: 6),

        // Tap tempo button
        GestureDetector(
          onTap: _onTapTempo,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceLighter,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'TAP',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BpmStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _BpmStepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.surfaceLighter,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 14, color: AppColors.textSecondary),
      ),
    );
  }
}
