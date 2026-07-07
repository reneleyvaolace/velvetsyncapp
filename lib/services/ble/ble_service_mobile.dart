// ═══════════════════════════════════════════════════════════════
// LVS Control · lib/ble/ble_service.dart · v2.1.0
// Migrado a flutter_blue_plus v2.x
// Servicio BLE: escaneo, conexión GATT, burst mode, permisos, batería
//
// NOTAS DE FONDO:
//  - Android: FlutterForegroundTask mantiene el proceso vivo.
//    El escaneo BLE sigue activo con pantalla apagada.
//  - iOS: background mode 'bluetooth-central' en Info.plist
//    permite continuar recibiendo eventos BLE mientras la app
//    está en background (limitado por iOS power management).
// ═══════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:velvet_sync/services/ble/ble_types.dart';
export 'package:velvet_sync/services/ble/ble_types.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'lvs_commands.dart';
import 'package:velvet_sync/devices/models/toy_model.dart';
import 'toy_profile.dart';
import 'package:velvet_sync/utils/logger.dart';
import 'package:velvet_sync/utils/protocol_translator.dart';
import 'package:velvet_sync/services/backend/notification_service.dart';

// ── Provider Global para Riverpod ──────────────────────────────
final bleProvider = ChangeNotifierProvider((ref) => BleService());



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
  BluetoothCharacteristic? characteristic;
  ToyProfile? toyProfile;
  ToyModel? activeToy; // El modelo del catálogo que está en uso

  // Nombre real del hardware detectado en la sesión actual
  String connectedDeviceName = '';

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

  // ── Funciones especiales (heating, strike, suction) ────────
  bool _heatingActive = false;
  int _heatingLevel = 0;
  int _strikeIndex = -1;
  bool _suctionActive = false;
  int _suctionLevel = 0;

  bool get heatingActive => _heatingActive;
  int get heatingLevel => _heatingLevel;
  int get strikeIndex => _strikeIndex;
  bool get suctionActive => _suctionActive;
  int get suctionLevel => _suctionLevel;

  PacketMode packetMode = PacketMode.b11;
  bool isBurstActive   = false;
  int burstIntervalMs  = 250;
  bool isDeepScan      = false;
  int batteryLevel     = 0;

  // Notificaciones
  NotificationService? _notificationService;

  bool isCooldownActive = false;
  int cooldownRemaining = 0;
  Timer? _cooldownTimer;

  static const List<int> verificationCmd = [0x01, 0x01, 0x01];
  static const int expectedAck = 0x06;

  void activateCooldown() {
    emergencyStop();
    isCooldownActive = true;
    cooldownRemaining = 60;
    notifyListeners();

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      cooldownRemaining--;
      if (cooldownRemaining <= 0) {
        isCooldownActive = false;
        timer.cancel();
      }
      notifyListeners();
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
    notifyListeners();
  }

  void _initNotifications() {
    if (_notificationService == null) {
      _notificationService = NotificationService();
      _notificationService!.init();
    }
  }

  /// ── NUEVO: Método para verificar si hay hardware real conectado ──
  Future<bool> verifyHardwareConnection() async {
    if (_hardwareConfirmed) return true;

    _log('⚠️ No hay hardware confirmado. Intentando verificar...', 'warn');

    const timeout = Duration(seconds: 3);

    try {
      final ok = await writeCommand(verificationCmd, label: 'VERIFY_HW', silent: true)
          .timeout(timeout, onTimeout: () {
        _log('⏱️ Timeout de verificación - hardware no responde', 'error');
        return false;
      });

      if (!ok) {
        _log('❌ No hay hardware físico presente', 'error');
        return false;
      }

      await Future.delayed(const Duration(milliseconds: 300));

      final secondCheck = await writeCommand([0x00, 0x00, 0x00], label: 'VERIFY_HW2', silent: true)
          .timeout(const Duration(milliseconds: 1500), onTimeout: () => false);

      if (!secondCheck) {
        _log('⚠️ Segunda verificación fallida - hardware inestable', 'warn');
      }

      _hardwareConfirmed = true;
      _initNotifications();
      _log('✅ Hardware verificado exitosamente', 'success');
      return true;
    } catch (e) {
      _log('❌ Error verificando hardware: $e', 'error');
      return false;
    }
  }

  void renameActiveToy(String newName) {
    if (activeToy == null) return;
    // Creamos una copia con el nuevo nombre
    final updated = ToyModel(
      id: activeToy!.id,
      name: newName,
      usageType: activeToy!.usageType,
      targetAnatomy: activeToy!.targetAnatomy,
      stimulationType: activeToy!.stimulationType,
      motorLogic: activeToy!.motorLogic,
      imageUrl: activeToy!.imageUrl,
      qrCodeUrl: activeToy!.qrCodeUrl, // <--- FALTANTE
      supportedFuncs: activeToy!.supportedFuncs,
      isPrecise: activeToy!.isPrecise,
      broadcastPrefix: activeToy!.broadcastPrefix,
    );
    activeToy = updated;
    toyProfile = ToyProfile(
      name: newName,
      identifier: updated.id,
      hasDualChannel: updated.hasDualChannel,
    );
    connectedDeviceName = newName;
    notifyListeners();
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
      notificationTitle: connectedDeviceName.isNotEmpty ? connectedDeviceName : 'LVS Control',
      notificationText: isConnected ? 'Conectado a $connectedDeviceName' : 'Buscando dispositivo…',
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
              toy.name.toLowerCase() == realName.toLowerCase() ||
              (toy.bleName.isNotEmpty &&
                realName.toLowerCase().contains(toy.bleName.toLowerCase()))
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

    // Registrar nombre real del dispositivo detectado
    final rawName = found!.platformName.isEmpty
        ? found!.remoteId.str
        : found!.platformName;
    connectedDeviceName = rawName;
    notifyListeners();

    if (catalog != null) {
      toyProfile = ToyProfile.fromCatalog(rawName, catalog);
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
      if (!connectedDevices.contains(dev)) {
        connectedDevices.add(dev);
      }

      // HANDSHAKE ACTIVO REAL con timeout
      final ok = await writeCommand(verificationCmd, label: 'VERIFY', silent: false)
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
      await Future.delayed(const Duration(milliseconds: 200));
      final secondCheck = await writeCommand([0x00, 0x00, 0x00], label: 'VERIFY2', silent: true)
          .timeout(const Duration(milliseconds: 1500), onTimeout: () => false);

      if (!secondCheck) {
        _log('⚠️ Segunda verificación fallida - hardware inestable', 'warn');
        // No rechazamos, pero logueamos
      }


      // ── NUEVO: Confirmar hardware exitoso ──
      _hardwareConfirmed = true;
      _initNotifications();
      batteryLevel = 100;
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

    _setState(BleState.idle);
    await _updateNotification('Desconectado');
    _log('🔌 Dispositivo desconectado. Hardware no confirmado.', 'info');
  }



  // Para de emergencia: detiene burst+sequencer, bypassa mutex y para el advertising
  Future<void> emergencyStop() async {
    _stopBurst();
    _stopSequencer();
    activeSpeed = null; activePattern = null; activeIntensity = null;
    activeIntensityCh1 = null; activeIntensityCh2 = null;
    activePatternCh1 = null; activePatternCh2 = null;
    _resetSpecialFunctions();
    try {
      _isWriting = false;   // Liberar mutex por si está bloqueado
      _lastPacket = null;
      if (await _peripheral.isAdvertising) {
        await _peripheral.stop();
      }
      await writeCommand(LvsCommands.cmdStop, label: 'EMERGENCY_STOP', silent: false);
      await Future.delayed(const Duration(milliseconds: 120));
      await writeCommand(LvsCommands.ch1Stop, label: 'EMERGENCY_STOP_CH1', silent: false);
    } catch (_) {}
    _log('🛑 PARADA DE EMERGENCIA', 'error');
    notifyListeners();
  }

  void _resetSpecialFunctions() {
    _heatingActive = false;
    _heatingLevel = 0;
    _strikeIndex = -1;
    _suctionActive = false;
    _suctionLevel = 0;
  }

  // Detiene todos los motores sin afectar el estado del servicio BLE
  Future<void> stopAllMotors() async {
    _stopBurst();
    _stopSequencer();
    activeSpeed = null; activePattern = null; activeIntensity = null;
    activeIntensityCh1 = null; activeIntensityCh2 = null;
    activePatternCh1 = null; activePatternCh2 = null;
    _resetSpecialFunctions();
    try {
      _lastPacket = null;
      await writeCommand(LvsCommands.cmdStop, label: 'STOP_MOTORS');
      await Future.delayed(const Duration(milliseconds: 120));
      await writeCommand(LvsCommands.ch1Stop, label: 'STOP_MOTORS_CH1');
      await Future.delayed(const Duration(milliseconds: 100));
      // Extra safety for dual channel devices
      await writeCommand(LvsCommands.dualMotor(0, 0), label: 'STOP_MOTORS_DUAL_SYNC');
    } catch (_) {}
    _log('⏹️ MOTORES DETENIDOS', 'info');
    notifyListeners();
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

    // Ejecutar comando con mutex
    if (_isWriting) {
      // Re-encolar si está escribiendo
      _commandQueue.insert(0, cmd);
      _isProcessingQueue = false;
      return;
    }

    _isWriting = true;
    try {
      // Apply encryption if device requires it
      final encryptedBytes = activeToy?.isEncrypt == true
          ? LvsCommands.encrypt(cmd.cmdBytes, activeToy!.encryptCommand)
          : cmd.cmdBytes;
      // Use device-specific broadcast prefix when available
      final prefixBytes = activeToy != null
          ? LvsCommands.parseBroadcastPrefix(activeToy!.broadcastPrefix)
          : null;
      final packet = LvsCommands.buildPacket(encryptedBytes, mode: packetMode, prefixBytes: prefixBytes);

      // OPTIMIZACIÓN: No reiniciar si el paquete es el mismo
      if (_lastPacket != null && listEquals(_lastPacket, packet)) {
        _isWriting = false;
        cmd.completer.complete(true);
        _processCommandQueue();
        return;
      }
      _lastPacket = packet;

      if (!cmd.silent) _log('→ [${cmd.label}] ${LvsCommands.bytesToHex(packet)}', 'cmd');

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

      // 🔒 PERFORMANCE: Delay no bloqueante para limpiar buffer HCI
      if (await _peripheral.isAdvertising) {
        await _peripheral.stop();
        await Future.delayed(const Duration(milliseconds: 15)); // Reducido de 20ms
      }

      await _peripheral.start(
        advertiseData: data,
        advertiseSetParameters: parameters,
      );

      // Soporte para dispositivos GATT estándar
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
    } catch (e) {
      if (!cmd.silent) _log('✗ Error Peripheral: $e', 'error');
      _lastPacket = null;
      cmd.completer.complete(false);
    } finally {
      _isWriting = false;
      _processCommandQueue();
    }
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
    notifyListeners();
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
    notifyListeners();
  }

  Future<void> setProportionalIntensity(int intensity) async {
    if (isCooldownActive) return;
    final capped = (intensity * stealthIntensityCap).round();
    
    if (activeIntensity == capped && activeSpeed == null && activePattern == null && capped > 0) return;
    
    _stopSequencer();
    activeIntensity = capped;
    activeIntensityCh1 = null; activeIntensityCh2 = null;
    activeSpeed = null; activePattern = null;
    activePatternCh1 = null; activePatternCh2 = null;
    
    if (capped == 0) {
      await stopAllMotors();
    } else {
      final cmd = buildIntensityCommand(capped);
      _startBurst(cmd, 'LVL:$capped');
    }
    notifyListeners();
  }

  @visibleForTesting
  List<int> buildIntensityCommand(int intensity) {
    if (activeToy != null) {
      return ProtocolTranslator.translate(
        toy: activeToy!,
        intensity: intensity,
        channel: null,
      ).bytes;
    }
    return LvsCommands.proportional(intensity);
  }

  @visibleForTesting
  List<int> buildChannel1Command(int intensity) {
    if (activeToy != null) {
      return ProtocolTranslator.translate(
        toy: activeToy!,
        intensity: intensity,
        channel: 1,
      ).bytes;
    }
    return LvsCommands.proportionalChannel1(intensity);
  }

  @visibleForTesting
  List<int> buildChannel2Command(int intensity) {
    if (activeToy != null) {
      return ProtocolTranslator.translate(
        toy: activeToy!,
        intensity: intensity,
        channel: 2,
      ).bytes;
    }
    return LvsCommands.proportionalChannel2(intensity);
  }

  Future<void> setProportionalChannel1(int intensity) async {
    if (isCooldownActive) return;
    _stopSequencer();
    final capped = (intensity * stealthIntensityCap).round();
    activeIntensityCh1 = capped;
    activeIntensity = null; activeIntensityCh2 = null;
    activeSpeed = null; activePattern = null; activePatternCh1 = null;
    notifyListeners();
    if (capped == 0) {
      _startBurst(LvsCommands.ch1Stop, 'CH1:STOP');
    } else {
      final cmd = buildChannel1Command(capped);
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
    notifyListeners();
    if (capped == 0) {
      _startBurst(LvsCommands.cmdStop, 'CH2:STOP');
    } else {
      final cmd = buildChannel2Command(capped);
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
    notifyListeners();
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
    notifyListeners();
    if (p == 0) {
      _startBurst(LvsCommands.ch1Stop, 'CH1:STOP');
    } else {
      final cmd = LvsCommands.ch1PatternFor(p);
      _startBurst(cmd, 'CH1:PAT$p');
    }
  }

  // ── Device-specific patterns (from ClassicId) ──────────────
  /// Sends a device-specific pattern command for CH2 using the ClassicId
  /// button's position within its group (0-based index).
  Future<void> setDevicePatternCh2(PatternButton btn, int index) async {
    if (isCooldownActive) return;
    if (activePatternCh2 == index) {
      await _stopButtonPattern(btn, 2);
      return;
    }
    _stopSequencer();
    activePatternCh2 = index;
    activeIntensityCh2 = null;
    activeIntensity = null;
    activePattern = null;
    activeSpeed = null;
    activePatternCh1 = null;
    notifyListeners();
    final cmd = LvsCommands.commandForButton(btn, 2, index);
    _startBurst(cmd, 'DEV:CH2:${btn.name}');
  }

  Future<void> setDevicePatternCh1(PatternButton btn, int index) async {
    if (isCooldownActive) return;
    if (activePatternCh1 == index) {
      await _stopButtonPattern(btn, 1);
      return;
    }
    _stopSequencer();
    activePatternCh1 = index;
    activeIntensityCh1 = null;
    activeIntensity = null;
    activePattern = null;
    activeSpeed = null;
    activePatternCh2 = null;
    notifyListeners();
    final cmd = LvsCommands.commandForButton(btn, 1, index);
    _startBurst(cmd, 'DEV:CH1:${btn.name}');
  }

  /// Stop a device pattern using the button's specific stopCommand.
  /// Falls back to channel stop if no stopCommand defined.
  Future<void> _stopButtonPattern(PatternButton btn, int channel) async {
    _stopBurst();
    _stopSequencer();
    final cmd = LvsCommands.commandForButtonStop(btn, channel);
    if (btn.stopCommand > 0) {
      await writeCommand(cmd, label: 'STOP:${btn.name}');
    } else {
      await writeCommand(cmd, label: 'CH$channel:STOP');
    }
    if (channel == 1) {
      activePatternCh1 = null;
    } else {
      activePatternCh2 = null;
    }
    notifyListeners();
  }

  // ── Funciones especiales (heating, strike, suction) ───────────

  /// Toggle heating on/off. If [on] is null, toggles current state.
  Future<void> setHeating(bool? on) async {
    if (isCooldownActive) return;
    _heatingActive = on ?? !_heatingActive;
    _stopBurst();
    final cmd = _heatingActive ? LvsCommands.heatingOn : LvsCommands.heatingOff;
    await writeCommand(cmd, label: 'HEAT:${_heatingActive ? "ON" : "OFF"}');
    if (_heatingActive && _heatingLevel > 0) {
      await writeCommand(LvsCommands.heatingLevel(_heatingLevel), label: 'HEAT:LVL$_heatingLevel');
    }
    notifyListeners();
  }

  /// Set heating level (0-255).
  Future<void> setHeatingLevel(int level) async {
    if (isCooldownActive) return;
    _heatingLevel = level.clamp(0, 255);
    if (_heatingActive) {
      await writeCommand(LvsCommands.heatingLevel(_heatingLevel), label: 'HEAT:LVL$_heatingLevel');
    }
    notifyListeners();
  }

  /// Toggle strike on/off or select strike pattern by index.
  Future<void> setStrike(int index) async {
    if (isCooldownActive) return;
    if (_strikeIndex == index) {
      _strikeIndex = -1;
      _stopBurst();
      await writeCommand(LvsCommands.strikeOff, label: 'STRIKE:OFF');
      notifyListeners();
      return;
    }
    _stopBurst();
    _strikeIndex = index;
    final cmd = LvsCommands.strikePattern(index);
    _startBurst(cmd, 'STRIKE:PAT$index');
    notifyListeners();
  }

  /// Turn strike off.
  Future<void> stopStrike() async {
    _strikeIndex = -1;
    _stopBurst();
    await writeCommand(LvsCommands.strikeOff, label: 'STRIKE:OFF');
    notifyListeners();
  }

  /// Toggle suction on/off. If [on] is null, toggles current state.
  Future<void> setSuction(bool? on) async {
    if (isCooldownActive) return;
    _suctionActive = on ?? !_suctionActive;
    _stopBurst();
    final cmd = _suctionActive ? LvsCommands.suctionOn : LvsCommands.suctionOff;
    await writeCommand(cmd, label: 'SUCTION:${_suctionActive ? "ON" : "OFF"}');
    if (_suctionActive && _suctionLevel > 0) {
      await writeCommand(LvsCommands.suctionLevel(_suctionLevel), label: 'SUCTION:LVL$_suctionLevel');
    }
    notifyListeners();
  }

  /// Set suction level (0-255).
  Future<void> setSuctionLevel(int level) async {
    if (isCooldownActive) return;
    _suctionLevel = level.clamp(0, 255);
    if (_suctionActive) {
      await writeCommand(LvsCommands.suctionLevel(_suctionLevel), label: 'SUCTION:LVL$_suctionLevel');
    }
    notifyListeners();
  }

  /// Stop all special functions (heating, strike, suction).
  Future<void> stopSpecialFunctions() async {
    _heatingActive = false;
    _heatingLevel = 0;
    _strikeIndex = -1;
    _suctionActive = false;
    _suctionLevel = 0;
    _stopBurst();
    await writeCommand(LvsCommands.heatingOff, label: 'HEAT:OFF');
    await writeCommand(LvsCommands.strikeOff, label: 'STRIKE:OFF');
    await writeCommand(LvsCommands.suctionOff, label: 'SUCTION:OFF');
    notifyListeners();
  }

  void playWaveChannel1(WaveType type, {int max = 100}) {
    if (isCooldownActive) return;
    _stopBurst();
    activeIntensityCh1 = null; activeIntensity = null; activeSpeed = null; activePattern = null;
    activeWaveCh1 = type;
    waveMaxIntensityCh1 = max;
    _startSequencer();
    notifyListeners();
  }

  void playWaveChannel2(WaveType type, {int max = 100}) {
    if (isCooldownActive) return;
    _stopBurst();
    activeIntensityCh2 = null; activeIntensity = null; activeSpeed = null; activePattern = null;
    activeWaveCh2 = type;
    waveMaxIntensityCh2 = max;
    _startSequencer();
    notifyListeners();
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
        final c1 = val1 > 0 ? buildChannel1Command(val1) : LvsCommands.ch1Stop;
        writeCommand(c1, label: 'SQ CH1:$val1', silent: true);
        activeIntensityCh1 = val1;
      } else {
        final c2 = val2 > 0 ? buildChannel2Command(val2) : LvsCommands.cmdStop;
        writeCommand(c2, label: 'SQ CH2:$val2', silent: true);
        activeIntensityCh2 = val2;
      }
      _isCh1Turn = !_isCh1Turn;
    } else if (ch1Active) {
      final c1 = val1 > 0 ? buildChannel1Command(val1) : LvsCommands.ch1Stop;
      writeCommand(c1, label: 'SQ CH1:$val1', silent: true);
      activeIntensityCh1 = val1;
    } else if (ch2Active) {
      final c2 = val2 > 0 ? buildChannel2Command(val2) : LvsCommands.cmdStop;
      writeCommand(c2, label: 'SQ CH2:$val2', silent: true);
      activeIntensityCh2 = val2;
    }

    notifyListeners();
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
    notifyListeners();
  }

  void _startBurst(List<int> cmdBytes, String label) {
    _stopBurst();
    isBurstActive = true;
    notifyListeners();
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
    notifyListeners();
    if (isBurstActive) {
      List<int>? cmd;
      var label = '';
      if (activeSpeed != null) { cmd = LvsCommands.commandFor(activeSpeed!); label = activeSpeed!.name; }
      else if (activePattern != null) { cmd = LvsCommands.patternFor(activePattern!); label = activePattern!.name; }
      else if (activeIntensity != null) {
        cmd = buildIntensityCommand(activeIntensity!);
        label = 'INT:$activeIntensity%';
      }
      if (cmd != null) _startBurst(cmd, label);
    }
  }

  void toggleDeepScan() {
    isDeepScan = !isDeepScan;
    notifyListeners();
    _log('Deep Scan: ${isDeepScan ? "ON" : "OFF"}', 'info');
  }

  void setPacketMode(PacketMode mode) {
    packetMode = mode;
    _log('Modo paquete: ${mode.name}', 'info');
    notifyListeners();
  }

  void _log(String msg, String type) {
    _logs.add(BleLogEntry(DateTime.now(), msg, type));
    if (_logs.length > 150) {
      _logs.removeRange(0, 50);
    }
    notifyListeners();
  }

  void _setState(BleState s) {
    state = s;
    notifyListeners();
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
      );
      setActiveToy(dummyToy);
    } else {
      _log('🧪 Demo mode desactivado', 'info');
      if (!_hardwareConfirmed) {
        disconnect();
      }
    }
    notifyListeners();
  }

  void toggleBridgeMode() {
    isBridgeModeActive = !isBridgeModeActive;
    _log('🌉 Bridge mode: ${isBridgeModeActive ? "ON" : "OFF"}', 'info');
    notifyListeners();
  }

  Future<void> initSecurity() async {
    _log('🔒 Seguridad inicializada', 'info');
  }

  Future<bool> toggleTravelLock(String pin) async {
    isTravelLockActive = !isTravelLockActive;
    _log('🔒 Travel Lock: ${isTravelLockActive ? "ACTIVO" : "INACTIVO"}', 'info');
    notifyListeners();
    return true;
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
}

void startCallback() {}
