// NOTE: Requires 'video_player' package in pubspec.yaml:
//   video_player: ^2.9.2

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:velvet_sync/devices/models/funscript.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/services/p2p/p2p_connection_manager.dart';
import 'package:velvet_sync/utils/logger.dart';

class HapticVideoSyncService {
  VideoPlayerController? _controller;
  Funscript? _funscript;
  BleService? _ble;
  P2PConnectionManager? _p2p;
  bool _isActive = false;
  bool _isPaused = false;
  Timer? _syncTimer;
  int _lastCh1 = -1;
  int _lastCh2 = -1;
  double _smoothedCh1 = 0;
  double _smoothedCh2 = 0;
  double _previousPosition = 0.0;
  Duration _previousTimestamp = Duration.zero;
  double _smoothingFactor = 0.35;
  double _currentCh1 = 0.0;
  double _currentCh2 = 0.0;
  bool _p2pEnabled = false;

  bool get isActive => _isActive;
  bool get isPaused => _isPaused;
  double get currentCh1 => _currentCh1;
  double get currentCh2 => _currentCh2;
  bool get p2pEnabled => _p2pEnabled;

  VoidCallback? onIntensityUpdate;
  VoidCallback? onSyncStateChange;

  void configure({
    required VideoPlayerController controller,
    required Funscript funscript,
    required BleService ble,
    P2PConnectionManager? p2p,
    bool enableP2P = false,
    double smoothingFactor = 0.35,
  }) {
    stop();
    _controller = controller;
    _funscript = funscript;
    _ble = ble;
    _p2p = p2p;
    _p2pEnabled = enableP2P && p2p != null && p2p.isConnected;
    _smoothingFactor = smoothingFactor.clamp(0.1, 0.9);
  }

  void setP2PEnabled(bool enabled) {
    _p2pEnabled = enabled && _p2p != null && _p2p!.isConnected;
  }

  void start() {
    if (_controller == null || _funscript == null || _ble == null) {
      lvsLog('HapticVideoSync: cannot start - not configured', tag: 'HAPTIC_SYNC');
      return;
    }
    if (!_controller!.value.isInitialized) {
      lvsLog('HapticVideoSync: cannot start - controller not initialized', tag: 'HAPTIC_SYNC');
      return;
    }
    _isActive = true;
    _isPaused = false;
    _previousPosition = _funscript!.getPositionAt(_controller!.value.position);
    _previousTimestamp = _controller!.value.position;
    _lastCh1 = -1;
    _lastCh2 = -1;
    _smoothedCh1 = 0;
    _smoothedCh2 = 0;
    _currentCh1 = 0.0;
    _currentCh2 = 0.0;
    _startSyncTimer();
    onSyncStateChange?.call();
    lvsLog('Haptic sync started', tag: 'HAPTIC_SYNC');
  }

  void pause() {
    _isPaused = true;
    _syncTimer?.cancel();
    _sendStop();
    _lastCh1 = -1;
    _lastCh2 = -1;
    onSyncStateChange?.call();
    lvsLog('Haptic sync paused', tag: 'HAPTIC_SYNC');
  }

  void resume() {
    if (!_isActive) return;
    _isPaused = false;
    _previousPosition = _funscript?.getPositionAt(_controller?.value.position ?? Duration.zero) ?? 0.0;
    _previousTimestamp = _controller?.value.position ?? Duration.zero;
    _startSyncTimer();
    onSyncStateChange?.call();
    lvsLog('Haptic sync resumed', tag: 'HAPTIC_SYNC');
  }

  void stop() {
    _isActive = false;
    _isPaused = false;
    _syncTimer?.cancel();
    _sendStop();
    _lastCh1 = -1;
    _lastCh2 = -1;
    _smoothedCh1 = 0;
    _smoothedCh2 = 0;
    _currentCh1 = 0.0;
    _currentCh2 = 0.0;
    _previousPosition = 0.0;
    _previousTimestamp = Duration.zero;
    onIntensityUpdate?.call();
    onSyncStateChange?.call();
    lvsLog('Haptic sync stopped', tag: 'HAPTIC_SYNC');
  }

  void updateFunscript(Funscript funscript) {
    _funscript = funscript;
    _lastCh1 = -1;
    _lastCh2 = -1;
    lvsLog('Funscript updated in sync service', tag: 'HAPTIC_SYNC');
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _processTick();
    });
  }

  void _processTick() {
    if (_isPaused || !_isActive) return;
    if (_controller == null || _funscript == null || _ble == null) return;
    if (!_controller!.value.isInitialized) return;

    final position = _controller!.value.position;
    final duration = _controller!.value.duration;
    if (duration.inMilliseconds <= 0) return;

    if (position >= duration && position.inMilliseconds > 0) {
      stop();
      return;
    }

    final pos = _funscript!.getPositionAt(position);

    var ch1 = (pos * 255).round().clamp(0, 255);

    var ch2 = 0;
    if (_previousTimestamp.inMilliseconds > 0) {
      final dt = (position.inMilliseconds - _previousTimestamp.inMilliseconds).clamp(1, 500);
      final velocity = ((pos - _previousPosition).abs() / (dt / 1000.0)).clamp(0.0, 1.0);
      ch2 = (velocity * 255).round().clamp(0, 255);
    }

    _smoothedCh1 += (ch1 - _smoothedCh1) * _smoothingFactor;
    _smoothedCh2 += (ch2 - _smoothedCh2) * _smoothingFactor;

    final smoothedCh1Int = _smoothedCh1.round().clamp(0, 255);
    final smoothedCh2Int = _smoothedCh2.round().clamp(0, 255);

    _currentCh1 = smoothedCh1Int / 255.0;
    _currentCh2 = smoothedCh2Int / 255.0;

    if (smoothedCh1Int != _lastCh1 || smoothedCh2Int != _lastCh2) {
      _lastCh1 = smoothedCh1Int;
      _lastCh2 = smoothedCh2Int;

      if (_ble!.state == BleState.connected) {
        _ble!.sendMultimediaSync(smoothedCh1Int, smoothedCh2Int);
      }

      if (_p2pEnabled && _p2p != null) {
        _p2p!.sendCommand(
          intensityCh1: smoothedCh1Int,
          intensityCh2: smoothedCh2Int,
          commandType: 'funscript_sync',
        );
      }
    }

    _previousPosition = pos;
    _previousTimestamp = position;
    onIntensityUpdate?.call();
  }

  void _sendStop() {
    if (_ble != null && _ble!.state == BleState.connected) {
      _ble!.sendMultimediaSync(0, 0);
    }
    if (_p2pEnabled && _p2p != null) {
      _p2p!.sendCommand(
        intensityCh1: 0,
        intensityCh2: 0,
        commandType: 'funscript_sync',
      );
    }
  }

  void dispose() {
    stop();
    _controller = null;
    _funscript = null;
    _ble = null;
    onIntensityUpdate = null;
    onSyncStateChange = null;
  }
}
