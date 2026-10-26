// Velvet Sync · lib/services/ble/ble_service_stub.dart
// Fallback para plataformas no soportadas (Web / Desktop sin BLE)

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/ble/lvs_commands.dart';
import 'ble_types.dart';
export 'ble_types.dart';

final bleProvider = ChangeNotifierProvider((ref) => BleService());

class BleService extends ChangeNotifier {
  BleState state = BleState.idle;
  bool get isConnected => state == BleState.connected;
  bool get hasHardwareConnection => state == BleState.connected;
  bool get isScanning => state == BleState.scanning;
  bool get isVirtualConnection => true;
  bool get isDemoMode => false;
  bool get hasGatt => false;

  String connectedDeviceName = 'Simulador Web';
  List<dynamic> connectedDevices = const [];
  PacketMode packetMode = PacketMode.b11;
  bool isBurstActive = false;
  int burstIntervalMs = 250;
  bool isDeepScan = false;
  int batteryLevel = 0;
  bool isBridgeModeActive = false;
  bool isTravelLockActive = false;
  List<BleLogEntry> get logs => const [];

  void setActiveToy(dynamic toy) {
    toy = toy;
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
    if (!silent) debugPrint('[BleServiceStub] Simulating command: ${LvsCommands.bytesToHex(bytes)}');
    return true;
  }

  Future<void> emergencyStop() async => debugPrint('[BleServiceStub] EMERGENCY STOP');
  Future<void> initSecurity() async => debugPrint('[BleServiceStub] Security Initialized');
  void clearLogs() => notifyListeners();

  void writeDebugCommand(int b0, int b1, int b2, {bool silent = false}) async {
    await writeCommand([b0, b1, b2], label: 'DBG', silent: silent);
  }
  void setBurstInterval(int ms) => burstIntervalMs = ms;
  void toggleDeepScan() => isDeepScan = !isDeepScan;
  void setPacketMode(PacketMode mode) {
    packetMode = mode;
    notifyListeners();
  }
  void toggleDemoMode() => notifyListeners();
  Future<bool> toggleTravelLock(String pin) async {
    isTravelLockActive = !isTravelLockActive;
    notifyListeners();
    return true;
  }
  void toggleBridgeMode() {
    isBridgeModeActive = !isBridgeModeActive;
    notifyListeners();
  }
  void selectSpeed(dynamic level) {}
  void selectPattern(dynamic pattern) {}
  void setProportionalIntensity(int intensity) {}
  void sendMultimediaSync(int ch1Val, int ch2Val) async {}

  int? get activePatternCh1 => null;
  int? get activePatternCh2 => null;

  void setPatternChannel1(int i) {}
  void setPatternChannel2(int i) {}
  void setDevicePatternCh1(dynamic btn, int i) {}
  void setDevicePatternCh2(dynamic btn, int i) {}
  void setProportionalChannel1(int i) {}
  void setProportionalChannel2(int i) {}
  void stopAllMotors() async {}

  bool get heatingActive => false;
  int get heatingLevel => 0;
  int get strikeIndex => -1;
  bool get suctionActive => false;
  int get suctionLevel => 0;
  void setStrike(int index) {}
  void stopStrike() {}
  void setSuction(bool? on) {}
  void setSuctionLevel(int level) {}
  void stopSpecialFunctions() {}

  void setCurrentToy(dynamic toy) {}
  void executeAICommand({required int intensity}) {}
}
