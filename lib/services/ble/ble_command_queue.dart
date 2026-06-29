import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'lvs_commands.dart';
import 'ble_types.dart';
import 'package:velvet_sync/utils/logger.dart';

class BleCommandQueue {
  final FlutterBlePeripheral _peripheral;
  final List<BluetoothDevice> Function() _getConnectedDevices;
  final PacketMode Function() _getPacketMode;
  final bool Function() _isTravelLocked;
  final void Function(String msg, String type) _log;
  final void Function() _notify;

  BleCommandQueue({
    required FlutterBlePeripheral peripheral,
    required List<BluetoothDevice> Function() getConnectedDevices,
    required PacketMode Function() getPacketMode,
    required bool Function() isTravelLocked,
    required void Function(String msg, String type) logFn,
    required void Function() notify,
  })  : _peripheral = peripheral,
        _getConnectedDevices = getConnectedDevices,
        _getPacketMode = getPacketMode,
        _isTravelLocked = isTravelLocked,
        _log = logFn,
        _notify = notify;

  final List<QueuedCommand> _commandQueue = [];
  bool _isProcessingQueue = false;
  bool _isWriting = false;
  List<int>? _lastPacket;

  bool isBurstActive = false;
  int burstIntervalMs = 200;
  Timer? _burstTimer;

  Future<bool> writeCommand(List<int> cmdBytes,
      {String label = '', bool silent = false}) async {
    if (_isTravelLocked() &&
        label != 'EMERGENCY_STOP' &&
        label != 'VERIFY') {
      if (!silent) _log('🔒 Comando bloqueado: Bloqueo de Viaje activo', 'warn');
      return false;
    }

    final completer = Completer<bool>();
    _commandQueue
        .add(QueuedCommand(cmdBytes, label, silent, completer));

    if (!_isProcessingQueue) {
      _processCommandQueue();
    }

    return completer.future.timeout(const Duration(seconds: 3), onTimeout: () {
      if (!silent) _log('⏰ Timeout comando: $label', 'warn');
      return false;
    });
  }

  void _processCommandQueue() async {
    if (_commandQueue.isEmpty) {
      _isProcessingQueue = false;
      return;
    }

    _isProcessingQueue = true;
    final cmd = _commandQueue.removeAt(0);

    if (_isWriting) {
      _commandQueue.insert(0, cmd);
      _isProcessingQueue = false;
      return;
    }

    _isWriting = true;
    try {
      final packet =
          LvsCommands.buildPacket(cmd.cmdBytes, mode: _getPacketMode());

      if (_lastPacket != null && listEquals(_lastPacket, packet)) {
        _isWriting = false;
        if (!cmd.completer.isCompleted) cmd.completer.complete(true);
        _processCommandQueue();
        return;
      }
      _lastPacket = packet;

      if (!cmd.silent) {
        _log('→ [${cmd.label}] ${LvsCommands.bytesToHex(packet)}', 'cmd');
      }

      final data = AdvertiseData(
        serviceUuid: LvsCommands.serviceUuid,
        manufacturerId: LvsCommands.companyId,
        manufacturerData: Uint8List.fromList(packet),
        includeDeviceName: false,
      );

      final parameters = AdvertiseSetParameters(
        connectable: true,
        scannable: true,
        legacyMode: true,
        interval: 160,
      );

      if (await _peripheral.isAdvertising) {
        await _peripheral.stop();
        await Future.delayed(const Duration(milliseconds: 15));
      }

      await _peripheral.start(
        advertiseData: data,
        advertiseSetParameters: parameters,
      );

      for (var dev in _getConnectedDevices()) {
        try {
          final services = await dev.discoverServices();
          for (var s in services) {
            if (s.uuid.toString().contains('fff0')) {
              for (var c in s.characteristics) {
                if (c.properties.write || c.properties.writeWithoutResponse) {
                  await c.write(packet, withoutResponse: true);
                }
              }
            }
          }
        } catch (e) {
          if (!cmd.silent) lvsLog('Error escribiendo a GATT: $e');
        }
      }

      if (!cmd.completer.isCompleted) cmd.completer.complete(true);
    } catch (e) {
      if (!cmd.silent) _log('✗ Error Peripheral: $e', 'error');
      _lastPacket = null;
      if (!cmd.completer.isCompleted) cmd.completer.complete(false);
    } finally {
      _isWriting = false;
      _processCommandQueue();
    }
  }

  void startBurst(List<int> cmdBytes, String label) {
    stopBurst();
    isBurstActive = true;
    _notify();
    _burstTimer = Timer.periodic(Duration(milliseconds: burstIntervalMs), (_) {
      writeCommand(cmdBytes, label: '$label ♻', silent: true);
    });
  }

  void stopBurst() {
    _burstTimer?.cancel();
    _burstTimer = null;
    isBurstActive = false;
  }

  void reset() {
    _isWriting = false;
    _lastPacket = null;
    for (final cmd in _commandQueue) {
      if (!cmd.completer.isCompleted) cmd.completer.complete(false);
    }
    _commandQueue.clear();
    _isProcessingQueue = false;
  }
}
