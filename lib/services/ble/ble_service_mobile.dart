import 'dart:async';

export 'ble_service.dart';

class BleServiceMobile {
  static final BleServiceMobile _instance = BleServiceMobile._internal();
  factory BleServiceMobile() => _instance;
  BleServiceMobile._internal();
  
  dynamic get adapterState => null;
  bool get isScanning => false;
  static bool get isSupported => false;
  Future<void> initialize() async {}
  Future<List<dynamic>> scan({Duration timeout = const Duration(seconds: 10)}) async => [];
  Future<void> connect(dynamic device) async {}
  Future<void> disconnect(dynamic device) async {}
  Future<void> writeCommand(dynamic device, List<int> bytes, {String? serviceUuid}) async {}
  Future<void> dispose() async {}
}

dynamic getBleService() => BleServiceMobile();
