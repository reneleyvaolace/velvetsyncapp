import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/services/p2p/p2p_connection_manager.dart';
import 'package:velvet_sync/utils/logger.dart';

class RemoteHapticReceiver {
  StreamSubscription<Map<String, dynamic>>? _subscription;
  bool _isActive = false;
  bool _lastHadActivity = false;

  bool get isActive => _isActive;

  VoidCallback? onHapticReceived;
  VoidCallback? onConnectionChange;

  void startListening({
    required P2PConnectionManager p2p,
    required BleService ble,
  }) {
    stopListening();
    _isActive = true;

    _subscription = p2p.onCommandReceived.listen((cmd) => _handleCommand(cmd, ble));
    lvsLog('RemoteHapticReceiver: listening for P2P haptic commands', tag: 'HAPTIC_RX');
    onConnectionChange?.call();
  }

  void _handleCommand(Map<String, dynamic> cmd, BleService ble) {
    if (!_isActive) return;

    final type = cmd['type'] as String?;
    if (type != 'control_command') return;

    final ch1 = cmd['intensity_ch1'] as int? ?? 0;
    final ch2 = cmd['intensity_ch2'] as int? ?? 0;

    if (ble.state == BleState.connected) {
      ble.sendMultimediaSync(ch1, ch2);
    }

    final hasActivity = ch1 > 0 || ch2 > 0;
    if (hasActivity != _lastHadActivity) {
      _lastHadActivity = hasActivity;
      onHapticReceived?.call();
    }

    lvsLog('Remote haptic: CH1=$ch1 CH2=$ch2', tag: 'HAPTIC_RX');
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _isActive = false;
    _lastHadActivity = false;
    onConnectionChange?.call();
    lvsLog('RemoteHapticReceiver: stopped', tag: 'HAPTIC_RX');
  }

  void dispose() {
    stopListening();
    onHapticReceived = null;
    onConnectionChange = null;
  }
}

