import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Represents a session marker / section (e.g., Intro, Verse, Chorus)
class SessionMarker {
  final String id;
  String name;
  Color color;

  /// Position in milliseconds from the start
  double positionMs;

  /// Optional end position for looping a section
  double? endPositionMs;

  SessionMarker({
    String? id,
    required this.name,
    required this.color,
    required this.positionMs,
    this.endPositionMs,
  }) : id = id ?? const Uuid().v4();

  /// Duration of this section (if end is defined)
  double? get durationMs =>
      endPositionMs != null ? endPositionMs! - positionMs : null;

  SessionMarker copyWith({
    String? name,
    Color? color,
    double? positionMs,
    double? endPositionMs,
  }) {
    return SessionMarker(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      positionMs: positionMs ?? this.positionMs,
      endPositionMs: endPositionMs ?? this.endPositionMs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'colorValue': color.toARGB32(),
      'positionMs': positionMs,
      'endPositionMs': endPositionMs,
    };
  }

  factory SessionMarker.fromMap(Map<String, dynamic> map) {
    return SessionMarker(
      id: map['id'],
      name: map['name'],
      color: map['colorValue'] != null ? Color(map['colorValue']) : const Color(0xFF6C5CE7),
      positionMs: map['positionMs'] ?? 0.0,
      endPositionMs: map['endPositionMs'],
    );
  }

  @override
  String toString() => 'SessionMarker($name @ ${positionMs}ms)';
}
