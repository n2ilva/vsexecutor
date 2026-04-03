/// Maximum number of tracks supported
const int kMaxTracks = 21;

/// Default BPM
const double kDefaultBpm = 120.0;

/// Min/Max BPM
const double kMinBpm = 20.0;
const double kMaxBpm = 300.0;

/// Default time signature
const int kDefaultBeatsPerBar = 4;
const int kDefaultBeatUnit = 4;

/// Volume range
const double kMinVolume = 0.0;
const double kMaxVolume = 1.0;
const double kDefaultVolume = 0.8;

/// Audio engine settings
const int kSampleRate = 44100;
const int kBufferSize = 2048;

/// Max active voices (tracks + metronome + headroom)
const int kMaxActiveVoices = 32;

/// Available time signatures
const List<Map<String, int>> kTimeSignatures = [
  {'beats': 2, 'unit': 4},
  {'beats': 3, 'unit': 4},
  {'beats': 4, 'unit': 4},
  {'beats': 5, 'unit': 4},
  {'beats': 6, 'unit': 4},
  {'beats': 7, 'unit': 4},
  {'beats': 6, 'unit': 8},
  {'beats': 7, 'unit': 8},
  {'beats': 9, 'unit': 8},
  {'beats': 12, 'unit': 8},
];
