// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/ble/ble_service_stub.dart
// Fallback para plataformas no soportadas (Web / Desktop sin BLE)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/devices/models/toy_model.dart';
import 'lvs_commands.dart';

/// Provider mock para Web
final bleProvider = ChangeNotifierProvider((ref) => BleService());

enum BleState { idle, scanning, connecting, connected, error }

class BleService extends ChangeNotifier {
  BleState state = BleState.idle;
  
  bool get isConnected => state == BleState.connected;
  bool get isScanning => state == BleState.scanning;
  bool get isVirtualConnection => true;
  
  String connectedDeviceName = 'Simulador Web';
  
  ToyModel? activeToy;

  void setActiveToy(ToyModel? toy) {
    activeToy = toy;
    notifyListeners();
  }

  Future<void> connectToDevice({List<dynamic>? catalog}) async {
    state = BleState.scanning;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 1));
    state = BleState.connected;
    notifyListeners();
    debugPrint('[BleServiceStub] Conexión simulada activa');
  }

  Future<void> disconnect() async {
    state = BleState.idle;
    notifyListeners();
  }

  Future<bool> writeCommand(List<int> bytes, {String label = '', bool silent = false}) async {
    if (!silent) {
       debugPrint('[BleServiceStub] Simulating command: ${LvsCommands.bytesToHex(bytes)}');
    }
    return true;
  }

  Future<void> emergencyStop() async {
    debugPrint('[BleServiceStub] EMERGENCY STOP');
  }

  // Métodos requeridos por el Bridge
  void setCurrentToy(dynamic toy) {}
  void executeAICommand({required int intensity}) {}
}
