// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/providers/media_sync_provider.dart
// Media Sync Provider - Sincronización de audio con hardware
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
<<<<<<< HEAD

=======
>>>>>>> 088fb8ed6ede4304227d867f93ab56660b547fd3
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../services/ble/ble_service.dart';

final mediaSyncProvider = ChangeNotifierProvider((ref) => MediaSyncNotifier(ref));

class MediaSyncNotifier extends ChangeNotifier {
  final Ref ref;
  final AudioPlayer _player = AudioPlayer();
  List<double> _amplitudes = [];
  bool _isSyncing = false;
  String? _fileName;
  Timer? _syncTimer;

  MediaSyncNotifier(this.ref) {
    _player.positionStream.listen((_) => notifyListeners());
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        stopSync();
      }
      notifyListeners();
    });
  }

  bool get isSyncing => _isSyncing;
  bool get isPlaying => _player.playing;
  String? get fileName => _fileName;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  List<double> get amplitudes => _amplitudes;

  Future<void> pickFile() async {
    var result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'mp4', 'm4a', 'wav'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      _fileName = result.files.single.name;

      await _player.setFilePath(path);

      final totalSeconds = _player.duration?.inSeconds ?? 0;
      final samplesNeeded = (totalSeconds * 4).clamp(10, 2000);

      final playerController = PlayerController();
      var rawAmplitudes = await playerController.extractWaveformData(
        path: path,
        noOfSamples: samplesNeeded,
      );

      if (rawAmplitudes.isNotEmpty) {
        var maxAmp = rawAmplitudes.reduce((a, b) => a.abs() > b.abs() ? a.abs() : b.abs());
        if (maxAmp == 0) maxAmp = 1;
        _amplitudes = rawAmplitudes.map((amp) => amp.abs() / maxAmp).toList();
        debugPrint('[MediaSync] Waveform extraída: ${rawAmplitudes.length} muestras');
      } else {
        _amplitudes = [];
      }

      notifyListeners();
    }
  }

  void toggleSync() {
    _isSyncing = !_isSyncing;
    if (_isSyncing) {
      _startSyncTimer();
    } else {
      _syncTimer?.cancel();
    }
    notifyListeners();
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!_isSyncing || !isPlaying) return;
      _processTick();
    });
  }

  void _processTick() {
    if (_amplitudes.isEmpty) return;

    final durMs = _player.duration?.inMilliseconds ?? 1;
    final posMs = _player.position.inMilliseconds;

    if (durMs <= 0) return;

    var progress = (posMs / durMs).clamp(0.0, 1.0);
    var index = (progress * _amplitudes.length).floor();
    if (index >= _amplitudes.length) index = _amplitudes.length - 1;
    if (index < 0) index = 0;

    final amplitude = _amplitudes[index].abs();

    var ch2Val = (math.pow(amplitude, 0.8) * 255).clamp(0, 255).toInt();

    var ch1Val = 0;
    if (amplitude > 0.8) {
      ch1Val = 255;
    }

    final ble = ref.read(bleProvider);
    if (ble.state == BleState.connected) {
       debugPrint('[MediaSync] ch1: $ch1Val, ch2: $ch2Val (amp: ${amplitude.toStringAsFixed(2)})');
       ble.sendMultimediaSync(ch1Val, ch2Val);
    }
  }

  void play() {
    _player.play();
    if (_isSyncing) _startSyncTimer();
    notifyListeners();
  }

  void pause() {
    _player.pause();
    _syncTimer?.cancel();
    notifyListeners();
  }

  void stopSync() {
    _isSyncing = false;
    _syncTimer?.cancel();
    _player.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}
