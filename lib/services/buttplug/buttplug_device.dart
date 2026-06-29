// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/buttplug/buttplug_device.dart
// Dispositivo Buttplug que implementa DeviceInterface
// ═══════════════════════════════════════════════════════════════

import 'package:velvet_sync/core/hal/device_interface.dart';
import 'package:velvet_sync/types/device_types.dart';
import 'package:velvet_sync/types/command_types.dart';
import 'package:velvet_sync/types/result_types.dart';
import 'package:velvet_sync/devices/models/buttplug_devices.dart' as db;
import 'package:velvet_sync/utils/logger.dart';
import 'buttplug_client_service.dart';

/// Dispositivo Buttplug que implementa DeviceInterface
///
/// Wrappe un dispositivo descubierto por Intiface Central y delega
/// el control a [ButtplugClientService].
class ButtplugDevice implements DeviceInterface {
  final ButtplugDeviceInfo _info;
  final db.ButtplugDevice? _catalogEntry;

  String _deviceStatus = 'available';
  double _batteryLevel = 0.0;
  bool _isCharging = false;
  double _rssi = 0.0;

  ButtplugDevice({
    required ButtplugDeviceInfo info,
    db.ButtplugDevice? catalogEntry,
  })  : _info = info,
        _catalogEntry = catalogEntry;

  // ═══════════════════════════════════════════════════════════
  // DeviceInterface - Propiedades
  // ═══════════════════════════════════════════════════════════

  @override
  String get id => 'buttplug_${_info.deviceIndex}';

  @override
  String get name => _info.deviceName;

  @override
  DeviceType get type {
    if (_catalogEntry == null) return DeviceType.vibrator;

    switch (_catalogEntry.formFactor) {
      case db.DeviceFormFactor.bullet:
        return DeviceType.bullet;
      case db.DeviceFormFactor.egg:
        return DeviceType.egg;
      case db.DeviceFormFactor.rabbit:
        return DeviceType.multi;
      case db.DeviceFormFactor.wand:
        return DeviceType.vibrator;
      case db.DeviceFormFactor.dildo:
        return DeviceType.thrusting;
      case db.DeviceFormFactor.masturbator:
        return DeviceType.thrusting;
      case db.DeviceFormFactor.prostate:
        return DeviceType.prostate;
      case db.DeviceFormFactor.clitoral:
        return DeviceType.clitoral;
      case db.DeviceFormFactor.couples:
        return DeviceType.multi;
      case db.DeviceFormFactor.other:
        return DeviceType.vibrator;
    }
  }

  @override
  ConnectionType get connectionType {
    if (_catalogEntry == null) return ConnectionType.wifi;

    if (_catalogEntry.connections.contains(db.ConnectionType.bluetoothLE)) {
      return ConnectionType.ble;
    }
    if (_catalogEntry.connections.contains(db.ConnectionType.usb)) {
      return ConnectionType.usb;
    }
    if (_catalogEntry.connections.contains(db.ConnectionType.wifi)) {
      return ConnectionType.wifi;
    }
    return ConnectionType.virtual;
  }

  @override
  ConnectionStatus get status {
    final client = ButtplugClientService();
    if (!client.isConnected) return ConnectionStatus.disconnected;
    return ConnectionStatus.connected;
  }

  @override
  DeviceStatus get deviceStatus {
    switch (_deviceStatus) {
      case 'inUse':
        return DeviceStatus.inUse;
      case 'unavailable':
        return DeviceStatus.unavailable;
      case 'lowBattery':
        return DeviceStatus.lowBattery;
      default:
        return DeviceStatus.available;
    }
  }

  @override
  String get protocolName => 'Buttplug';

  @override
  List<DeviceFeature> get supportedFeatures {
    final features = <DeviceFeature>[];
    if (_info.supportsVibrate) features.add(DeviceFeature.vibrate);
    if (_info.supportsRotate) features.add(DeviceFeature.rotate);
    if (_info.supportsLinear) features.add(DeviceFeature.thrust);
    if (_catalogEntry?.hasSuction == true) features.add(DeviceFeature.suction);
    if (_catalogEntry?.hasThrust == true) features.add(DeviceFeature.thrust);
    return features;
  }

  @override
  ControlPrecision get precision => ControlPrecision.precise;

  @override
  bool get hasDualChannel => _info.vibrateFeatureCount > 1;

  @override
  String get address => 'buttplug:${_info.deviceIndex}:${_info.deviceName}';

  @override
  double get batteryLevel => _batteryLevel;

  @override
  bool get isCharging => _isCharging;

  @override
  double get rssi => _rssi;

  @override
  Map<String, dynamic> get metadata => {
    'deviceIndex': _info.deviceIndex,
    'deviceName': _info.deviceName,
    'deviceMessages': _info.deviceMessages,
    'catalogBrand': _catalogEntry?.brand,
    'catalogModel': _catalogEntry?.model,
    'supportLevel': _catalogEntry?.supportLevel.name,
  };

  // ═══════════════════════════════════════════════════════════
  // DeviceInterface - Conexión
  // ═══════════════════════════════════════════════════════════

  @override
  Future<Result<void, DeviceError>> connect() async {
    try {
      final client = ButtplugClientService();
      if (client.isConnected) return const Success(null);

      await client.connect();
      lvsLog('ButtplugDevice conectado: $name', tag: 'BUTTPLUG');
      return const Success(null);
    } catch (e) {
      lvsLog('Error conectando ButtplugDevice: $e', tag: 'BUTTPLUG');
      return const Failure(DeviceError.connectionError);
    }
  }

  @override
  Future<Result<void, DeviceError>> disconnect() async {
    try {
      final client = ButtplugClientService();
      await client.disconnect();
      lvsLog('ButtplugDevice desconectado: $name', tag: 'BUTTPLUG');
      return const Success(null);
    } catch (e) {
      lvsLog('Error desconectando ButtplugDevice: $e', tag: 'BUTTPLUG');
      return const Failure(DeviceError.connectionError);
    }
  }

  @override
  Future<bool> isConnected() async {
    final client = ButtplugClientService();
    return client.isConnected;
  }

  // ═══════════════════════════════════════════════════════════
  // DeviceInterface - Control básico
  // ═══════════════════════════════════════════════════════════

  @override
  Future<Result<void, DeviceError>> stop() async {
    try {
      final client = ButtplugClientService();
      await client.stopDevice(_info.deviceIndex);
      return const Success(null);
    } catch (e) {
      return const Failure(DeviceError.connectionError);
    }
  }

  @override
  Future<Result<void, DeviceError>> stopFeature(
    DeviceFeature feature, {
    DeviceChannel channel = DeviceChannel.single,
  }) async {
    return stop();
  }

  // ═══════════════════════════════════════════════════════════
  // DeviceInterface - Features
  // ═══════════════════════════════════════════════════════════

  @override
  Future<Result<void, DeviceError>> vibrate(
    double intensity, {
    DeviceChannel channel = DeviceChannel.single,
  }) async {
    if (!_info.supportsVibrate) {
      return const Failure(DeviceError.unsupportedProtocol);
    }

    try {
      final client = ButtplugClientService();
      final speed = intensity.clamp(0.0, 1.0);

      if (channel == DeviceChannel.both) {
        for (var i = 0; i < _info.vibrateFeatureCount; i++) {
          await client.vibrate(_info.deviceIndex, speed, feature: i);
        }
      } else {
        final feature = channel == DeviceChannel.channel2 ? 1 : 0;
        await client.vibrate(_info.deviceIndex, speed, feature: feature);
      }

      return const Success(null);
    } catch (e) {
      return const Failure(DeviceError.connectionError);
    }
  }

  @override
  Future<Result<void, DeviceError>> rotate(
    double intensity, {
    DeviceChannel channel = DeviceChannel.single,
  }) async {
    if (!_info.supportsRotate) {
      return const Failure(DeviceError.unsupportedProtocol);
    }

    try {
      final client = ButtplugClientService();
      final speed = intensity.clamp(0.0, 1.0);

      if (channel == DeviceChannel.both) {
        for (var i = 0; i < _info.rotateFeatureCount; i++) {
          await client.rotate(_info.deviceIndex, speed, feature: i);
        }
      } else {
        final feature = channel == DeviceChannel.channel2 ? 1 : 0;
        await client.rotate(_info.deviceIndex, speed, feature: feature);
      }

      return const Success(null);
    } catch (e) {
      return const Failure(DeviceError.connectionError);
    }
  }

  @override
  Future<Result<void, DeviceError>> oscillate(
    double intensity, {
    DeviceChannel channel = DeviceChannel.single,
  }) async {
    return vibrate(intensity, channel: channel);
  }

  @override
  Future<Result<void, DeviceError>> thrust(
    double intensity, {
    double speed = 0.5,
  }) async {
    if (!_info.supportsLinear) {
      return const Failure(DeviceError.unsupportedProtocol);
    }

    try {
      final client = ButtplugClientService();
      final position = intensity.clamp(0.0, 1.0);
      final duration = (speed * 2000).clamp(100, 2000).toInt();
      await client.linear(_info.deviceIndex, duration, position);
      return const Success(null);
    } catch (e) {
      return const Failure(DeviceError.connectionError);
    }
  }

  @override
  Future<Result<void, DeviceError>> suction(
    double intensity, {
    String? pattern,
  }) async {
    // Suction no es soportado directamente por Buttplug.
    // Algunos dispositivos Lovense lo implementan como vibración en un feature.
    return vibrate(intensity);
  }

  // ═══════════════════════════════════════════════════════════
  // DeviceInterface - Patrones
  // ═══════════════════════════════════════════════════════════

  @override
  Future<Result<void, DeviceError>> executePattern(
    String patternId, {
    DeviceChannel channel = DeviceChannel.single,
  }) async {
    return stop();
  }

  @override
  Future<Result<void, DeviceError>> executeSequence(CommandSequence sequence) async {
    try {
      for (final cmd in sequence.commands) {
        Result<void, DeviceError> result;

        switch (cmd.type) {
          case CommandType.vibrate:
            result = await vibrate(cmd.intensity, channel: cmd.channel);
            break;
          case CommandType.rotate:
            result = await rotate(cmd.intensity, channel: cmd.channel);
            break;
          case CommandType.thrust:
            result = await thrust(cmd.intensity);
            break;
          case CommandType.stop:
            result = await stop();
            break;
          default:
            result = await vibrate(cmd.intensity, channel: cmd.channel);
        }

        if (result.isFailure) return result;
      }

      return const Success(null);
    } catch (e) {
      return const Failure(DeviceError.connectionError);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // DeviceInterface - Información
  // ═══════════════════════════════════════════════════════════

  @override
  Future<Result<double, DeviceError>> getBatteryLevel() async {
    return Success(_batteryLevel);
  }

  @override
  Future<Result<double, DeviceError>> getRssi() async {
    return Success(_rssi);
  }

  @override
  Future<Result<bool, DeviceError>> getChargingStatus() async {
    return Success(_isCharging);
  }

  // ═══════════════════════════════════════════════════════════
  // DeviceInterface - Configuración
  // ═══════════════════════════════════════════════════════════

  @override
  Future<Result<void, DeviceError>> updateConfiguration(
    Map<String, dynamic> config,
  ) async {
    return const Success(null);
  }

  @override
  Future<Result<Map<String, dynamic>, DeviceError>> getConfiguration() async {
    return Success({
      'deviceIndex': _info.deviceIndex,
      'deviceName': _info.deviceName,
    });
  }

  // ═══════════════════════════════════════════════════════════
  // DeviceInterface - Diagnóstico
  // ═══════════════════════════════════════════════════════════

  @override
  Future<Result<DeviceDiagnosticResult, DeviceError>> runDiagnostic() async {
    final client = ButtplugClientService();
    final connected = client.isConnected;

    if (!connected) {
      return Success(DeviceDiagnosticResult.failure(
        errors: ['Buttplug no está conectado a Intiface Central'],
      ));
    }

    return Success(DeviceDiagnosticResult.success(metrics: {
      'deviceIndex': _info.deviceIndex.toDouble(),
      'featureCount': _info.vibrateFeatureCount.toDouble(),
    }));
  }

  @override
  Future<Result<FirmwareInfo, DeviceError>> getFirmwareInfo() async {
    return Success(FirmwareInfo(
      version: 'Buttplug_v3',
      buildDate: null,
    ));
  }

  // ═══════════════════════════════════════════════════════════
  // Métodos internos
  // ═══════════════════════════════════════════════════════════

  void updateBattery(double level) {
    _batteryLevel = level.clamp(0.0, 1.0);
  }

  void updateCharging(bool charging) {
    _isCharging = charging;
  }

  void updateRssi(double value) {
    _rssi = value;
  }

  void updateDeviceStatus(String status) {
    _deviceStatus = status;
  }

  int get deviceIndex => _info.deviceIndex;

  ButtplugDeviceInfo get deviceInfo => _info;

  // ═══════════════════════════════════════════════════════════
  // DeviceInterface - Cleanup
  // ═══════════════════════════════════════════════════════════

  @override
  void dispose() {
    lvsLog('ButtplugDevice disposed: $name', tag: 'BUTTPLUG');
  }
}
