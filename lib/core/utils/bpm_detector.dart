import 'package:vs_executor/core/utils/constants.dart';

/// Utility class for BPM detection and extraction from filenames
class BpmDetector {
  BpmDetector._();

  /// Detect if a filename contains "Click" (case-insensitive)
  static bool isClickTrack(String fileName) {
    return fileName.toLowerCase().contains('click');
  }

  /// Extract BPM from filename
  /// Looks for patterns like: "120 BPM", "120bpm", "120", etc.
  /// Returns null if no valid BPM found
  static double? extractBpmFromFilename(String fileName) {
    final cleanName = fileName.toLowerCase();

    // Pattern 1: "120 BPM" or "120bpm" or "120 bpm"
    final bpmPattern = RegExp(r'(\d{2,3})\s*bpm');
    final match1 = bpmPattern.firstMatch(cleanName);
    if (match1 != null) {
      final bpmStr = match1.group(1);
      if (bpmStr != null) {
        final bpm = double.tryParse(bpmStr);
        if (bpm != null && _isValidBpm(bpm)) {
          return bpm;
        }
      }
    }

    // Pattern 2: Numbers at the beginning like "120Hz" or just "120"
    final startPattern = RegExp(r'^(\d{2,3})(?:\s*hz)?');
    final match2 = startPattern.firstMatch(cleanName);
    if (match2 != null) {
      final bpmStr = match2.group(1);
      if (bpmStr != null) {
        final bpm = double.tryParse(bpmStr);
        if (bpm != null && _isValidBpm(bpm)) {
          return bpm;
        }
      }
    }

    // Pattern 3: Numbers in square brackets like "[120]" or "(120)"
    final bracketsPattern = RegExp(r'[\[\(]\s*(\d{2,3})\s*[\]\)]');
    final match3 = bracketsPattern.firstMatch(cleanName);
    if (match3 != null) {
      final bpmStr = match3.group(1);
      if (bpmStr != null) {
        final bpm = double.tryParse(bpmStr);
        if (bpm != null && _isValidBpm(bpm)) {
          return bpm;
        }
      }
    }

    // Pattern 4: Numbers with dash separators like "120-bpm"
    final dashPattern = RegExp(r'(\d{2,3})\s*-\s*bpm');
    final match4 = dashPattern.firstMatch(cleanName);
    if (match4 != null) {
      final bpmStr = match4.group(1);
      if (bpmStr != null) {
        final bpm = double.tryParse(bpmStr);
        if (bpm != null && _isValidBpm(bpm)) {
          return bpm;
        }
      }
    }

    return null;
  }

  /// Validate if BPM is within acceptable range
  static bool _isValidBpm(double bpm) {
    return bpm >= kMinBpm && bpm <= kMaxBpm;
  }

  /// Extract filename without extension
  static String getFileName(String path) {
    final parts = path.split('/');
    final fileName = parts.last;
    final dotIndex = fileName.lastIndexOf('.');
    return dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
  }

  /// Detect BPM from a file path if it's a click track
  static double? detectBpmFromPath(String filePath) {
    final fileName = getFileName(filePath);

    if (!isClickTrack(fileName)) {
      return null;
    }

    return extractBpmFromFilename(fileName);
  }

  /// Format BPM value for display
  static String formatBpm(double bpm) {
    if (bpm == bpm.roundToDouble()) {
      return '${bpm.toInt()} BPM';
    }
    return '${bpm.toStringAsFixed(1)} BPM';
  }

  /// Check if a BPM value is significantly different from current BPM
  static bool isDifferentBpm(double currentBpm, double newBpm, {double tolerance = 2.0}) {
    return (currentBpm - newBpm).abs() > tolerance;
  }
}
