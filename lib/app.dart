import 'package:flutter/material.dart';
import 'package:vs_executor/ui/theme/app_theme.dart';
import 'package:vs_executor/ui/theme/app_colors.dart';
import 'package:vs_executor/ui/screens/mixer_screen.dart';
import 'package:vs_executor/ui/screens/audio_devices_screen.dart';
import 'package:vs_executor/core/audio/audio_engine.dart';

class VSExecutorApp extends StatefulWidget {
  const VSExecutorApp({super.key});

  @override
  State<VSExecutorApp> createState() => _VSExecutorAppState();
}

class _VSExecutorAppState extends State<VSExecutorApp> {
  final AudioEngine _engine = AudioEngine();
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  Future<void> _initEngine() async {
    try {
      await _engine.initialize();
      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VS Executor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routes: {
        '/audio-devices': (context) => AudioDevicesScreen(engine: _engine),
      },
      home: _isInitialized
          ? MixerScreen(engine: _engine)
          : _error != null
              ? _ErrorScreen(error: _error!)
              : const _LoadingScreen(),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.primaryGradient.createShader(bounds),
              child: const Text(
                'VS EXECUTOR',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Inicializando engine de áudio...',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;

  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.stopRed,
            ),
            const SizedBox(height: 16),
            const Text(
              'Erro ao inicializar áudio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                error,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
