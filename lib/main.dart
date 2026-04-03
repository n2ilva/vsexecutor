import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vs_executor/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Força a orientação horizontal (paisagem)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  runApp(const VSExecutorApp());
}
