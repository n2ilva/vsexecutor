

/// Represents a time signature (e.g. 4/4, 3/4, 6/8)
class TimeSignature {
  final int beatsPerBar;
  final int beatUnit;

  const TimeSignature({
    this.beatsPerBar = 4,
    this.beatUnit = 4,
  });

  /// Duration of one beat in milliseconds at a given BPM
  double beatDurationMs(double bpm) => 60000.0 / bpm;

  /// Duration of one bar in milliseconds at a given BPM
  double barDurationMs(double bpm) => beatDurationMs(bpm) * beatsPerBar;

  /// Convert a duration in ms to bar:beat:tick
  ({int bar, int beat, int tick}) positionFromMs(double ms, double bpm) {
    final beatMs = beatDurationMs(bpm);
    final totalBeats = ms / beatMs;
    final bar = (totalBeats / beatsPerBar).floor() + 1;
    final beat = (totalBeats % beatsPerBar).floor() + 1;
    final tick = ((totalBeats % 1) * 480).floor(); // 480 PPQ
    return (bar: bar, beat: beat, tick: tick);
  }

  /// Convert bar:beat to duration in ms
  double msFromPosition(int bar, int beat, double bpm) {
    final beatMs = beatDurationMs(bpm);
    return ((bar - 1) * beatsPerBar + (beat - 1)) * beatMs;
  }

  /// Quantize a time in ms to the nearest beat boundary
  double quantizeToNearestBeat(double ms, double bpm) {
    final beatMs = beatDurationMs(bpm);
    return (ms / beatMs).round() * beatMs;
  }

  /// Quantize a time in ms to the nearest bar boundary
  double quantizeToNearestBar(double ms, double bpm) {
    final barMs = barDurationMs(bpm);
    return (ms / barMs).round() * barMs;
  }

  Map<String, dynamic> toMap() {
    return {
      'beatsPerBar': beatsPerBar,
      'beatUnit': beatUnit,
    };
  }

  factory TimeSignature.fromMap(Map<String, dynamic> map) {
    return TimeSignature(
      beatsPerBar: map['beatsPerBar'] ?? 4,
      beatUnit: map['beatUnit'] ?? 4,
    );
  }

  @override
  String toString() => '$beatsPerBar/$beatUnit';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSignature &&
          runtimeType == other.runtimeType &&
          beatsPerBar == other.beatsPerBar &&
          beatUnit == other.beatUnit;

  @override
  int get hashCode => Object.hash(beatsPerBar, beatUnit);
}
