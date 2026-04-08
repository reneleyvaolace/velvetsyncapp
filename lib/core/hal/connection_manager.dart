// ═══════════════════════════════════════════════════════════════
// Velvet Sync Platform · lib/core/hal/connection_manager.dart
// Gestor unificado de conexiones de dispositivos
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:velvet_sync/types/device_types.dart';
import 'package:velvet_sync/types/event_types.dart';
import 'package:velvet_sync/types/result_types.dart';
import 'device_interface.dart';

/// Gestor de conexiones para múltiples dispositivos
/// 
/// Centraliza la gestión de conexiones BLE, USB, WiFi, etc.
/// Proporciona una API unificada para conectar/desconectar dispositivos.
class ConnectionManager {
  static final ConnectionManager _instance = ConnectionManager._internal();
  factory ConnectionManager() => _instance;
  ConnectionManager._internal();
  
  /// Dispositivos conectados actualmente
  final Map<String, DeviceInterface> _connectedDevices = {};
  
  /// Dispositivos disponibles (descubiertos)
  final Map<String, DeviceInterface> _availableDevices = {};
  
  /// StreamController para eventos de conexión
  final _eventController = StreamController<PlatformEvent>.broadcast();
  
  /// Stream de eventos del connection manager
  Stream<PlatformEvent> get eventStream => _eventController.stream;
  
  /// Dispositivos conectados
  List<DeviceInterface> get connectedDevices => 
    _connectedDevices.values.toList();
  
  /// Dispositivos disponibles
  List<DeviceInterface> get availableDevices => 
    _availableDevices.values.toList();
  
  /// Número de dispositivos conectados
  int get connectedCount => _connectedDevices.length;
  
  /// Número de dispositivos disponibles
  int get availableCount => _availableDevices.length;
  
  /// Si está escaneando actualmente
  bool _isScanning = false;
  bool get isScanning => _isScanning;
  
  /// Timeout por defecto para conexiones (segundos)
  int connectionTimeoutSeconds = 30;
  
  /// Auto-reconectar si se pierde la conexión
  bool autoReconnect = true;
  
  // ═══════════════════════════════════════════════════════════
  // ESCANEO
  // ═══════════════════════════════════════════════════════════
  
  /// Escanear dispositivos disponibles
  /// 
  /// [deviceTypes] Tipos de dispositivos a buscar
  /// [timeout] Timeout del escaneo en segundos
  /// [onDeviceFound] Callback cuando encuentra un dispositivo
  /// 
  /// Returns: Lista de dispositivos encontrados
  Future<Result<List<DeviceInterface>, DeviceError>> scan({
    List<DeviceType>? deviceTypes,
    int timeout = 10,
    void Function(DeviceInterface device)? onDeviceFound,
  }) async {
    if (_isScanning) {
      return const Failure(DeviceError.alreadyConnected); // Ya está escaneando
    }
    
    _isScanning = true;
    _availableDevices.clear();
    
    _eventController.add(ScanStartedEvent(
      deviceTypes: deviceTypes ?? DeviceType.values,
    ));
    
    try {
      // Implementación específica según plataforma
      // Esto se sobrescribe en las implementaciones concretas
      final devices = await _performScan(
        deviceTypes: deviceTypes,
        timeout: timeout,
        onDeviceFound: onDeviceFound,
      );
      
      _isScanning = false;
      
      _eventController.add(ScanFinishedEvent(
        devicesFound: devices.length,
      ));
      
      return Success(devices);
    } catch (e) {
      _isScanning = false;
      return const Failure(DeviceError.bluetoothUnavailable);
    }
  }
  
  /// Implementación del escaneo (a sobrescribir)
  Future<List<DeviceInterface>> _performScan({
    List<DeviceType>? deviceTypes,
    required int timeout,
    void Function(DeviceInterface device)? onDeviceFound,
  }) async {
    // Implementación por defecto - debe ser sobrescrita
    await Future.delayed(Duration(seconds: timeout));
    return [];
  }
  
  /// Detener escaneo
  Future<void> stopScan() async {
    _isScanning = false;
  }
  
  // ═══════════════════════════════════════════════════════════
  // CONEXIÓN
  // ═══════════════════════════════════════════════════════════
  
  /// Conectar a un dispositivo
  /// 
  /// [deviceId] ID del dispositivo
  /// [autoConnect] Auto-reconectar si se pierde
  /// 
  /// Returns: [Success] si conecta, [Failure] con error
  Future<Result<DeviceInterface, DeviceError>> connect(
    String deviceId, {
    bool autoConnect = false,
  }) async {
    // Buscar en dispositivos disponibles
    var device = _availableDevices[deviceId];
    
    if (device == null) {
      // Intentar buscar en conectados
      if (_connectedDevices.containsKey(deviceId)) {
        return Success(_connectedDevices[deviceId]!);
      }
      return const Failure(DeviceError.notFound);
    }
    
    // Conectar
    final result = await device.connect();
    
    return result.fold(
      (error) => Failure(error),
      (_) {
        // Mover a conectados
        _connectedDevices[deviceId] = device;
        _availableDevices.remove(deviceId);
        
        _eventController.add(DeviceConnectedEvent(
          deviceId: deviceId,
          name: device.name,
          connectionTimeMs: DateTime.now().millisecondsSinceEpoch,
        ));
        
        return Success(device);
      },
    );
  }
  
  /// Desconectar dispositivo
  /// 
  /// [deviceId] ID del dispositivo
  /// [disconnectAll] Desconectar todos los dispositivos
  /// 
  /// Returns: [Success] si desconecta, [Failure] con error
  Future<Result<void, DeviceError>> disconnect(
    String deviceId, {
    bool disconnectAll = false,
  }) async {
    if (disconnectAll) {
      // Desconectar todos
      for (final device in _connectedDevices.values.toList()) {
        await _disconnectDevice(device);
      }
      return const Success(null);
    }
    
    var device = _connectedDevices[deviceId];
    
    if (device == null) {
      return const Failure(DeviceError.notConnected);
    }
    
    return await _disconnectDevice(device);
  }
  
  /// Desconectar dispositivo interno
  Future<Result<void, DeviceError>> _disconnectDevice(
    DeviceInterface device,
  ) async {
    final result = await device.disconnect();
    
    return result.fold(
      (error) => Failure(error),
      (_) {
        _eventController.add(DeviceDisconnectedEvent(
          deviceId: device.id,
          name: device.name,
          reason: DisconnectReason.normal,
        ));
        
        // Mover a disponibles
        _connectedDevices.remove(device.id);
        _availableDevices[device.id] = device;
        
        return const Success(null);
      },
    );
  }
  
  /// Desconectar todos los dispositivos
  Future<void> disconnectAll() async {
    await disconnect('', disconnectAll: true);
  }
  
  /// Verificar si un dispositivo está conectado
  bool isConnected(String deviceId) {
    return _connectedDevices.containsKey(deviceId);
  }
  
  /// Obtener dispositivo conectado
  DeviceInterface? getConnectedDevice(String deviceId) {
    return _connectedDevices[deviceId];
  }
  
  // ═══════════════════════════════════════════════════════════
  // GESTIÓN DE ESTADO
  // ═══════════════════════════════════════════════════════════
  
  /// Agregar dispositivo disponible
  void addAvailableDevice(DeviceInterface device) {
    _availableDevices[device.id] = device;
  }
  
  /// Remover dispositivo disponible
  void removeAvailableDevice(String deviceId) {
    _availableDevices.remove(deviceId);
  }
  
  /// Limpiar todos los dispositivos
  void clearAll() {
    _connectedDevices.clear();
    _availableDevices.clear();
  }
  
  // ═══════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════
  
  /// Cerrar connection manager
  Future<void> dispose() async {
    await disconnectAll();
    await _eventController.close();
  }
}

/// Configuración del escaneo
class ScanConfig {
  /// Tipos de dispositivo a escanear
  final List<DeviceType> deviceTypes;
  
  /// Timeout del escaneo
  final Duration timeout;
  
  /// Filtrar por RSSI mínimo
  final int? minRssi;
  
  /// Filtrar por nombre
  final Pattern? nameFilter;
  
  /// Si debe escanear continuamente
  final bool continuous;
  
  ScanConfig({
    this.deviceTypes = const [],
    this.timeout = const Duration(seconds: 10),
    this.minRssi,
    this.nameFilter,
    this.continuous = false,
  });
  
  /// Crear configuración para escaneo LVS
  factory ScanConfig.lvs({Duration? timeout}) {
    return ScanConfig(
      deviceTypes: [DeviceType.vibrator, DeviceType.multi],
      timeout: timeout ?? const Duration(seconds: 10),
    );
  }
  
  /// Crear configuración para escaneo Buttplug
  factory ScanConfig.buttplug({Duration? timeout}) {
    return ScanConfig(
      deviceTypes: DeviceType.values,
      timeout: timeout ?? const Duration(seconds: 15),
    );
  }
  
  /// Crear configuración para escaneo profundo
  factory ScanConfig.deepScan({Duration? timeout}) {
    return ScanConfig(
      deviceTypes: DeviceType.values,
      timeout: timeout ?? const Duration(seconds: 30),
      continuous: true,
    );
  }
}
