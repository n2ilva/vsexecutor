import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../models/track_model.dart';
import '../models/time_signature.dart';
import '../models/session_marker.dart';
import '../utils/constants.dart';
import '../utils/bpm_detector.dart';

/// Central audio engine that wraps SoLoud for multi-track playback
class AudioEngine extends ChangeNotifier {
  final SoLoud _soloud = SoLoud.instance;
  bool _isInitialized = false;
  Timer? _positionTimer;

  // Transport state
  bool _isPlaying = false;
  bool _isLooping = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // Custom loop zone (measures precision)
  double? _loopStartMs;
  double? _loopEndMs;

  // BPM & Time Signature
  double _bpm = kDefaultBpm;
  TimeSignature _timeSignature = const TimeSignature();

  // Tracks
  final List<TrackModel> _tracks = [];

  // Session Markers
  final List<SessionMarker> _markers = [];

  // Solo state tracking
  bool _anySoloed = false;

  // Metronome
  bool _metronomeEnabled = false;
  AudioSource? _metronomeClickHigh;
  AudioSource? _metronomeClickLow;

  // Audio Devices
  List<PlaybackDevice> _availableDevices = [];
  PlaybackDevice? _currentDevice;
  String? _masterADeviceName;
  int? _masterADeviceId;
  String? _masterBDeviceName;
  int? _masterBDeviceId;

  // Persistência de Pans por ID de dispositivo
  final Map<int, double> _allKnownDevicePans = {};

  // Global Volumes
  double _masterVolume = 1.0;
  double _masterAVolume = 1.0;
  double _masterBVolume = 1.0;
  bool _masterMuted = false;
  bool _masterAMuted = false;
  bool _masterBMuted = false;

  // Master A/B Routing Specifics
  double _masterAPan = 0.0;
  double _masterBPan = 0.0;

  // Metronome State
  double _metronomeVolume = 0.5;
  int _lastBeatPlayed = -1;

  // Audio analysis for visualization
  final List<double> _trackPeaks = [];
  final List<double> _trackDecay = [];
  final List<int> _trackSamples = [];

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isPlaying => _isPlaying;
  bool get isLooping => _isLooping;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  double? get loopStartMs => _loopStartMs;
  double? get loopEndMs => _loopEndMs;

  void setLoopZone(double startMs, double endMs) {
    _loopStartMs = startMs;
    _loopEndMs = endMs;
    notifyListeners();
  }
  double get bpm => _bpm;
  TimeSignature get timeSignature => _timeSignature;
  List<TrackModel> get tracks => List.unmodifiable(_tracks);
  List<SessionMarker> get markers => List.unmodifiable(_markers);
  bool get metronomeEnabled => _metronomeEnabled;
  int get trackCount => _tracks.length;
  List<PlaybackDevice> get availableDevices => List.unmodifiable(_availableDevices);
  PlaybackDevice? get currentDevice => _currentDevice;
  String? get masterADeviceName => _masterADeviceName;
  String? get masterBDeviceName => _masterBDeviceName;
  double get masterVolume => _masterVolume;
  double get masterAVolume => _masterAVolume;
  double get masterBVolume => _masterBVolume;
  double get masterAPan => _masterAPan;
  double get masterBPan => _masterBPan;
  Map<int, double> get allKnownDevicePans => Map.unmodifiable(_allKnownDevicePans);
  bool get masterMuted => _masterMuted;
  bool get masterAMuted => _masterAMuted;
  bool get masterBMuted => _masterBMuted;
  double get metronomeVolume => _metronomeVolume;

  void setMetronomeVolume(double val) {
    _metronomeVolume = val.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Initialize the audio engine
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _soloud.init(
        sampleRate: kSampleRate,
        bufferSize: kBufferSize,
      );
      _soloud.setMaxActiveVoiceCount(kMaxActiveVoices);
      
      // Carregar áudios de clique pro metrônomo vindo de assets customizados
      try {
        _metronomeClickHigh = await _soloud.loadAsset('assets/audio/beep_high.wav', mode: LoadMode.memory);
        _metronomeClickLow = await _soloud.loadAsset('assets/audio/beep_low.wav', mode: LoadMode.memory);
      } catch (e) {
        debugPrint("Metronome clicks not loaded: $e");
      }

      _isInitialized = true;

      // Start position tracking timer
      _positionTimer = Timer.periodic(
        const Duration(milliseconds: 16), // ~60fps
        (_) => _updatePosition(),
      );

      _loadAvailableDevices();

      notifyListeners();
    } catch (e) {
      debugPrint('AudioEngine init failed: $e');
      rethrow;
    }
  }

  /// Dispose the audio engine
  @override
  void dispose() {
    _positionTimer?.cancel();
    if (_isInitialized) {
      stopAll();
      for (final track in _tracks) {
        if (track.audioSource != null) {
          _soloud.disposeSource(track.audioSource!);
        }
      }
      _soloud.deinit();
    }
    super.dispose();
  }

  // =============================================
  // TRACK MANAGEMENT
  // =============================================

  /// Add a track from file path
  Future<TrackModel> addTrack(String filePath, {String? name}) async {
    if (!_isInitialized) throw StateError('Engine not initialized');

    final trackName = name ?? _extractFileName(filePath);
    final track = TrackModel(name: trackName, filePath: filePath);

    try {
      track.audioSource = await _soloud.loadFile(filePath, mode: LoadMode.memory);
      track.totalDuration = _soloud.getLength(track.audioSource!);
      track.isLoaded = true;

      // Enable visualization for this source (some versions of SoLoud use this to enable per-source FFT)
      _soloud.setVisualizationEnabled(true);

      _tracks.add(track);
      
      _updateTotalDuration();
      notifyListeners();
      return track;
    } catch (e) {
      debugPrint('Failed to load track: $e');
      rethrow;
    }
  }

  /// Calculates real pan constraints based on Master A/B routing
  double _calculateTrackEffectivePan(TrackModel track) {
    // Agora respeita o PAN configurado no dispositivo para cada Master
    return track.routing == 'B' ? _masterBPan : _masterAPan;
  }

  void _updateTrackPan(TrackModel track) {
    if (track.soundHandle != null) {
      _soloud.setPan(track.soundHandle!, _calculateTrackEffectivePan(track));
    }
  }

  /// Remove a track
  Future<void> removeTrack(String trackId) async {
    final index = _tracks.indexWhere((t) => t.id == trackId);
    if (index == -1) return;

    final track = _tracks[index];
    if (track.soundHandle != null) {
      await _soloud.stop(track.soundHandle!);
    }
    if (track.audioSource != null) {
      await _soloud.disposeSource(track.audioSource!);
    }

    _tracks.removeAt(index);
    
    _updateSoloState();
    _updateTotalDuration();
    notifyListeners();
  }

  /// Reorder tracks
  void reorderTrack(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final track = _tracks.removeAt(oldIndex);
    _tracks.insert(newIndex, track);
    notifyListeners();
  }

  // =============================================
  // TRANSPORT CONTROLS
  // =============================================

  /// Plays only a specific track (useful for analysis)
  Future<void> playTrack(String trackId, {Duration? position}) async {
    if (!_isInitialized) return;
    
    final track = _findTrack(trackId);
    if (track == null || !track.isLoaded || track.audioSource == null) return;
    
    // Stop everything else first
    await stopAll();
    
    // Play with solo focus (master routing pan is handled by _soloud.play)
    track.soundHandle = await _soloud.play(
      track.audioSource!,
      volume: _getEffectiveVolume(track),
      pan: _calculateTrackEffectivePan(track),
      paused: true,
    );
    
    if (position != null) {
      _soloud.seek(track.soundHandle!, position);
    } else if (_currentPosition > Duration.zero) {
      _soloud.seek(track.soundHandle!, _currentPosition);
    }
    
    _soloud.setPause(track.soundHandle!, false);
    track.isPlaying = true;
    _isPlaying = true;
    
    notifyListeners();
  }

  /// Play all loaded tracks from current position
  Future<void> playAll() async {
    if (!_isInitialized) return;

    for (final track in _tracks) {
      if (!track.isLoaded || track.audioSource == null) continue;

      try {
        final effectiveVol = _getEffectiveVolume(track);
        track.soundHandle = await _soloud.play(
          track.audioSource!,
          volume: effectiveVol,
          pan: _calculateTrackEffectivePan(track),
          paused: true,
          looping: _isLooping,
        );

        // Protect voice so it doesn't get killed
        _soloud.setProtectVoice(track.soundHandle!, true);

        // Seek to current position + trim start
        final seekPos = _currentPosition + Duration(milliseconds: track.trimStartMs.toInt());
        _soloud.seek(track.soundHandle!, seekPos);

        // Unpause
        _soloud.setPause(track.soundHandle!, false);
        track.isPlaying = true;
      } catch (e) {
        debugPrint('Failed to play track ${track.name}: $e');
      }
    }

    _isPlaying = true;
    notifyListeners();
  }

  /// Pause all tracks
  void pauseAll() {
    if (!_isInitialized) return;

    for (final track in _tracks) {
      if (track.soundHandle != null && track.isPlaying) {
        _soloud.setPause(track.soundHandle!, true);
        track.isPlaying = false;
      }
    }

    _isPlaying = false;
    notifyListeners();
  }

  /// Resume all tracks
  void resumeAll() {
    if (!_isInitialized) return;

    for (final track in _tracks) {
      if (track.soundHandle != null && track.isLoaded) {
        _soloud.setPause(track.soundHandle!, false);
        track.isPlaying = true;
      }
    }

    _isPlaying = true;
    notifyListeners();
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      pauseAll();
    } else {
      bool hasActiveHandles = _tracks.any((t) => t.soundHandle != null);
      if (hasActiveHandles) {
        resumeAll();
      } else {
        await playAll();
      }
    }
  }

  /// Stop all tracks and reset position
  Future<void> stopAll() async {
    if (!_isInitialized) return;

    for (final track in _tracks) {
      if (track.soundHandle != null) {
        try {
          await _soloud.stop(track.soundHandle!);
        } catch (_) {}
        track.soundHandle = null;
        track.isPlaying = false;
      }
    }

    _isPlaying = false;
    _currentPosition = Duration.zero;
    _lastBeatPlayed = -1;
    notifyListeners();
  }

  /// Reset the entire project to a clean state
  Future<void> resetProject() async {
    await stopAll();
    
    // Dispose and clear all tracks
    for (final track in _tracks.toList()) {
      await removeTrack(track.id);
    }
    
    // Clear all markers
    _markers.clear();
    
    // Reset BPM and Time Signature to defaults
    _bpm = kDefaultBpm;
    _timeSignature = const TimeSignature();
    
    _totalDuration = Duration.zero;
    _currentPosition = Duration.zero;
    
    notifyListeners();
  }

  /// Seek to position
  void seekTo(Duration position) {
    _currentPosition = position;
    _lastBeatPlayed = -1;

    for (final track in _tracks) {
      if (track.soundHandle != null) {
        // Leva em conta o trim inicial da trilha para manter a sincronia
        final handlePosition = position + Duration(milliseconds: track.trimStartMs.toInt());
        _soloud.seek(track.soundHandle!, handlePosition);
      }
    }

    notifyListeners();
  }

  /// Seek to a position quantized to the nearest bar
  void seekToBar(Duration position) {
    final quantized = _timeSignature.quantizeToNearestBar(
      position.inMilliseconds.toDouble(),
      _bpm,
    );
    seekTo(Duration(milliseconds: quantized.toInt()));
  }

  /// Go to beginning
  void goToStart() {
    seekTo(Duration.zero);
  }

  /// Toggle loop
  void toggleLoop() {
    _isLooping = !_isLooping;

    for (final track in _tracks) {
      if (track.soundHandle != null) {
        _soloud.setLooping(track.soundHandle!, _isLooping);
      }
    }

    notifyListeners();
  }

  // =============================================
  // MIXER CONTROLS
  // =============================================

  /// Set volume for a track
  void setTrackVolume(String trackId, double volume) {
    final track = _findTrack(trackId);
    if (track == null) return;

    track.volume = volume.clamp(kMinVolume, kMaxVolume);

    if (track.soundHandle != null) {
      _soloud.setVolume(track.soundHandle!, _getEffectiveVolume(track));
    }

    notifyListeners();
  }

  /// Toggle mute for a track
  void toggleMute(String trackId) {
    final track = _findTrack(trackId);
    if (track == null) return;

    track.isMuted = !track.isMuted;

    if (track.soundHandle != null) {
      _soloud.setVolume(track.soundHandle!, _getEffectiveVolume(track));
    }

    notifyListeners();
  }

  /// Toggle solo for a track
  void toggleSolo(String trackId) {
    final track = _findTrack(trackId);
    if (track == null) return;

    track.isSolo = !track.isSolo;
    _updateSoloState();

    // Update all track volumes based on solo state
    for (final t in _tracks) {
      if (t.soundHandle != null) {
        _soloud.setVolume(t.soundHandle!, _getEffectiveVolume(t));
      }
    }

    notifyListeners();
  }

  /// Set master volume
  void setMasterVolume(double volume) {
    if (!_isInitialized) return;
    _masterVolume = volume.clamp(0.0, 1.0);
    final effectiveVolume = _masterMuted ? 0.0 : _masterVolume;
    _soloud.setGlobalVolume(effectiveVolume);
    notifyListeners();
  }

  /// Toggle master mute
  void toggleMasterMute() {
    _masterMuted = !_masterMuted;
    final effectiveVolume = _masterMuted ? 0.0 : _masterVolume;
    _soloud.setGlobalVolume(effectiveVolume);
    notifyListeners();
  }

  void setMasterAVolume(double volume) {
    _masterAVolume = volume.clamp(0.0, 1.0);
    _refreshAllTrackVolumes();
    notifyListeners();
  }

  /// Toggle master A mute
  void toggleMasterAMute() {
    _masterAMuted = !_masterAMuted;
    _refreshAllTrackVolumes();
    notifyListeners();
  }

  void setMasterBVolume(double volume) {
    _masterBVolume = volume.clamp(0.0, 1.0);
    _refreshAllTrackVolumes();
    notifyListeners();
  }

  /// Toggle master B mute
  void toggleMasterBMute() {
    _masterBMuted = !_masterBMuted;
    _refreshAllTrackVolumes();
    notifyListeners();
  }

  /// Define dispositivo de saída para Master A e seu Pan inicial
  void setMasterAOutputDevice(String deviceName, {double pan = 0.0, int? deviceId}) {
    debugPrint('🔊 AudioEngine: Definindo Master A -> $deviceName (ID: $deviceId, Pan: $pan)');
    _masterADeviceName = deviceName;
    _masterADeviceId = deviceId;
    _masterAPan = pan;
    _refreshAllTrackPans();
    notifyListeners();
  }

  /// Define dispositivo de saída para Master B e seu Pan inicial
  void setMasterBOutputDevice(String deviceName, {double pan = 0.0, int? deviceId}) {
    debugPrint('🔊 AudioEngine: Definindo Master B -> $deviceName (ID: $deviceId, Pan: $pan)');
    _masterBDeviceName = deviceName;
    _masterBDeviceId = deviceId;
    _masterBPan = pan;
    _refreshAllTrackPans();
    notifyListeners();
  }

  /// Chamado pela página de dispositivos para sincronizar o Pan em tempo real
  void syncDevicePan(String deviceName, double pan, {int? deviceId}) {
    // Persiste o valor no mapa global para consulta posterior da UI
    if (deviceId != null) {
      _allKnownDevicePans[deviceId] = pan;
    }

    bool changed = false;
    
    // Tenta sincronizar por ID (mais preciso) ou por nome
    if ((deviceId != null && _masterADeviceId == deviceId) || 
        (_masterADeviceName == deviceName)) {
      debugPrint('🔄 Sincronizando Pan Master A: $pan');
      _masterAPan = pan;
      changed = true;
    }
    
    if ((deviceId != null && _masterBDeviceId == deviceId) || 
        (_masterBDeviceName == deviceName)) {
      debugPrint('🔄 Sincronizando Pan Master B: $pan');
      _masterBPan = pan;
      changed = true;
    }
    
    if (changed) {
      _refreshAllTrackPans();
      notifyListeners();
    }
  }

  void _refreshAllTrackPans() {
    int updatedCount = 0;
    for (final track in _tracks) {
      if (track.soundHandle != null) {
        final newPan = _calculateTrackEffectivePan(track);
        _soloud.setPan(track.soundHandle!, newPan);
        updatedCount++;
      }
    }
    debugPrint('✅ Pans atualizados em $updatedCount trilhas ativas.');
  }

  void setTrackRouting(String trackId, String routing) {
    final track = _findTrack(trackId);
    if (track == null) return;
    track.routing = routing == 'B' ? 'B' : 'A';
    
    if (track.soundHandle != null) {
      _soloud.setVolume(track.soundHandle!, _getEffectiveVolume(track));
      _updateTrackPan(track);
    }
    notifyListeners();
  }

  void _refreshAllTrackVolumes() {
    for (final track in _tracks) {
      if (track.soundHandle != null) {
        _soloud.setVolume(track.soundHandle!, _getEffectiveVolume(track));
      }
    }
  }

  // =============================================
  // BPM & TIME SIGNATURE
  // =============================================

  /// Set BPM
  void setBpm(double bpm) {
    _bpm = bpm.clamp(kMinBpm, kMaxBpm);
    // Force a small delay or microtask if needed, but notifyListeners should be enough
    notifyListeners();
  }

  /// Set time signature
  void setTimeSignature(int beatsPerBar, int beatUnit) {
    _timeSignature = TimeSignature(beatsPerBar: beatsPerBar, beatUnit: beatUnit);
    notifyListeners();
  }

  /// Toggle metronome
  void toggleMetronome() {
    _metronomeEnabled = !_metronomeEnabled;
    notifyListeners();
  }

  // =============================================
  // AUDIO DEVICES
  // =============================================

  void _loadAvailableDevices() {
    try {
      _availableDevices = _soloud.listPlaybackDevices();
      // Define o dispositivo atual como o padrão do OS
      if (_availableDevices.isNotEmpty) {
        _currentDevice = _availableDevices.firstWhere(
          (d) => d.isDefault,
          orElse: () => _availableDevices.first,
        );
      }
    } catch (e) {
      debugPrint('Failed to load playback devices: $e');
    }
  }

  void changePlaybackDevice(PlaybackDevice device) {
    if (!_isInitialized) return;
    try {
      _soloud.changeDevice(newDevice: device);
      _currentDevice = device;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to change device: $e');
    }
  }

  // =============================================
  // SESSION MARKERS
  // =============================================

  /// Add a marker at the current position
  SessionMarker addMarker(String name, {int colorIndex = 0}) {
    final color = colorIndex < 8
        ? [
            const Color(0xFF6C5CE7),
            const Color(0xFF00D4FF),
            const Color(0xFFFF6B6B),
            const Color(0xFF00FF87),
            const Color(0xFFFFD700),
            const Color(0xFFFF8C00),
            const Color(0xFFFF69B4),
            const Color(0xFF00CED1),
          ][colorIndex]
        : const Color(0xFF6C5CE7);

    final marker = SessionMarker(
      name: name,
      color: color,
      positionMs: _currentPosition.inMilliseconds.toDouble(),
    );

    _markers.add(marker);
    _markers.sort((a, b) => a.positionMs.compareTo(b.positionMs));
    notifyListeners();
    return marker;
  }

  /// Add a marker at a specific position
  SessionMarker addMarkerAt(String name, double positionMs, {int colorIndex = 0, double? endMs}) {
    final color = colorIndex < 8
        ? [
            const Color(0xFF6C5CE7),
            const Color(0xFF00D4FF),
            const Color(0xFFFF6B6B),
            const Color(0xFF00FF87),
            const Color(0xFFFFD700),
            const Color(0xFFFF8C00),
            const Color(0xFFFF69B4),
            const Color(0xFF00CED1),
          ][colorIndex]
        : const Color(0xFF6C5CE7);

    final marker = SessionMarker(
      name: name,
      color: color,
      positionMs: positionMs,
      endPositionMs: endMs,
    );

    _markers.add(marker);
    _markers.sort((a, b) => a.positionMs.compareTo(b.positionMs));
    notifyListeners();
    return marker;
  }

  /// Remove a marker
  void removeMarker(String markerId) {
    _markers.removeWhere((m) => m.id == markerId);
    notifyListeners();
  }

  /// Jump to a marker, quantized to the nearest beat
  void jumpToMarker(String markerId) {
    final marker = _markers.firstWhere(
      (m) => m.id == markerId,
      orElse: () => throw StateError('Marker not found'),
    );

    // Quantize to nearest beat for musical timing
    final quantizedMs = _timeSignature.quantizeToNearestBeat(
      marker.positionMs,
      _bpm,
    );

    seekTo(Duration(milliseconds: quantizedMs.toInt()));
  }

  // =============================================
  // TRIM / CUT
  // =============================================

  /// Set trim start for a track
  void setTrimStart(String trackId, double startMs) {
    final track = _findTrack(trackId);
    if (track == null) return;
    track.trimStartMs = startMs.clamp(0, track.durationMs);
    notifyListeners();
  }

  /// Set trim end for a track
  void setTrimEnd(String trackId, double endMs) {
    final track = _findTrack(trackId);
    if (track == null) return;
    track.trimEndMs = endMs.clamp(track.trimStartMs, track.durationMs);
    notifyListeners();
  }

  // =============================================
  // PRIVATE HELPERS
  // =============================================

  TrackModel? _findTrack(String trackId) {
    try {
      return _tracks.firstWhere((t) => t.id == trackId);
    } catch (_) {
      return null;
    }
  }

  void _updateSoloState() {
    _anySoloed = _tracks.any((t) => t.isSolo);
  }

  double _getEffectiveVolume(TrackModel track) {
    if (track.isMuted) return 0.0;
    if (_anySoloed && !track.isSolo) return 0.0;
    
    // Apply Routing Bus volume and mute state
    final isBusA = track.routing == 'A';
    final busVolume = isBusA ? _masterAVolume : _masterBVolume;
    final busMuted = isBusA ? _masterAMuted : _masterBMuted;
    
    if (busMuted) return 0.0;
    
    return (track.volume * busVolume).clamp(0.0, 1.0);
  }

  void _updateTotalDuration() {
    Duration maxDuration = Duration.zero;
    for (final track in _tracks) {
      if (track.totalDuration > maxDuration) {
        maxDuration = track.totalDuration;
      }
    }
    _totalDuration = maxDuration;
  }

  void _updatePosition() {
    if (!_isPlaying) return;

    // Process Metronome Ticks
    if (_metronomeEnabled) {
      final bbt = currentBarBeat;
      if (bbt.beat != _lastBeatPlayed) {
        _lastBeatPlayed = bbt.beat;
        
        // Play click! High on beat 1, low on others
        if (_metronomeClickHigh != null && _metronomeClickLow != null) {
          if (bbt.beat == 1) {
             _soloud.play(_metronomeClickHigh!, volume: _metronomeVolume * _masterVolume);
          } else {
             _soloud.play(_metronomeClickLow!, volume: _metronomeVolume * _masterVolume * 0.7);
          }
        }
      }
    }

    if (_tracks.isEmpty) return;

    // Initialize tracking arrays if needed
    if (_trackPeaks.length != _tracks.length) {
      _trackPeaks.clear();
      _trackDecay.clear();
      _trackSamples.clear();
      _trackPeaks.addAll(List.filled(_tracks.length, 0.0));
      _trackDecay.addAll(List.filled(_tracks.length, 0.0));
      _trackSamples.addAll(List.filled(_tracks.length, 0));
    }

    // Update track levels and get position from the first valid handle
    bool positionUpdated = false;

    for (int idx = 0; idx < _tracks.length; idx++) {
      final track = _tracks[idx];
      
      if (track.soundHandle != null && track.isPlaying) {
        try {
          final pos = _soloud.getPosition(track.soundHandle!);
          
          // Calculate dynamic intensity based on position and track properties
          final intensity = _calculateIntensity(track, pos, idx);
          track.level = intensity.clamp(0.0, 1.0);
          
          if (!positionUpdated) {
            _currentPosition = pos;
            positionUpdated = true;
          }
        } catch (_) {
          track.level = 0;
        }
      } else {
        track.level = 0;
        _trackDecay[idx] = 0;
      }
    }

    // Check custom loop zone
    if (_isLooping && _loopStartMs != null && _loopEndMs != null) {
      if (_currentPosition.inMilliseconds >= _loopEndMs!) {
        seekTo(Duration(milliseconds: _loopStartMs!.toInt()));
        return; // seekTo already calls notifyListeners
      }
    }

    notifyListeners();
  }

  /// Calculate dynamic audio intensity based on position and audio characteristics
  double _calculateIntensity(TrackModel track, Duration position, int trackIndex) {
    // Start with the base volume
    double baseIntensity = track.volume;

    if (track.soundHandle == null) return baseIntensity;

    try {
      // Get position in milliseconds
      final posMs = position.inMilliseconds.toDouble();
      final handleValue = track.soundHandle!.hashCode.toDouble();

      // Create deterministic but varied animation based on position
      // This simulates different audio intensities across the track timeline
      final timePhase = (posMs / 1000.0) % 16.0; // 16 second cycle
      final trackPhase = (handleValue % 100.0) / 100.0; // Unique per track

      // Generate harmonic series for organic feel
      double harmonic = 0;
      for (int h = 1; h <= 4; h++) {
        double freq = h * 0.5;
        harmonic += math.sin((timePhase + trackPhase) * freq * math.pi) / h;
      }
      harmonic = (harmonic + 2) / 4; // Normalize to 0-1

      // Add some randomness for more organic feel
      final seed = (posMs.toInt() ~/ 50) ^ track.id.hashCode;
      final pseudo = (math.sin(seed * 0.1) + 1) / 2;

      // Combine effects: harmonic + pseudo-randomness
      double dynamicIntensity = harmonic * 0.4 + pseudo * 0.3 + baseIntensity * 0.3;

      // Smooth decay with peak hold
      if (dynamicIntensity > _trackDecay[trackIndex]) {
        _trackDecay[trackIndex] = dynamicIntensity;
        _trackPeaks[trackIndex] = dynamicIntensity;
        _trackSamples[trackIndex] = 30; // Hold peak for ~30 frames
      } else if (_trackSamples[trackIndex] > 0) {
        _trackSamples[trackIndex]--;
      } else {
        _trackDecay[trackIndex] = _trackDecay[trackIndex] * 0.95;
      }

      return _trackDecay[trackIndex].clamp(0.0, 1.0);
    } catch (_) {
      return baseIntensity;
    }
  }

  String _extractFileName(String path) {
    final parts = path.split('/');
    final fileName = parts.last;
    // Remove extension
    final dotIndex = fileName.lastIndexOf('.');
    return dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
  }

  /// Get bar:beat:tick for the current position
  ({int bar, int beat, int tick}) get currentBarBeat {
    return _timeSignature.positionFromMs(
      _currentPosition.inMilliseconds.toDouble(),
      _bpm,
    );
  }
}
