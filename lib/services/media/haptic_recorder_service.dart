import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:velvet_sync/devices/models/funscript.dart';
import 'package:velvet_sync/utils/logger.dart';

class HapticRecorderService {
  bool _isRecording = false;
  int _startTimeMs = 0;
  int _lastRecordedAt = -1;
  final List<FunscriptAction> _actions = [];
  Timer? _sampleTimer;
  double _currentCh1 = 0.0;
  double _currentCh2 = 0.0;
  String? _lastSavePath;

  bool get isRecording => _isRecording;
  int get actionCount => _actions.length;
  String? get lastSavePath => _lastSavePath;

  VoidCallback? onRecordingStateChange;
  VoidCallback? onActionCountChange;

  void startRecording() {
    if (_isRecording) return;
    _isRecording = true;
    _actions.clear();
    _startTimeMs = DateTime.now().millisecondsSinceEpoch;
    _lastRecordedAt = -1;
    _currentCh1 = 0.0;
    _currentCh2 = 0.0;
    _lastSavePath = null;

    _sampleTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _sample();
    });

    lvsLog('Haptic recording started', tag: 'HAPTIC_REC');
    onRecordingStateChange?.call();
  }

  void updateIntensity(double ch1, double ch2) {
    _currentCh1 = ch1;
    _currentCh2 = ch2;
  }

  void _sample() {
    if (!_isRecording) return;

    final ch1Pos = (_currentCh1 * 99).round().clamp(0, 99);
    final ch2Pos = (_currentCh2 * 99).round().clamp(0, 99);
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - _startTimeMs;

    if (ch1Pos > 0 && (elapsedMs - _lastRecordedAt) >= 40) {
      _actions.add(FunscriptAction(pos: ch1Pos, at: elapsedMs));
      _lastRecordedAt = elapsedMs;
      onActionCountChange?.call();
    }

    if (ch2Pos > 0 && ch2Pos != ch1Pos) {
      _actions.add(FunscriptAction(pos: ch2Pos, at: elapsedMs));
    }
  }

  Future<String?> stopAndSave({String? fileName}) async {
    if (!_isRecording) return null;
    _isRecording = false;
    _sampleTimer?.cancel();
    _sampleTimer = null;

    if (_actions.isEmpty) {
      lvsLog('No actions recorded, nothing to save', tag: 'HAPTIC_REC');
      onRecordingStateChange?.call();
      return null;
    }

    _actions.sort((a, b) => a.at.compareTo(b.at));

    final script = Funscript(
      version: '1.0',
      actions: _actions,
      metadata: FunscriptMetadata(
        title: fileName ?? 'Grabación ${DateTime.now().toIso8601String()}',
        createdAt: DateTime.now(),
        tags: ['grabado', 'velvet-sync'],
      ),
    );

    try {
      final dir = await getApplicationDocumentsDirectory();
      final scriptsDir = Directory('${dir.path}/recordings');
      if (!scriptsDir.existsSync()) {
        await scriptsDir.create(recursive: true);
      }

      final name = fileName ?? 'recording_${DateTime.now().millisecondsSinceEpoch}';
      final path = '${scriptsDir.path}/${name.replaceAll(RegExp(r'[^\w\-]'), '_')}.funscript';
      await script.toFile(path);
      _lastSavePath = path;

      lvsLog('Recording saved: $path (${_actions.length} actions)', tag: 'HAPTIC_REC');
      onRecordingStateChange?.call();
      return path;
    } catch (e) {
      lvsLog('Error saving recording: $e', tag: 'HAPTIC_REC');
      onRecordingStateChange?.call();
      return null;
    }
  }

  void cancelRecording() {
    _isRecording = false;
    _sampleTimer?.cancel();
    _sampleTimer = null;
    _actions.clear();
    onRecordingStateChange?.call();
    lvsLog('Recording cancelled', tag: 'HAPTIC_REC');
  }

  void dispose() {
    cancelRecording();
    onRecordingStateChange = null;
    onActionCountChange = null;
  }
}
