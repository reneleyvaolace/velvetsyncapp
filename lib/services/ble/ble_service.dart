// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/ble/ble_service.dart
// Re-export de la implementación móvil (ble_service_mobile.dart)
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'lvs_commands.dart';
import 'ble_protocol.dart';
import 'ble_types.dart';
import 'ipao_protocol.dart' as ipao;
import 'crypt_ble.dart';
import 'lovespouse_protocol.dart';
import 'package:velvet_sync/devices/models/toy_model.dart';
import 'toy_profile.dart';
import 'package:velvet_sync/utils/logger.dart';
import 'package:velvet_sync/services/backend/notification_service.dart';
import 'package:velvet_sync/controllers/device_controller.dart';


// ── Provider Global para Riverpod ──────────────────────────────
final bleProvider = ChangeNotifierProvider((ref) => BleService());
final deviceControllerProvider = ChangeNotifierProvider((ref) => DeviceController());



// 🔒 PERFORMANCE: Clase para cola de comandos BLE
class _QueuedCommand {
  final List<int> cmdBytes;
  final String label;
  final bool silent;
  final Completer<bool> completer;

  _QueuedCommand(this.cmdBytes, this.label, this.silent, this.completer);
}

class BleService extends ChangeNotifier {
  // ── Estado ─────────────────────────────────────────────────
  BleState state = BleState.idle;
  List<BluetoothDevice> connectedDevices = [];
  BluetoothDevice? _lastConnectedDevice; // Último dispositivo conectado
  BluetoothCharacteristic? characteristic;
  ToyProfile? toyProfile;
  ToyModel? activeToy; // El modelo del catálogo que está en uso

  // Nombre real del hardware detectado en la sesión actual
  String connectedDeviceName = '';

  // Guarda el nombre real detectado durante el escaneo BLE (advName)
  String _discoveredDeviceName = '';

  // ── NUEVO: Control de conexión real vs virtual ─────────────
  // True si hay hardware físico confirmado mediante handshake
  bool _hardwareConfirmed = false;

  // ── VARIABLES RECUPERADAS ────────────────────────────────
  Timer? _heartbeatTimer;
  Timer? _smoothingTimer;
  bool _demoMode = false;
  bool isBridgeModeActive = false;
  bool isTravelLockActive = false;

  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();

  SpeedLevel? activeSpeed;
  LvsPattern? activePattern;
  int? activeIntensity;
  int? activeIntensityCh1;
  int? activeIntensityCh2;
  int? activePatternCh1;
  int? activePatternCh2;

  PacketMode packetMode = PacketMode.b11;
  bool isBurstActive   = false;
  int burstIntervalMs  = 250;
  bool isDeepScan      = false;
  int batteryLevel     = 0;
  ToyModel? _pendingToy;

  // Notificaciones
  NotificationService? _notificationService;

  bool isCooldownActive = false;
  int cooldownRemaining = 0;
  Timer? _cooldownTimer;

  static const List<int> verificationCmd = [0x01, 0x01, 0x01];
  static const List<int> verificationCmdNew = [0x01, 0x01, 0x01, 0x01]; // NewCommand handshake
  static const int expectedAck = 0x06;

  // ── Debounce para notifyListeners (evita rebuilds excesivos de UI) ──
  Timer? _notifyDebounceTimer;
  bool _notifyPending = false;

  void _notifyListeners() {
    if (_notifyPending) return; // Ya hay una notificación pendiente
    _notifyPending = true;
    _notifyDebounceTimer?.cancel();
    _notifyDebounceTimer = Timer(const Duration(milliseconds: 80), () {
      _notifyPending = false;
      super.notifyListeners();
    });
  }

  void activateCooldown() {
    emergencyStop();
    isCooldownActive = true;
    cooldownRemaining = 60;
    _notifyListeners();

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      cooldownRemaining--;
      if (cooldownRemaining <= 0) {
        isCooldownActive = false;
        timer.cancel();
      }
      _notifyListeners();
    });
  }

  // ── Getters de Estado ─────────────────────────────────────
  bool get isConnected => state == BleState.connected && _hardwareConfirmed;
  bool get isScanning  => state == BleState.scanning;
  bool get hasGatt      => connectedDevices.isNotEmpty;
  bool get isDemoMode  => _demoMode;

  // ── NUEVO: Verificar si es conexión virtual (sin hardware) ──
  bool get isVirtualConnection => state == BleState.connected && !_hardwareConfirmed;

  // ── Activación desde Catálogo (Virtual) ──────────────────
  void setActiveToy(ToyModel toy) {
    activeToy = toy;
    toyProfile = ToyProfile(
      name: toy.name,
      identifier: toy.id,
      hasDualChannel: toy.hasDualChannel,
    );
    connectedDeviceName = toy.name;

    // Inicializar servicio de notificaciones
    _initNotifications();

    // ── NUEVO: Marcar como conexión VIRTUAL (sin hardware real) ──
    _hardwareConfirmed = false;
    _setState(BleState.connected); // Estado "virtual" para UI

    _log('📱 Dispositivo "${toy.name}" activado desde el catálogo (MODO VIRTUAL - sin hardware)', 'info');
    _notifyListeners();
  }

  void _initNotifications() {
    if (_notificationService == null) {
      _notificationService = NotificationService();
      _notificationService!.init();
    }
  }

  /// ── NUEVO: Método para verificar si hay hardware real conectado ──
  Future<bool> verifyHardwareConnection() async {
    if (!_hardwareConfirmed) {
      _log('⚠️ No hay hardware confirmado. Intentando verificar...', 'warn');
      // Intentar handshake de verificación
      final ok = await writeCommand(verificationCmd, label: 'VERIFY_HW', silent: true);
      if (ok) {
        _hardwareConfirmed = true;
        _initNotifications();
        _log('✅ Hardware verificado exitosamente', 'success');
      } else {
        _log('❌ No hay hardware físico presente', 'error');
      }
      return ok;
    }
    return true;
  }

  void renameActiveToy(String newName) {
    if (activeToy == null) return;
    final updated = ToyModel(
      id: activeToy!.id,
      name: newName,
      usageType: activeToy!.usageType,
      targetAnatomy: activeToy!.targetAnatomy,
      stimulationType: activeToy!.stimulationType,
      motorLogic: activeToy!.motorLogic,
      imageUrl: activeToy!.imageUrl,
      qrCodeUrl: activeToy!.qrCodeUrl,
      supportedFuncs: activeToy!.supportedFuncs,
      isPrecise: activeToy!.isPrecise,
      broadcastPrefix: activeToy!.broadcastPrefix,
      bleProtocol: activeToy!.bleProtocol,
      isPrivateProtocol: activeToy!.isPrivateProtocol,
      encryptCommand: activeToy!.encryptCommand,
    );
    activeToy = updated;
    toyProfile = ToyProfile(
      name: newName,
      identifier: updated.id,
      hasDualChannel: updated.hasDualChannel,
    );
    connectedDeviceName = newName;
    _notifyListeners();
  }

  // ── Getter Dinámico para Podómetro Frontal ────────────────
  int get displayIntensity {
    if (activeIntensity != null) return activeIntensity!;
    if (activeIntensityCh1 != null || activeIntensityCh2 != null) {
      return math.max(activeIntensityCh1 ?? 0, activeIntensityCh2 ?? 0);
    }
    if (activeSpeed != null) {
      switch (activeSpeed!) {
        case SpeedLevel.low: return 33;
        case SpeedLevel.medium: return 66;
        case SpeedLevel.high: return 100;
        default: return 0;
      }
    }
    if (activePattern != null || activePatternCh1 != null || activePatternCh2 != null) {
      return 75;
    }
    return 0;
  }

  // Log - 🔒 PERFORMANCE: Limitado a 100 entradas para prevenir memory growth
  final List<BleLogEntry> _logs = [];
  List<BleLogEntry> get logs {
    const maxLogs = 100;
    if (_logs.length <= maxLogs) return List.from(_logs);
    return _logs.sublist(_logs.length - maxLogs);
  }

  // ── Secuenciador Asíncrono ─────────────────────────────────
  WaveType activeWaveCh1 = WaveType.none;
  WaveType activeWaveCh2 = WaveType.none;
  int waveMaxIntensityCh1 = 100;
  int waveMaxIntensityCh2 = 100;
  Timer? _sequenceTimer;
  int _sequenceTick = 0;
  bool _isCh1Turn = true;

  // ── Timers ─────────────────────────────────────────────────
  Timer? _burstTimer;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _batterySub;

  // ── Constantes de escaneo ──────────────────────────────────
  static const _scanTimeout = Duration(seconds: 20);

  // ══════════════════════════════════════════════════════════════
  // PERMISOS Y FOREGROUND
  // ══════════════════════════════════════════════════════════════
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.locationWhenInUse,
        Permission.notification,
      ].request();

      // En Android 12+, la ubicación se puede denegar y aún así el BLE escanea
      // gracias a neverForLocation. Por lo que toleramos que location falle
      // siempre y cuando tengamos bluetoothScan y Connect.
      final btScanOk = statuses[Permission.bluetoothScan]?.isGranted == true || statuses[Permission.bluetoothScan]?.isLimited == true;
      final btConnOk = statuses[Permission.bluetoothConnect]?.isGranted == true || statuses[Permission.bluetoothConnect]?.isLimited == true;
      final locOk    = statuses[Permission.locationWhenInUse]?.isGranted == true || statuses[Permission.locationWhenInUse]?.isLimited == true;

      // Si tenemos los nuevos permisos BLE explícitos (API 31+), confiamos en ellos.
      // Si no, recaemos en que locOk debe ser cierto para API < 31.
      return (btScanOk && btConnOk) || locOk;
    } else if (Platform.isIOS) {
      final bt = await Permission.bluetooth.request();
      return bt.isGranted;
    }
    return true;
  }

  Future<void> startForegroundService() async {
    if (!Platform.isAndroid) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'lvs_ble_channel',
        channelName: 'LVS Control BLE',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),
        allowWakeLock: true,
      ),
    );
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: 8154,
      notificationTitle: 'LVS Control',
      notificationText: 'Buscando wbMSE / 8154…',
      callback: startCallback,
    );
  }

  Future<void> stopForegroundService() async => Platform.isAndroid ? await FlutterForegroundTask.stopService() : null;

  Future<void> _updateNotification(String text) async {
    if (Platform.isAndroid && await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(notificationText: text);
    }
  }

  // ══════════════════════════════════════════════════════════════
  // ESCANEO Y CONEXIÓN
  // ══════════════════════════════════════════════════════════════

  // 🔒 PERFORMANCE: Throttling para prevenir escaneos repetitivos
  DateTime? _lastScanTime;
  static const Duration _scanCooldown = Duration(seconds: 5);

  Future<void> connectToDevice({List<ToyModel>? catalog}) async {
    if (state == BleState.scanning || state == BleState.connecting) return;

    _discoveredDeviceName = ''; // Reset para nueva búsqueda

    // 🔒 PERFORMANCE: Throttling - evitar escaneos muy seguidos
    final now = DateTime.now();
    if (_lastScanTime != null) {
      final elapsed = now.difference(_lastScanTime!);
      if (elapsed < _scanCooldown) {
        final waitTime = (_scanCooldown - elapsed).inMilliseconds;
        _log('Scan throttled: esperar ${waitTime}ms', 'debug');
        await Future.delayed(Duration(milliseconds: waitTime));
      }
    }
    _lastScanTime = now;

    if (!await requestPermissions()) return;

    if (!await FlutterBluePlus.isSupported) {
      _log('Bluetooth no soportado.', 'error');
      return;
    }

    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      _log('Encendiendo Bluetooth...', 'warn');
      if (Platform.isAndroid) await FlutterBluePlus.turnOn();
      await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first.timeout(const Duration(seconds: 3)).catchError((_) => BluetoothAdapterState.off);
    }

    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
       _log('No se pudo encender el Bluetooth.', 'error');
       return;
    }

    await startForegroundService();
    _setState(BleState.scanning);
    lvsLog('INICIANDO ESCANEO - Deep Scan: $isDeepScan', tag: 'BLE');
    _log(isDeepScan ? 'MODO DEEP SCAN ACTIVO' : 'Escaneando dispositivos LVS...', 'info');

    BluetoothDevice? found;
    try {
      await FlutterBluePlus.startScan(
        timeout: _scanTimeout,
        androidScanMode: AndroidScanMode.lowLatency,
        removeIfGone: const Duration(seconds: 5),
        continuousUpdates: true,
      );

      final subscription = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          final name = r.advertisementData.advName;
          final realName = name.isEmpty ? r.device.platformName : name;
          final rssi = r.rssi;
          final mac  = r.device.remoteId.str;

          // ── NUEVO: Filtro de RSSI mínimo para evitar falsos positivos ──
          // Si la señal es muy débil (< -85 dBm), probablemente esté fuera de rango
          // o sea ruido. Ignoramos a menos que sea un match muy claro.
          final isWeakSignal = rssi < -85;

          // Filtros base: LVS por nombre conocido
          final hasId       = realName.contains('8154') || realName.contains('LVS');
          final isBroadlink = realName.startsWith('wbMSE');

          // ✨ NUEVO: coincidencia con catálogo (incluye pre-registrados)
          var matchesCatalog = false;
          if (catalog != null && realName.isNotEmpty) {
            matchesCatalog = catalog.any((toy) =>
              realName.contains(toy.id) ||
              realName.toLowerCase().contains(toy.name.toLowerCase()) ||
              toy.name.toLowerCase() == realName.toLowerCase()
            );
          }

          if (isDeepScan) {
             _log('👁️ [DEEP] "$realName" RSSI: $rssi ${isWeakSignal ? "(SEÑAL DÉBIL)" : ""}', 'info');
          }

          // ── NUEVO: Validación más estricta para evitar falsos positivos ──
          var shouldConnect = false;
          var reason = '';

          if (hasId || isBroadlink || matchesCatalog) {
            // Si es un match claro, conectar solo si la señal es razonable
            if (!isWeakSignal || matchesCatalog) {
              shouldConnect = true;
              reason = matchesCatalog ? 'PRE-REGISTRADO' : (isBroadlink ? 'Broadlink' : 'ID');
            } else {
              _log('⚠️ MATCH ignorado por señal débil ($rssi dBm): "$realName"', 'warn');
            }
          } else if (isDeepScan && !isWeakSignal && rssi > -75) {
             // En Deep Scan, solo si la señal es buena
             shouldConnect = true;
             reason = 'Deep Scan (RSSI: $rssi)';
          }

          if (shouldConnect && found == null) {
            _log('🎯 MATCH ($reason): "$realName" [$mac] RSSI: $rssi', 'success');
            found = r.device;
            // Guardar nombre real detectado (de advertisement, no platformName que da "N/A" en Android)
            final cleanName = (realName.isEmpty || realName == 'N/A' || realName == 'Unknown') ? mac : realName;
            _discoveredDeviceName = cleanName;
            FlutterBluePlus.stopScan();
          }
        }
      });

      await FlutterBluePlus.isScanning.where((v) => !v).first;
      await subscription.cancel();
    } catch (e) {
      _log('Error de escaneo: $e', 'error');
      _setState(BleState.idle);
      return;
    }

    if (found == null) {
      if (!isDeepScan) {
        _log('Búsqueda rápida falló, activando Deep Scan oculto...', 'warn');
        isDeepScan = true;
        _lastScanTime = null; // Reiniciar cooldown para escaneo inmediato
        _setState(BleState.idle); // Necesario para que el if de arriba no bloquee
        await connectToDevice(catalog: catalog);
        return; // El recursivo maneja el resto
      } else {
        _log('No se encontró dispositivo compatible ni con Deep Scan.', 'error');
        _setState(BleState.idle);
        isDeepScan = false; // Reset para el siguiente intento
        return;
      }
    }
    
    // Si lo encontró, resetear la variable para futuras búsquedas limpias
    isDeepScan = false;

    // Usar el nombre detectado durante el escaneo (advName), no platformName
    // que en Android puede devolver "N/A".
    final rawName = _discoveredDeviceName.isNotEmpty
        ? _discoveredDeviceName
        : found!.remoteId.str;
    connectedDeviceName = rawName;
    _notifyListeners();

    if (catalog != null) {
      toyProfile = ToyProfile.fromCatalog(rawName, catalog);
      final matched = catalog!.where((t) =>
        rawName.contains(t.id) ||
        t.name.toLowerCase() == rawName.toLowerCase() ||
        t.broadcastPrefix.contains(rawName)
      ).firstOrNull;
      if (matched != null) _pendingToy = matched;
    }
    toyProfile ??= ToyProfile.fromName(rawName);

    _log('✓ Encontrado: $rawName (${toyProfile!.name})', 'success');
    await _setupFastcon(found!);
  }

  double stealthIntensityCap = 1.0;

  Future<void> _setupFastcon(BluetoothDevice dev) async {
    _setState(BleState.connecting);
    _log('🔐 Handshake: Verificando hardware activo...', 'info');

    const handshakeTimeout = Duration(seconds: 3);

try {
      // ── PASO 1: CONEXIÓN GATT REAL ──
      // Si no se puede conectar vía GATT, el dispositivo está apagado o fuera de rango
      _log('🔗 Estableciendo conexión GATT...', 'info');
      try {
                await dev.connect(timeout: const Duration(seconds: 5), license: License.free);
      } catch (e) {
        _log('❌ No se pudo conectar GATT: $e. Dispositivo apagado o fuera de rango.', 'error');
        connectedDeviceName = '';
        connectedDevices.remove(dev);
        _hardwareConfirmed = false;
        _setState(BleState.idle);
        _showHardwareNotFoundSnackbar();
        return;
      }

      if (!connectedDevices.contains(dev)) {
        connectedDevices.add(dev);
      }

      // ── PASO 2: HANDSHAKE VÍA GATT ──
      // Escribir comando de verificación al UUID del protocolo detectado
      // Usar NewCommand handshake si el dispositivo lo soporta
      final verifyCmd = (activeToy != null && activeToy!.isNewCommand) 
          ? verificationCmdNew 
          : verificationCmd;
      final ok = await writeCommand(verifyCmd, label: 'VERIFY', silent: false)
          .timeout(handshakeTimeout, onTimeout: () {
            _log('⏱️ Timeout de handshake (3s) - hardware no responde', 'error');
            return false;
          });

      if (!ok) {
        _log('❌ Handshake fallido: el hardware no responde. Conexión RECHAZADA.', 'error');
        _log('   Posibles causas: 1) Dispositivo apagado, 2) Fuera de rango, 3) Falso positivo en escaneo', 'warn');
        connectedDeviceName = '';
        connectedDevices.remove(dev);
        _hardwareConfirmed = false;
        _setState(BleState.idle);

        // Mostrar mensaje al usuario
        _showHardwareNotFoundSnackbar();
        return;
      }

      // Pausa para recibir el ACK (0x06) del hardware
      await Future.delayed(const Duration(milliseconds: 300));

      // ── NUEVO: Segunda verificación para confirmar ──
      // Usar NewCommand final handshake si el dispositivo lo soporta
      final finalCmd = (activeToy != null && activeToy!.isNewCommand)
          ? LoveSpouseCommands.handshakeFinal
          : [0x00, 0x00, 0x00];
      await Future.delayed(const Duration(milliseconds: 200));
      final secondCheck = await writeCommand(finalCmd, label: 'VERIFY2', silent: true)
          .timeout(const Duration(milliseconds: 1500), onTimeout: () => false);

      if (!secondCheck) {
        _log('⚠️ Segunda verificación fallida - hardware inestable', 'warn');
        // No rechazamos, pero logueamos
      }


      _hardwareConfirmed = true;
      _lastConnectedDevice = dev; // Rastrear último dispositivo conectado
      _initNotifications();
      batteryLevel = 100;

      // ── NUEVO: Configurar notificaciones GATT para LoveSpouse (telemetría) ──
      if (_activeProtocol == BleProtocolType.loveSpouse) {
        await _setupLoveSpouseNotifications(dev);
      }

      // Intentar leer el Device Name via GATT (0x2A00)
      // Útil cuando advName viene vacío y platformName devuelve "N/A"
      final gattName = await _readDeviceName(dev);
      if (gattName != null && gattName.isNotEmpty &&
          (connectedDeviceName.isEmpty || connectedDeviceName == 'N/A' || connectedDeviceName == 'Unknown' || connectedDeviceName.contains(':'))) {
        connectedDeviceName = gattName;
        _log('📛 Nombre obtenido vía GATT: "$gattName"', 'success');
        _notifyListeners();
      }

      if (activeToy == null && connectedDeviceName.isNotEmpty) {
        setActiveToy(_pendingToy ?? ToyModel(
          id: connectedDeviceName,
          name: connectedDeviceName,
          usageType: 'Universal',
          targetAnatomy: 'Universal',
          stimulationType: 'Vibración',
          motorLogic: 'Single Channel',
          imageUrl: '',
          qrCodeUrl: '',
          supportedFuncs: 'speed,vibration',
          isPrecise: false,
          broadcastPrefix: '77 62 4d 53 45',
        ));
        _pendingToy = null;
      }
      _setState(BleState.connected);
      _log('✅ Handshake OK — ${toyProfile?.name ?? connectedDeviceName} vinculado. Hardware CONFIRMADO.', 'success');
      await _updateNotification('Vinculado (${connectedDevices.length}) → ${toyProfile?.name ?? connectedDeviceName}');

    } catch (e) {
      _log('❌ Error en handshake: $e', 'error');
      connectedDeviceName = '';
      _hardwareConfirmed = false;
      _setState(BleState.idle);
      _showHardwareNotFoundSnackbar();
    }
  }

  /// ── NUEVO: Mostrar Snackbar de hardware no encontrado ──
  void _showHardwareNotFoundSnackbar() {
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'warn');
    _log('⚠️  NO SE DETECTÓ HARDWARE FÍSICO', 'warn');
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'warn');
    _log('La app intentó conectarse pero el dispositivo:', 'warn');
    _log('  • Está apagado o fuera de rango', 'warn');
    _log('  • No está en modo emparejamiento', 'warn');
    _log('  • O fue un falso positivo del escaneo BLE', 'warn');
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'warn');
  }

  Future<void> disconnect() async {
    _stopBurst();
    for (var dev in connectedDevices) {
      await dev.disconnect();
    }
    connectedDevices.clear();
    await _handleDisconnect();
  }

  Future<void> _handleDisconnect() async {
    _heartbeatTimer?.cancel();
    _smoothingTimer?.cancel();
    _stopBurst();
    _batterySub?.cancel();
    characteristic = null;
    activeToy = null; // Limpiar dispositivo virtual
    activeSpeed = null;
    activePattern = null;
    activeIntensity = null;
    batteryLevel = 0;
    _demoMode = false; // <-- APAGAR MODO DEMO AL DESCONECTAR

    // Notificación de desconexión
    _notificationService?.showConnectionLost();

    // ── NUEVO: Resetear confirmación de hardware ──
    _hardwareConfirmed = false;
    _discoveredDeviceName = '';

    _setState(BleState.idle);
    await _updateNotification('Desconectado');
    _log('🔌 Dispositivo desconectado. Hardware no confirmado.', 'info');
  }



  // Para de emergencia: detiene burst+sequencer, bypassa mutex y para el advertising
  BleProtocolType get _activeProtocol {
    if (activeToy != null) return detectBleProtocol(activeToy!);
    return BleProtocolType.classic;
  }

  /// Envía comando de parada de emergencia según protocolo activo
  Future<void> _emergencyStopByProtocol() async {
    final proto = _activeProtocol;
    switch (proto) {
      case BleProtocolType.ipao:
        await writeCommand(ipao.IpaoProtocol.stopAll(), label: 'IPAO_ESTOP');
        break;
      case BleProtocolType.cryptBle:
        final psk = _derivePsk();
        final cmd = CryptBle.encryptCommand(0, 0, psk);
        await writeCommand(cmd, label: 'CRYPT_ESTOP');
        break;
      case BleProtocolType.loveSpouse:
        await writeCommand(LoveSpouseCommands.dualMotor(0, 0), label: 'LOVESPOUSE_ESTOP');
        break;
      case BleProtocolType.classic:
        await writeCommand(LvsCommands.cmdStop, label: 'EMERGENCY_STOP');
        await Future.delayed(const Duration(milliseconds: 120));
        await writeCommand(LvsCommands.ch1Stop, label: 'EMERGENCY_STOP_CH1');
        break;
    }
    // Fallback: escribir a todos los UUIDs BLE conocidos
    if (connectedDevices.isNotEmpty) {
      await _writeGattByUuid(LvsCommands.cmdStop, BleUuids.classicWrite);
      await _writeGattByUuid([0xAA, 1, 0, 0], BleUuids.ipaoWrite);
      if (proto == BleProtocolType.cryptBle) {
        final psk = _derivePsk();
        await _writeGattByUuid(CryptBle.encryptCommand(0, 0, psk), BleUuids.cryptWrite);
      }
      if (proto == BleProtocolType.loveSpouse) {
        await _writeGattByUuid(LoveSpouseCommands.dualMotor(0, 0), LoveSpouseUuids.classicWrite);
      }
    }
  }

  List<int> _derivePsk() {
    // Placeholder: en una implementación real, el seed vendría del scan record
    // almacenado en MMKV/secure storage, y la MAC del dispositivo conectado.
    // Por ahora retornamos un PSK por defecto.
    return [0x01, 0x02, 0x03, 0x04];
  }

  Future<void> emergencyStop() async {
    _stopBurst();
    _stopSequencer();
    activeSpeed = null; activePattern = null; activeIntensity = null;
    activeIntensityCh1 = null; activeIntensityCh2 = null;
    activePatternCh1 = null; activePatternCh2 = null;
    try {
      _isWriting = false;
      _lastPacket = null;
      if (await _peripheral.isAdvertising) {
        await _peripheral.stop();
      }
      await _emergencyStopByProtocol();
    } catch (_) {}
    _log('🛑 PARADA DE EMERGENCIA', 'error');
    _notifyListeners();
  }

  Future<void> stopAllMotors() async {
    _stopBurst();
    _stopSequencer();
    activeSpeed = null; activePattern = null; activeIntensity = null;
    activeIntensityCh1 = null; activeIntensityCh2 = null;
    activePatternCh1 = null; activePatternCh2 = null;
    try {
      _lastPacket = null;
      final proto = _activeProtocol;
      if (proto == BleProtocolType.ipao) {
        await writeCommand(ipao.IpaoProtocol.stopAll(), label: 'IPAO_STOP');
      } else if (proto == BleProtocolType.cryptBle) {
        final psk = _derivePsk();
        final cmd = CryptBle.encryptCommand(0, 0, psk);
        await writeCommand(cmd, label: 'CRYPT_STOP');
      } else if (proto == BleProtocolType.loveSpouse) {
        await writeCommand(LoveSpouseCommands.dualMotor(0, 0), label: 'LOVESPOUSE_STOP');
      } else {
        await writeCommand(LvsCommands.cmdStop, label: 'STOP_MOTORS');
        await Future.delayed(const Duration(milliseconds: 120));
        await writeCommand(LvsCommands.ch1Stop, label: 'STOP_MOTORS_CH1');
        await Future.delayed(const Duration(milliseconds: 100));
        await writeCommand(LvsCommands.dualMotor(0, 0), label: 'STOP_MOTORS_DUAL_SYNC');
      }
    } catch (_) {}
    _log('⏹️ MOTORES DETENIDOS', 'info');
    _notifyListeners();
  }

  // NUEVO: Sincronización Multimedia (Dual Motor 8154)
  // Utiliza el comando F6 para enviar ambos niveles en un solo paquete.
  Future<void> sendMultimediaSync(int ch1Val, int ch2Val) async {
    if (state != BleState.connected) return;

    // Reset de cache para forzar el envío
    _lastPacket = null;

    // Enviar comando dual sincronizado (F6)
    await writeCommand(
      LvsCommands.dualMotor(ch1Val, ch2Val),
      label: 'AI SYNC (F6)',
      silent: false,
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ESCRITURA Y COMANDOS
  // ══════════════════════════════════════════════════════════════

  // 🔒 PERFORMANCE: Cola de comandos para evitar bloqueo UI
  final List<_QueuedCommand> _commandQueue = [];
  bool _isProcessingQueue = false;

  // Mutex para escritura BLE
  bool _isWriting = false;
  List<int>? _lastPacket;

  Future<bool> writeCommand(List<int> cmdBytes, {String label = '', bool silent = false}) async {
    // 🔒 PERFORMANCE: Encolar comando en lugar de ejecutar inmediatamente
    final completer = Completer<bool>();
    _commandQueue.add(_QueuedCommand(cmdBytes, label, silent, completer));

    // Procesar cola si no está activa
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
      final proto = _activeProtocol;
      final rawBytes = cmd.cmdBytes;

      if (!cmd.silent) _log('→ [${cmd.label}] ${LvsCommands.bytesToHex(rawBytes)}', 'cmd');

      if (proto == BleProtocolType.ipao && connectedDevices.isNotEmpty) {
        // IPAO: GATT write directo a 00008ac1-...
        await _writeGattByUuid(rawBytes, BleUuids.ipaoWrite);
        cmd.completer.complete(true);
      } else if (proto == BleProtocolType.cryptBle && connectedDevices.isNotEmpty) {
        // CryptBle: encriptar y escribir a 0000f6c2-...
        final psk = _derivePsk();
        final encrypted = CryptBle.encrypt(rawBytes, psk);
        await _writeGattByUuid(encrypted, BleUuids.cryptWrite);
        cmd.completer.complete(true);
      } else if (proto == BleProtocolType.loveSpouse && connectedDevices.isNotEmpty) {
        // LoveSpouse: GATT write a classicWrite UUID (FFF1)
        List<int> finalBytes = rawBytes;
        
        // ── NUEVO: Conversión a NewCommand si el dispositivo lo soporta ──
        if (activeToy != null && activeToy!.isNewCommand) {
          finalBytes = convertToNewCommand(rawBytes, isDualChannel: activeToy!.hasDualChannel);
          _log('🔄 Comando convertido a NewCommand: ${LvsCommands.bytesToHex(finalBytes)}', 'cmd');
        }
        
        // ── NUEVO: Encriptación XOR si el dispositivo lo requiere ──
        if (activeToy != null && 
            activeToy!.isEncrypt && 
            activeToy!.encryptCommand.isNotEmpty) {
          final key = parseLoveSpouseHexCommand(activeToy!.encryptCommand);
          if (key != null && key.isNotEmpty) {
            finalBytes = List.generate(finalBytes.length, (i) => finalBytes[i] ^ key[i % key.length]);
            _log('🔐 Comando encriptado XOR (key: ${LvsCommands.bytesToHex(key)})', 'cmd');
          }
        }
        
        await _writeGattByUuid(finalBytes, LoveSpouseUuids.classicWrite);
        cmd.completer.complete(true);
      } else {
        // Classic: advertising + GATT a fff0 (comportamiento legacy)
        final packet = LvsCommands.buildPacket(rawBytes, mode: packetMode);

        if (_lastPacket != null && listEquals(_lastPacket, packet)) {
          _isWriting = false;
          cmd.completer.complete(true);
          _processCommandQueue();
          return;
        }
        _lastPacket = packet;

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

        for (var dev in connectedDevices) {
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

        cmd.completer.complete(true);
      }
    } catch (e) {
      if (!cmd.silent) _log('✗ Error: $e', 'error');
      _lastPacket = null;
      cmd.completer.complete(false);
    } finally {
      _isWriting = false;
      _processCommandQueue();
    }
  }

  Future<void> _writeGattByUuid(List<int> data, String targetUuid) async {
    final devicesToTry = connectedDevices.isNotEmpty 
        ? connectedDevices 
        : (isConnected && activeToy != null ? [connectedDevices.last] : []);
    
    for (var dev in devicesToTry) {
      try {
        final services = await dev.discoverServices();
        for (var s in services) {
          final sUuid = s.uuid.toString().toLowerCase();
          if (!sUuid.contains(targetUuid.substring(0, 8))) continue;
          for (var c in s.characteristics) {
            final cUuid = c.uuid.toString().toLowerCase();
            if (cUuid == targetUuid.toLowerCase() &&
                (c.properties.write || c.properties.writeWithoutResponse)) {
              await c.write(data, withoutResponse: !c.properties.write);
              _log('✅ Emergency STOP escrito a $cUuid', 'success');
              return;
            }
          }
        }
      } catch (e) {
        _log('⚠️ Error escribiendo a GATT: $e', 'warn');
      }
    }
    _log('❌ No se pudo escribir comando de emergencia', 'error');
  }

  Future<void> selectSpeed(SpeedLevel level) async {
    if (activeSpeed == level) {
      await stopAllMotors();
      return;
    }
    _stopSequencer();
    activeSpeed = level;
    activePattern = null;
    activeIntensity = null;
    activeIntensityCh1 = null;
    activeIntensityCh2 = null;
    activePatternCh1 = null;
    activePatternCh2 = null;
    final cmd = LvsCommands.commandFor(level);
    _startBurst(cmd, level.name);
    _notifyListeners();
  }

  Future<void> selectPattern(LvsPattern pattern) async {
    if (activePattern == pattern) {
      await stopAllMotors();
      return;
    }
    _stopSequencer();
    activePattern = pattern;
    activeSpeed = null;
    activeIntensity = null;
    activeIntensityCh1 = null;
    activeIntensityCh2 = null;
    activePatternCh1 = null;
    activePatternCh2 = null;
    final cmd = LvsCommands.patternFor(pattern);
    _startBurst(cmd, pattern.name.toUpperCase());
    _notifyListeners();
  }

  Future<void> setProportionalIntensity(int intensity) async {
    if (isCooldownActive) return;
    final capped = (intensity * stealthIntensityCap).round();
    
    // Toggle: if intensity is high and we set same intensity again, maybe stay? 
    // Actually for sliders/intensity it's better to just set it.
    // But if we explicitly set 0, use emergency stop.
    
    if (activeIntensity == capped && activeSpeed == null && activePattern == null && capped > 0) return;
    
    _stopSequencer();
    activeIntensity = capped;
    activeIntensityCh1 = null; activeIntensityCh2 = null;
    activeSpeed = null; activePattern = null;
    activePatternCh1 = null; activePatternCh2 = null;
    
    if (capped == 0) {
      await stopAllMotors();
    } else {
      final cmd = LvsCommands.proportional(capped);
      _startBurst(cmd, 'LVL:$capped');
    }
    _notifyListeners();
  }

  Future<void> setProportionalChannel1(int intensity) async {
    if (isCooldownActive) return;
    _stopSequencer();
    final capped = (intensity * stealthIntensityCap).round();
    activeIntensityCh1 = capped;
    activeIntensity = null; activeIntensityCh2 = null;
    activeSpeed = null; activePattern = null; activePatternCh1 = null;
    _notifyListeners();
    if (capped == 0) {
      _startBurst(LvsCommands.ch1Stop, 'CH1:STOP');
    } else {
      final cmd = LvsCommands.proportionalChannel1(capped);
      _startBurst(cmd, 'CH1:$capped');
    }
  }

  Future<void> setProportionalChannel2(int intensity) async {
    if (isCooldownActive) return;
    _stopSequencer();
    final capped = (intensity * stealthIntensityCap).round();
    activeIntensityCh2 = capped;
    activeIntensity = null; activeIntensityCh1 = null;
    activeSpeed = null; activePattern = null; activePatternCh2 = null;
    _notifyListeners();
    if (capped == 0) {
      _startBurst(LvsCommands.cmdStop, 'CH2:STOP');
    } else {
      final cmd = LvsCommands.proportionalChannel2(capped);
      _startBurst(cmd, 'CH2:$capped');
    }
  }

  Future<void> setPatternChannel2(int p) async {
    if (isCooldownActive) return;
    if (activePatternCh2 == p && p != 0) {
      await stopAllMotors();
      return;
    }
    _stopSequencer();
    activePatternCh2 = (p == 0) ? null : p;
    activeIntensityCh2 = null;
    activeIntensity = null;
    activePattern = null;
    activeSpeed = null;
    activePatternCh1 = null; // Unificar estado: si cambiamos canal, limpiamos otros modos
    _notifyListeners();
    if (p == 0) {
      _startBurst(LvsCommands.cmdStop, 'CH2:STOP');
    } else {
      final cmd = LvsCommands.ch2PatternFor(p);
      _startBurst(cmd, 'CH2:PAT$p');
    }
  }

  Future<void> setPatternChannel1(int p) async {
    if (isCooldownActive) return;
    if (activePatternCh1 == p && p != 0) {
      await stopAllMotors();
      return;
    }
    _stopSequencer();
    activePatternCh1 = (p == 0) ? null : p;
    activeIntensityCh1 = null; 
    activeIntensity = null;
    activePattern = null; 
    activeSpeed = null;
    activePatternCh2 = null;
    _notifyListeners();
    if (p == 0) {
      _startBurst(LvsCommands.ch1Stop, 'CH1:STOP');
    } else {
      final cmd = LvsCommands.ch1PatternFor(p);
      _startBurst(cmd, 'CH1:PAT$p');
    }
  }

  void playWaveChannel1(WaveType type, {int max = 100}) {
    if (isCooldownActive) return;
    _stopBurst();
    activeIntensityCh1 = null; activeIntensity = null; activeSpeed = null; activePattern = null;
    activeWaveCh1 = type;
    waveMaxIntensityCh1 = max;
    _startSequencer();
    _notifyListeners();
  }

  void playWaveChannel2(WaveType type, {int max = 100}) {
    if (isCooldownActive) return;
    _stopBurst();
    activeIntensityCh2 = null; activeIntensity = null; activeSpeed = null; activePattern = null;
    activeWaveCh2 = type;
    waveMaxIntensityCh2 = max;
    _startSequencer();
    _notifyListeners();
  }

  void _startSequencer() {
    if (_sequenceTimer != null && _sequenceTimer!.isActive) return;
    _sequenceTick = 0;
    _sequenceTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _sequenceTick++;
      _processSequencerTick();
    });
  }

  void _stopSequencer() {
    _sequenceTimer?.cancel();
    _sequenceTimer = null;
    activeWaveCh1 = WaveType.none;
    activeWaveCh2 = WaveType.none;
  }

  void _processSequencerTick() {
    var ch1Active = activeWaveCh1 != WaveType.none;
    var ch2Active = activeWaveCh2 != WaveType.none;

    if (!ch1Active && !ch2Active) {
      _stopSequencer();
      return;
    }

    var val1 = ch1Active ? _evaluateWave(activeWaveCh1, _sequenceTick, waveMaxIntensityCh1) : 0;
    var val2 = ch2Active ? _evaluateWave(activeWaveCh2, _sequenceTick, waveMaxIntensityCh2) : 0;

    if (ch1Active && ch2Active) {
      if (_isCh1Turn) {
        final c1 = val1 > 0 ? LvsCommands.proportionalChannel1(val1) : LvsCommands.ch1Stop;
        writeCommand(c1, label: 'SQ CH1:$val1', silent: true);
        activeIntensityCh1 = val1;
      } else {
        final c2 = val2 > 0 ? LvsCommands.proportionalChannel2(val2) : LvsCommands.cmdStop;
        writeCommand(c2, label: 'SQ CH2:$val2', silent: true);
        activeIntensityCh2 = val2;
      }
      _isCh1Turn = !_isCh1Turn;
    } else if (ch1Active) {
      final c1 = val1 > 0 ? LvsCommands.proportionalChannel1(val1) : LvsCommands.ch1Stop;
      writeCommand(c1, label: 'SQ CH1:$val1', silent: true);
      activeIntensityCh1 = val1;
    } else if (ch2Active) {
      final c2 = val2 > 0 ? LvsCommands.proportionalChannel2(val2) : LvsCommands.cmdStop;
      writeCommand(c2, label: 'SQ CH2:$val2', silent: true);
      activeIntensityCh2 = val2;
    }

    _notifyListeners();
  }

  int _evaluateWave(WaveType type, int tick, int maxIntensity) {
    if (maxIntensity <= 0) return 0;
    switch (type) {
      case WaveType.none: return 0;
      case WaveType.pulse:
        return (tick % 10 < 5) ? maxIntensity : 0;
      case WaveType.wave:
        final sinVal = (math.sin(tick * 0.4) + 1) / 2;
        return (sinVal * maxIntensity).toInt();
      case WaveType.ramp:
        return ((tick % 20) / 20 * maxIntensity).toInt();
      case WaveType.storm:
        return (maxIntensity * 0.3 + math.Random().nextInt((maxIntensity * 0.7).toInt())).toInt();
    }
  }

  Future<void> writeDebugCommand(int b0, int b1, int b2, {bool silent = false}) async {
    final cmd = [b0, b1, b2];
    await writeCommand(cmd, label: 'DBG:${LvsCommands.bytesToHex(cmd)}', silent: silent);
  }

  void clearLogs() {
    _logs.clear();
    _notifyListeners();
  }

  void _startBurst(List<int> cmdBytes, String label) {
    _stopBurst();
    isBurstActive = true;
    _notifyListeners();
    _burstTimer = Timer.periodic(Duration(milliseconds: burstIntervalMs), (_) {
      writeCommand(cmdBytes, label: '$label ♻', silent: true);
    });
  }

  void _stopBurst() {
    _burstTimer?.cancel();
    _burstTimer = null;
    isBurstActive = false;
  }

  void setBurstInterval(int ms) {
    burstIntervalMs = ms;
    _notifyListeners();
    if (isBurstActive) {
      List<int>? cmd;
      var label = '';
      if (activeSpeed != null) { cmd = LvsCommands.commandFor(activeSpeed!); label = activeSpeed!.name; }
      else if (activePattern != null) { cmd = LvsCommands.patternFor(activePattern!); label = activePattern!.name; }
      else if (activeIntensity != null) { cmd = LvsCommands.proportional(activeIntensity!); label = 'INT:$activeIntensity%'; }
      if (cmd != null) _startBurst(cmd, label);
    }
  }

  void toggleDeepScan() {
    isDeepScan = !isDeepScan;
    _notifyListeners();
    _log('Deep Scan: ${isDeepScan ? "ON" : "OFF"}', 'info');
  }

  void setPacketMode(PacketMode mode) {
    packetMode = mode;
    _log('Modo paquete: ${mode.name}', 'info');
    _notifyListeners();
  }

  void _log(String msg, String type) {
    _logs.add(BleLogEntry(DateTime.now(), msg, type));
    if (_logs.length > 150) {
      _logs.removeRange(0, 50);
    }
    _notifyListeners();
  }

  void _setState(BleState s) {
    state = s;
    _notifyListeners();
  }

  // ── MÉTODOS RECUPERADOS ──────────────────────────────────
  void toggleDemoMode() {
    _demoMode = !_demoMode;
    if (_demoMode) {
      _log('🧪 Demo mode activado', 'info');
      final dummyToy = ToyModel(
        id: 'DEMO-8154',
        name: 'Knight No. 3 (Demo)',
        usageType: 'Ambos',
        targetAnatomy: 'Múltiple',
        stimulationType: 'Vibración',
        motorLogic: 'Dual (Canal A y B)',
        imageUrl: 'https://i.ibb.co/L9Nn4wH/toy-placeholder.png',
        qrCodeUrl: '',
        supportedFuncs: 'Gamificación, Sync',
        isPrecise: true,
        broadcastPrefix: 'wbMSE',
        bleProtocol: BleProtocolType.classic,
      );
      setActiveToy(dummyToy);
    } else {
      _log('🧪 Demo mode desactivado', 'info');
      if (!_hardwareConfirmed) {
        disconnect();
      }
    }
    _notifyListeners();
  }

  void toggleBridgeMode() {
    isBridgeModeActive = !isBridgeModeActive;
    _log('🌉 Bridge mode: ${isBridgeModeActive ? "ON" : "OFF"}', 'info');
    _notifyListeners();
  }

  Future<void> initSecurity() async {
    _log('🔒 Seguridad inicializada', 'info');
  }

  Future<bool> toggleTravelLock(String pin) async {
    isTravelLockActive = !isTravelLockActive;
    _log('🔒 Travel Lock: ${isTravelLockActive ? "ACTIVO" : "INACTIVO"}', 'info');
    _notifyListeners();
    return true;
  }

  /// Lee el Device Name (0x2A00) del Generic Access service (0x1800) vía GATT
  Future<String?> _readDeviceName(BluetoothDevice dev) async {
    try {
      final services = await dev.discoverServices();
      for (final s in services) {
        if (!s.uuid.toString().toLowerCase().startsWith('00001800')) continue;
        for (final c in s.characteristics) {
          if (c.uuid.toString().toLowerCase().startsWith('00002a00') && c.properties.read) {
            final value = await c.read();
            if (value.isNotEmpty) {
              return String.fromCharCodes(value).trim();
            }
          }
        }
      }
    } catch (e) {
      _log('⚠️ No se pudo leer Device Name GATT: $e', 'warn');
    }
    return null;
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _sequenceTimer?.cancel();
    _burstTimer?.cancel();
    _stopBurst();
    _connSub?.cancel();
    _batterySub?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // LOVE SPOUSE - Controles Especiales (Heating, Strike, Suction)
  // ═══════════════════════════════════════════════════════════════

  // Heating
  bool _heatingActive = false;
  int _heatingLevel = 0;
  bool get heatingActive => _heatingActive;
  int get heatingLevel => _heatingLevel;

  Future<void> setHeating(bool on) async {
    if (on == _heatingActive) return;
    _heatingActive = on;
    if (on) {
      await writeCommand(LoveSpouseCommands.heatingOn, label: 'HEATING_ON');
    } else {
      await writeCommand(LoveSpouseCommands.heatingOff, label: 'HEATING_OFF');
    }
    _notifyListeners();
  }

  Future<void> setHeatingLevel(int level) async {
    final clamped = level.clamp(0, 255);
    _heatingLevel = clamped;
    await writeCommand(LoveSpouseCommands.heatingLevel(clamped), label: 'HEATING_LVL:$clamped');
    _notifyListeners();
  }

  // Strike
  int _strikeIndex = -1;
  int get strikeIndex => _strikeIndex;

  Future<void> setStrike(int index) async {
    final clamped = index.clamp(0, 8);
    _strikeIndex = clamped;
    await writeCommand(LoveSpouseCommands.strikePattern(clamped), label: 'STRIKE_PAT:$clamped');
    _notifyListeners();
  }

  Future<void> stopStrike() async {
    _strikeIndex = -1;
    await writeCommand(LoveSpouseCommands.strikeOff, label: 'STRIKE_OFF');
    _notifyListeners();
  }

  // Suction
  bool _suctionActive = false;
  int _suctionLevel = 0;
  bool get suctionActive => _suctionActive;
  int get suctionLevel => _suctionLevel;

  Future<void> setSuction(bool on) async {
    if (on == _suctionActive) return;
    _suctionActive = on;
    if (on) {
      await writeCommand(LoveSpouseCommands.suctionOn, label: 'SUCTION_ON');
    } else {
      await writeCommand(LoveSpouseCommands.suctionOff, label: 'SUCTION_OFF');
    }
    _notifyListeners();
  }

  Future<void> setSuctionLevel(int level) async {
    final clamped = level.clamp(0, 255);
    _suctionLevel = clamped;
    await writeCommand(LoveSpouseCommands.suctionLevel(clamped), label: 'SUCTION_LVL:$clamped');
    _notifyListeners();
  }

  // Pattern Channel 1 & 2 (LoveSpouse specific)
  Future<void> setDevicePatternCh1(PatternButton button, int index) async {
    if (_activeProtocol != BleProtocolType.loveSpouse) return;
    // Para LoveSpouse, usamos los comandos de patrón CH1 (prefijo 0xD)
    final patterns = [
      LoveSpouseCommands.ch1Pat1, LoveSpouseCommands.ch1Pat2, LoveSpouseCommands.ch1Pat3,
      LoveSpouseCommands.ch1Pat4, LoveSpouseCommands.ch1Pat5, LoveSpouseCommands.ch1Pat6,
      LoveSpouseCommands.ch1Pat7, LoveSpouseCommands.ch1Pat8, LoveSpouseCommands.ch1Pat9,
    ];
    if (index >= 0 && index < patterns.length) {
      activePatternCh1 = index + 1;
      await writeCommand(patterns[index], label: 'CH1_PAT${index + 1}');
      _notifyListeners();
    }
  }

  Future<void> setDevicePatternCh2(PatternButton button, int index) async {
    if (_activeProtocol != BleProtocolType.loveSpouse) return;
    // Para LoveSpouse multimedia (8154), usamos prefijo 0xA
    final patterns = [
      LoveSpouseCommands.ch2Pat1Mm, LoveSpouseCommands.ch2Pat2Mm, LoveSpouseCommands.ch2Pat3Mm,
      LoveSpouseCommands.ch2Pat4Mm, LoveSpouseCommands.ch2Pat5Mm, LoveSpouseCommands.ch2Pat6Mm,
      LoveSpouseCommands.ch2Pat7Mm, LoveSpouseCommands.ch2Pat8Mm, LoveSpouseCommands.ch2Pat9Mm,
    ];
    if (index >= 0 && index < patterns.length) {
      activePatternCh2 = index + 1;
      await writeCommand(patterns[index], label: 'CH2_PAT${index + 1}');
      _notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // LOVE SPOUSE - Notificaciones GATT (Telemetría: Batería 0x8A, Kegel 0x8B)
  // ═══════════════════════════════════════════════════════════════

  Future<void> _setupLoveSpouseNotifications(BluetoothDevice dev) async {
    try {
      final services = await dev.discoverServices();
      for (final service in services) {
        final sUuid = service.uuid.toString().toLowerCase();
        if (!sUuid.contains('fff0')) continue;
        
        for (final characteristic in service.characteristics) {
          final cUuid = characteristic.uuid.toString().toLowerCase();
          // Buscar característica de notificación (FFF1 o FFF3)
          if ((cUuid.contains('fff1') || cUuid.contains('fff3')) && characteristic.properties.notify) {
            _log('🔔 Configurando notificaciones LoveSpouse en $cUuid', 'success');
            
            // Suscribirse a notificaciones
            await characteristic.setNotifyValue(true);
            
            _batterySub?.cancel();
            _batterySub = characteristic.onValueReceived.listen((value) {
              _handleLoveSpouseNotification(value);
            });
            
            // Solicitar batería inicial
            await Future.delayed(const Duration(milliseconds: 200));
            await writeCommand([LoveSpouseCommands.telemetryBatteryCmd, 0x00, 0x00], 
                label: 'BATTERY_REQUEST', silent: true);
            break;
          }
        }
      }
    } catch (e) {
      _log('⚠️ Error configurando notificaciones LoveSpouse: $e', 'warn');
    }
  }

  void _handleLoveSpouseNotification(List<int> bytes) {
    if (bytes.isEmpty) return;
    
    final parsed = LoveSpouseCommands.parseTelemetry(bytes);
    if (parsed != null) {
      _log('📊 Telemetría LoveSpouse: ${parsed['type']} = $parsed', 'info');
      
      if (parsed['type'] == 'battery') {
        batteryLevel = parsed['level'] as int;
        // TODO: manejar charging state si se necesita
        _notifyListeners();
      } else if (parsed['type'] == 'kegel') {
        // TODO: emitir evento o actualizar estado para Kegel
        _log('🎯 Kegel: pressure=${parsed['pressure']}, reps=${parsed['reps']}', 'info');
      }
    }
  }
}

void startCallback() {}
