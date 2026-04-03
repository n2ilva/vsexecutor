import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:uuid/uuid.dart';
import '../utils/constants.dart';

/// Represents a single audio track in the mixer
class TrackModel {
  final String id;
  String name;
  String? filePath;
  Color color;

  // Audio source and handle from SoLoud
  AudioSource? audioSource;
  SoundHandle? soundHandle;

  // Mixer settings
  double volume;
  bool isMuted;
  bool isSolo;

  // Trim / cut points (in milliseconds)
  double trimStartMs;
  double trimEndMs;

  // Offset from global timeline start (in milliseconds)
  double offsetMs;

  // Routing (A or B)
  String routing;

  // Track state
  bool isLoaded;
  bool isPlaying;
  double level; // Real-time audio level (0.0 to 1.0)
  Duration totalDuration;

  TrackModel({
    String? id,
    required this.name,
    this.filePath,
    Color? color,
    this.audioSource,
    this.soundHandle,
    this.volume = kDefaultVolume,
    this.isMuted = false,
    this.isSolo = false,
    this.trimStartMs = 0,
    this.trimEndMs = 0,
    this.offsetMs = 0,
    this.routing = 'A',
    this.isLoaded = false,
    this.isPlaying = false,
    this.level = 0.0,
    this.totalDuration = Duration.zero,
  })  : id = id ?? const Uuid().v4(),
        color = color ?? _defaultColors[_colorIndex++ % _defaultColors.length];

  static int _colorIndex = 0;
  static final List<Color> _defaultColors = [
    const Color(0xFF6C5CE7),
    const Color(0xFF00D4FF),
    const Color(0xFFFF6B6B),
    const Color(0xFF00FF87),
    const Color(0xFFFFD700),
    const Color(0xFFFF8C00),
    const Color(0xFFFF69B4),
    const Color(0xFF00CED1),
    const Color(0xFFA29BFE),
    const Color(0xFF55EFC4),
    const Color(0xFFFC5C65),
    const Color(0xFF45AAF2),
    const Color(0xFF26DE81),
    const Color(0xFFFD9644),
    const Color(0xFFA55EEA),
    const Color(0xFF2BCBBA),
    const Color(0xFFEB3B5A),
    const Color(0xFF4B7BEC),
    const Color(0xFF20BF6B),
    const Color(0xFFFA8231),
    const Color(0xFF8854D0),
  ];

  /// Effective volume considering mute state
  double get effectiveVolume => isMuted ? 0.0 : volume;

  /// Track duration in milliseconds
  double get durationMs => totalDuration.inMilliseconds.toDouble();

  /// Trim end (use total duration if not set)
  double get effectiveTrimEnd =>
      trimEndMs > 0 ? trimEndMs : durationMs;

  /// Effective playable duration
  double get playableDurationMs => effectiveTrimEnd - trimStartMs;


  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'filePath': filePath,
      'colorValue': color.toARGB32(),
      'volume': volume,
      'isMuted': isMuted,
      'isSolo': isSolo,
      'trimStartMs': trimStartMs,
      'trimEndMs': trimEndMs,
      'offsetMs': offsetMs,
      'routing': routing,
    };
  }

  factory TrackModel.fromMap(Map<String, dynamic> map) {
    return TrackModel(
      id: map['id'],
      name: map['name'] ?? 'Track',
      filePath: map['filePath'],
      color: map['colorValue'] != null ? Color(map['colorValue']) : null,
      volume: map['volume'] ?? kDefaultVolume,
      isMuted: map['isMuted'] ?? false,
      isSolo: map['isSolo'] ?? false,
      trimStartMs: map['trimStartMs'] ?? 0.0,
      trimEndMs: map['trimEndMs'] ?? 0.0,
      offsetMs: map['offsetMs'] ?? 0.0,
      routing: map['routing'] ?? 'A',
    );
  }

  @override
  String toString() => 'TrackModel($name, vol: $volume)';
}
