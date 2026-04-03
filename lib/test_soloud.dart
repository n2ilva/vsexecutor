import 'package:flutter_soloud/flutter_soloud.dart';
void test() {
  final s = SoLoud.instance;
  s.getWave();
  s.getFft();
  s.get256WaveData();
  s.getAudioTexture2D();
  s.getFftData();
}
