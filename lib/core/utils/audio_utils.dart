/// Audio utility functions
class AudioUtils {
  AudioUtils._();

  /// Convert linear volume (0.0 - 1.0) to decibels
  static double linearToDb(double linear) {
    if (linear <= 0.0) return -96.0; // effectively -infinity
    return 20.0 * _log10(linear);
  }

  /// Convert decibels to linear volume (0.0 - 1.0)
  static double dbToLinear(double db) {
    if (db <= -96.0) return 0.0;
    return _pow10(db / 20.0);
  }

  /// Format volume as dB string
  static String formatDb(double linear) {
    final db = linearToDb(linear);
    if (db <= -96.0) return '-∞';
    return '${db.toStringAsFixed(1)} dB';
  }

  /// Format pan as L/C/R string
  static String formatPan(double pan) {
    if (pan < -0.01) {
      return 'L${(pan.abs() * 100).toInt()}';
    } else if (pan > 0.01) {
      return 'R${(pan * 100).toInt()}';
    }
    return 'C';
  }

  /// Format duration as mm:ss.ms
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final millis = (duration.inMilliseconds % 1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(2, '0')}';
  }

  /// Format duration from milliseconds
  static String formatMs(double ms) {
    return formatDuration(Duration(milliseconds: ms.toInt()));
  }

  /// Format position as bars:beats:ticks
  static String formatBarBeatTick(int bar, int beat, int tick) {
    return '${bar.toString().padLeft(3, ' ')}.${beat.toString()}.${tick.toString().padLeft(3, '0')}';
  }

  static double _log10(double x) => _ln(x) / _ln10;
  static const double _ln10 = 2.302585092994046;
  static double _ln(double x) {
    // Dart doesn't have log10, use natural log
    if (x <= 0) return -96.0;
    double result = 0;
    while (x > 2) {
      x /= 2.718281828459045;
      result += 1;
    }
    x -= 1;
    double term = x;
    for (int i = 1; i <= 20; i++) {
      result += (i % 2 == 0 ? -1 : 1) * term / i;
      term *= x;
    }
    return result;
  }

  static double _pow10(double x) {
    // 10^x = e^(x * ln(10))
    return _exp(x * _ln10);
  }

  static double _exp(double x) {
    double result = 1;
    double term = 1;
    for (int i = 1; i <= 30; i++) {
      term *= x / i;
      result += term;
    }
    return result;
  }
}
