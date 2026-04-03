import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vs_executor/core/audio/audio_engine.dart';

class ProjectService {
  static const _recentFilesName = 'recent_projects.json';

  static Future<List<Map<String, String>>> getRecentProjects() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$_recentFilesName');
      if (!file.existsSync()) return [];
      final content = await file.readAsString();
      final list = jsonDecode(content) as List;
      return list.map((e) => Map<String, String>.from(e)).toList();
    } catch (e) {
      debugPrint('Error getting recent projects: $e');
      return [];
    }
  }

  static Future<void> addRecentProject(String path) async {
    try {
      final list = await getRecentProjects();
      final name = path.split(Platform.pathSeparator).last;
      
      list.removeWhere((item) => item['path'] == path);
      list.insert(0, {'name': name, 'path': path}); // Add to top
      if (list.length > 10) list.removeLast(); // Keep up to 10
      
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$_recentFilesName');
      await file.writeAsString(jsonEncode(list));
    } catch (e) {
      debugPrint('Error adding recent project: $e');
    }
  }

  /// Save the current engine state to a local .vsexec file
  static Future<bool> saveProject(AudioEngine engine, {String? fileName}) async {
    try {
      String? outputFile;
      if (Platform.isAndroid || Platform.isIOS) {
        final dir = await getApplicationDocumentsDirectory();
        outputFile = '${dir.path}/${fileName ?? "projeto_${DateTime.now().millisecondsSinceEpoch}.vsexec"}';
      } else {
        outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Salvar Projeto',
          fileName: fileName ?? 'meu_projeto.vsexec',
          type: FileType.custom,
          allowedExtensions: ['vsexec', 'json'],
        );
      }

      if (outputFile == null) return false;

      final projectData = {
        'bpm': engine.bpm,
        'timeSignature': engine.timeSignature.toMap(),
        'tracks': engine.tracks.map((t) => t.toMap()).toList(),
        'markers': engine.markers.map((m) => m.toMap()).toList(),
      };

      final jsonString = jsonEncode(projectData);
      final file = File(outputFile);
      await file.writeAsString(jsonString);

      await addRecentProject(outputFile);

      return true;
    } catch (e) {
      debugPrint('Error saving project: $e');
      return false;
    }
  }

  /// Load a project from a .vsexec file and update the engine
  static Future<bool> loadProject(AudioEngine engine) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Abrir Projeto',
        type: FileType.custom,
        allowedExtensions: ['vsexec', 'json'],
      );

      if (result == null || result.files.isEmpty) return false;
      final path = result.files.single.path;
      if (path == null) return false;

      return await loadProjectFromPath(engine, path);
    } catch (e) {
      debugPrint('Error loading project: $e');
      return false;
    }
  }

  /// Load a project from a specific path
  static Future<bool> loadProjectFromPath(AudioEngine engine, String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return false;
      final jsonString = await file.readAsString();
      final projectData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Clear current state
      await engine.stopAll();
      for (final track in engine.tracks.toList()) {
        await engine.removeTrack(track.id);
      }
      for (final marker in engine.markers.toList()) {
        engine.removeMarker(marker.id);
      }

      // Restore basic settings
      if (projectData['bpm'] != null) {
        engine.setBpm(projectData['bpm']);
      }
      if (projectData['timeSignature'] != null) {
        final ts = projectData['timeSignature'];
        engine.setTimeSignature(ts['beatsPerBar'] ?? 4, ts['beatUnit'] ?? 4);
      }

      // Restore markers
      if (projectData['markers'] != null) {
        final markersList = projectData['markers'] as List;
        for (final m in markersList) {
          engine.addMarkerAt(
            m['name'],
            m['positionMs'] ?? 0.0,
            endMs: m['endPositionMs'],
          );
        }
      }

      // Restore tracks
      if (projectData['tracks'] != null) {
        final tracksList = projectData['tracks'] as List;
        for (final tData in tracksList) {
          final filePath = tData['filePath'];
          if (filePath != null && File(filePath).existsSync()) {
            final track = await engine.addTrack(filePath, name: tData['name']);
            engine.setTrackVolume(track.id, tData['volume'] ?? 0.8);
            
            if (tData['isMuted'] == true) engine.toggleMute(track.id);
            if (tData['isSolo'] == true) engine.toggleSolo(track.id);
            
            track.trimStartMs = tData['trimStartMs'] ?? 0.0;
            track.trimEndMs = tData['trimEndMs'] ?? 0.0;
            track.offsetMs = tData['offsetMs'] ?? 0.0;
          } else {
            debugPrint('Warning: Track file not found $filePath');
          }
        }
      }

      await addRecentProject(path);

      return true;
    } catch (e) {
      debugPrint('Error loading project: $e');
      return false;
    }
  }
}
