import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../ble/ble_service.dart';

final mediaSyncProvider = ChangeNotifierProvider((ref) => MediaSyncNotifier(ref));

class MediaSyncNotifier extends ChangeNotifier {
  final Ref ref;
  final AudioPlayer _player = AudioPlayer();
  List<double> _amplitudes = [];
  bool _isSyncing = false;
  String? _fileName;
  Timer? _syncTimer;

  MediaSyncNotifier(this.ref) {
    // Escuchar el progreso para actualizar la UI
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
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'mp4', 'm4a', 'wav'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      _fileName = result.files.single.name;
      
      await _player.setFilePath(path);
      
      // Extraer datos de la forma de onda (Energy Map)
      // Queremos 4Hz, así que muestras = segundos * 4
      final totalSeconds = _player.duration?.inSeconds ?? 0;
      final samplesNeeded = (totalSeconds * 4).clamp(10, 2000);
      
      final playerController = PlayerController();
      List<double> rawAmplitudes = await playerController.extractWaveformData(
        path: path,
        noOfSamples: samplesNeeded,
      );
      
      // Normalizar datos (convertir todos a escala 0.0 - 1.0)
      if (rawAmplitudes.isNotEmpty) {
        double maxAmp = rawAmplitudes.reduce((a, b) => a.abs() > b.abs() ? a.abs() : b.abs());
        if (maxAmp == 0) maxAmp = 1; // Prevenir división por 0
        
        _amplitudes = rawAmplitudes.map((amp) => amp.abs() / maxAmp).toList();
        debugPrint('[MediaSync] Waveform extraída: ${rawAmplitudes.length} muestras. Max RMS original: $maxAmp');
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
    // Intervalo de 250ms (4Hz) como pide el protocolo de ráfagas
    _syncTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!_isSyncing || !isPlaying) return;
      _processTick();
    });
  }

  void _processTick() {
    if (_amplitudes.isEmpty) return;
    
    final int durMs = _player.duration?.inMilliseconds ?? 1;
    final int posMs = _player.position.inMilliseconds;
    
    // Si la duración es menor o igual a 0, evitamos división por 0
    if (durMs <= 0) return;
    
    // Progreso de 0.0 a 1.0
    double progress = (posMs / durMs).clamp(0.0, 1.0);
    
    // Calcular índice proporcional exacto en el mapa de energía
    int index = (progress * _amplitudes.length).floor();
    if (index >= _amplitudes.length) index = _amplitudes.length - 1;
    if (index < 0) index = 0;

    final amplitude = _amplitudes[index].abs(); // Normalizado de 0.0 a 1.0
    
    // Mapeo a Canal 2 (Vibración - 0xA) - Rango 0 a 255. 
    // Usamos una curva para que los sonidos medios se sientan más
    int ch2Val = (math.pow(amplitude, 0.8) * 255).clamp(0, 255).toInt();
    
    // Detección de Pico (Beat > 80%) para Canal 1 (Empuje - 0xD)
    int ch1Val = 0;
    if (amplitude > 0.8) {
      ch1Val = 255; // Ráfaga máxima
    }

    // Enviar al BleService
    final ble = ref.read(bleProvider);
    if (ble.state == BleState.connected) {
       // Opcional: imprimir una vez cada 10 ciclos para no saturar consola, pero lo dejaré impreso para ti.
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
