// ═══════════════════════════════════════════════════════════════
// LVS Control · lib/ble/ble_service.dart · v2.0.0
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
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'lvs_commands.dart';
import '../models/toy_model.dart';
import 'toy_profile.dart';
import '../utils/logger.dart';
import '../services/ai_hardware_bridge_service.dart';

// ── Provider Global para Riverpod ──────────────────────────────
final bleProvider = ChangeNotifierProvider((ref) => BleService());

enum BleState { idle, scanning, connecting, connected, error }
enum WaveType { none, pulse, wave, ramp, storm }

class LogEntry {
  final DateTime time;
  final String msg;
  final String type; // 'info' | 'cmd' | 'success' | 'warn' | 'error'
  LogEntry(this.time, this.msg, this.type);
}

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

  // ── NUEVO: Handshake & Cooldown ─────────────────────────────
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

    // ── NUEVO: Marcar como conexión VIRTUAL (sin hardware real) ──
    _hardwareConfirmed = false;
    _setState(BleState.connected); // Estado "virtual" para UI

    // Notificar al AI Hardware Bridge
    _notifyAIBridge(toy);

    _log('📱 Dispositivo "${toy.name}" activado desde el catálogo (MODO VIRTUAL - sin hardware)', 'info');
    notifyListeners();
  }

  /// ── NUEVO: Método para verificar si hay hardware real conectado ──
  Future<bool> verifyHardwareConnection() async {
    if (!_hardwareConfirmed) {
      _log('⚠️ No hay hardware confirmado. Intentando verificar...', 'warn');
      // Intentar handshake de verificación
      final bool ok = await writeCommand(verificationCmd, label: 'VERIFY_HW', silent: true);
      if (ok) {
        _hardwareConfirmed = true;
        _log('✅ Hardware verificado exitosamente', 'success');
      } else {
        _log('❌ No hay hardware físico presente', 'error');
      }
      return ok;
    }
    return true;
  }

  /// Notifica al AI Hardware Bridge sobre el dispositivo activo
  void _notifyAIBridge(ToyModel toy) {
    try {
      // Obtener instancia del AIHardwareBridge si está disponible
      debugPrint('[BleService] Notificando AI Bridge: ${toy.name}');
      final aiBridge = AIHardwareBridge();
      aiBridge.setCurrentToy(toy);
    } catch (e) {
      debugPrint('[BleService] Error notificando AI Bridge: $e');
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
      return 75; // Los patrones son fuertes por naturaleza (75%)
    }
    return 0;
  }

  // Log - 🔒 PERFORMANCE: Limitado a 100 entradas para prevenir memory growth
  final List<LogEntry> _logs = [];
  List<LogEntry> get logs {
    final maxLogs = 100;
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
        // v9.x: intervalMs es int (milisegundos), no Duration
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

    // Esperar a que el Bluetooth se encienda realmente
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      _log('Encendiendo Bluetooth...', 'warn');
      if (Platform.isAndroid) await FlutterBluePlus.turnOn();
      // Esperar hasta 3 segundos a que cambie el estado
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
        continuousUpdates: true, // Requerido por removeIfGone
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
          final bool isWeakSignal = rssi < -85;

          // Filtros base: LVS por nombre conocido
          final hasId       = realName.contains('8154') || realName.contains('LVS');
          final isBroadlink = realName.startsWith('wbMSE');

          // ✨ NUEVO: coincidencia con catálogo (incluye pre-registrados)
          bool matchesCatalog = false;
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
          bool shouldConnect = false;
          String reason = '';

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
      _log('No se encontró dispositivo compatible.', 'warn');
      _setState(BleState.idle);
      return;
    }

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

    // ── NUEVO: Timeout estricto para handshake (3 segundos máx) ──
    final handshakeTimeout = const Duration(seconds: 3);

    try {
      // HANDSHAKE ACTIVO REAL con timeout
      final bool ok = await writeCommand(verificationCmd, label: 'VERIFY', silent: false)
          .timeout(handshakeTimeout, onTimeout: () {
            _log('⏱️ Timeout de handshake (3s) - hardware no responde', 'error');
            return false;
          });

      if (!ok) {
        _log('❌ Handshake fallido: el hardware no responde. Conexión RECHAZADA.', 'error');
        _log('   Posibles causas: 1) Dispositivo apagado, 2) Fuera de rango, 3) Falso positivo en escaneo', 'warn');
        connectedDeviceName = '';
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
      final bool secondCheck = await writeCommand([0x00, 0x00, 0x00], label: 'VERIFY2', silent: true)
          .timeout(const Duration(milliseconds: 1500), onTimeout: () => false);

      if (!secondCheck) {
        _log('⚠️ Segunda verificación fallida - hardware inestable', 'warn');
        // No rechazamos, pero logueamos
      }

      if (!connectedDevices.contains(dev)) {
        connectedDevices.add(dev);
      }

      // ── NUEVO: Confirmar hardware exitoso ──
      _hardwareConfirmed = true;
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
    _stopBurst();
    _batterySub?.cancel();
    characteristic = null;
    activeToy = null; // Limpiar dispositivo virtual
    activeSpeed = null;
    activePattern = null;
    activeIntensity = null;
    batteryLevel = 0;

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
    try {
      _isWriting = false;   // Liberar mutex por si está bloqueado
      _lastPacket = null;
      if (await _peripheral.isAdvertising) {
        await _peripheral.stop();
      }
      await writeCommand(LvsCommands.cmdStop, label: 'EMERGENCY_STOP', silent: false);
      await Future.delayed(const Duration(milliseconds: 120));
      _lastPacket = null;
      await writeCommand(LvsCommands.ch1Stop, label: 'EMERGENCY_STOP_CH1', silent: false);
    } catch (_) {}
    _log('🛑 PARADA DE EMERGENCIA', 'error');
    Future.microtask(() => notifyListeners());
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
    
    _lastCh1Val = ch1Val;
  }

  int _lastCh1Val = 0;
  bool _isWriting = false;
  List<int>? _lastPacket;

  // ══════════════════════════════════════════════════════════════
  // ESCRITURA Y COMANDOS
  // ══════════════════════════════════════════════════════════════

  // 🔒 PERFORMANCE: Cola de comandos para evitar bloqueo UI
  final List<_QueuedCommand> _commandQueue = [];
  bool _isProcessingQueue = false;

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
      final packet = LvsCommands.buildPacket(cmd.cmdBytes, mode: packetMode);

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
      // Procesar siguiente comando
      _processCommandQueue();
    }
  }

  Future<void> selectSpeed(SpeedLevel level) async {
    // 🔒 PERFORMANCE: Early exit si es el mismo speed
    if (activeSpeed == level) return;

    _stopSequencer();
    activeSpeed = level;
    activePattern = null;
    activeIntensity = null;
    activeIntensityCh1 = null;
    activeIntensityCh2 = null;

    final cmd = LvsCommands.commandFor(level);
    _startBurst(cmd, level.name);
    notifyListeners();
  }

  Future<void> selectPattern(LvsPattern pattern) async {
    // 🔒 PERFORMANCE: Early exit si es el mismo pattern
    if (activePattern == pattern) return;

    _stopSequencer();
    activePattern = pattern;
    activeSpeed = null;
    activeIntensity = null;
    activeIntensityCh1 = null;
    activeIntensityCh2 = null;

    final cmd = LvsCommands.patternFor(pattern);
    _startBurst(cmd, pattern.name.toUpperCase());
    notifyListeners();
  }

  Future<void> setProportionalIntensity(int intensity) async {
    if (isCooldownActive) return;

    final capped = (intensity * stealthIntensityCap).round();

    // 🔒 PERFORMANCE: Early exit si es la misma intensidad
    if (activeIntensity == capped && activeSpeed == null && activePattern == null) return;

    _stopSequencer();
    activeIntensity = capped;
    activeIntensityCh1 = null; activeIntensityCh2 = null;
    activeSpeed = null; activePattern = null;

    if (capped == 0) {
      emergencyStop();
    } else {
      final cmd = LvsCommands.proportional(capped);
      _startBurst(cmd, 'LVL:$capped');
    }
    notifyListeners();
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
    notifyListeners();
    if (capped == 0) {
      _startBurst(LvsCommands.cmdStop, 'CH2:STOP');
    } else {
      final cmd = LvsCommands.proportionalChannel2(capped);
      _startBurst(cmd, 'CH2:$capped');
    }
  }

  Future<void> setPatternChannel2(int p) async {
    _stopSequencer();
    activePatternCh2 = (p == 0) ? null : p;
    activeIntensityCh2 = null;
    activeIntensity = null;
    activePattern = null;
    activeSpeed = null;
    notifyListeners();
    final cmd = LvsCommands.ch2PatternFor(p);
    _startBurst(cmd, 'CH2:PAT$p');
  }

  // emergencyStop() está definido arriba (~línea 339) con versión más robusta
  // que bypassa el mutex y detiene el advertising directamente.

  Future<void> setPatternChannel1(int p) async {
    if (isCooldownActive) return;
    _stopSequencer();
    activePatternCh1 = (p == 0) ? null : p;
    activeIntensityCh1 = null; activeIntensity = null;
    activePattern = null; activeSpeed = null;
    notifyListeners();
    final cmd = LvsCommands.ch1PatternFor(p);
    _startBurst(cmd, 'CH1:PAT$p');
  }

  // ══════════════════════════════════════════════════════════════
  // SECUENCIADOR DUAL POR SOFTWARE (Ondas Estéreo)
  // ══════════════════════════════════════════════════════════════
  
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
    bool ch1Active = activeWaveCh1 != WaveType.none;
    bool ch2Active = activeWaveCh2 != WaveType.none;
    
    if (!ch1Active && !ch2Active) {
      _stopSequencer();
      return;
    }

    int val1 = ch1Active ? _evaluateWave(activeWaveCh1, _sequenceTick, waveMaxIntensityCh1) : 0;
    int val2 = ch2Active ? _evaluateWave(activeWaveCh2, _sequenceTick, waveMaxIntensityCh2) : 0;
    
    // TDM (Time-Division Multiplexing) - Alterna comandos físicos para emular estéreo
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
    
    notifyListeners();
  }

  int _evaluateWave(WaveType type, int tick, int maxIntensity) {
    if (maxIntensity <= 0) return 0;
    switch (type) {
      case WaveType.none: return 0;
      case WaveType.pulse:
        return (tick % 10 < 5) ? maxIntensity : 0; // 500ms ON / OFF
      case WaveType.wave:
        final sinVal = (math.sin(tick * 0.4) + 1) / 2;
        return (sinVal * maxIntensity).toInt();
      case WaveType.ramp:
        return ((tick % 20) / 20 * maxIntensity).toInt(); // Sube por 2 seg y reinicia
      case WaveType.storm:
        return (maxIntensity * 0.3 + math.Random().nextInt((maxIntensity * 0.7).toInt())).toInt(); // Caos alto
    }
  }

  /// Escribe un comando crudo de 3 bytes (para el modo debug)
  Future<void> writeDebugCommand(int b0, int b1, int b2, {bool silent = false}) async {
    final cmd = [b0, b1, b2];
    await writeCommand(cmd, label: 'DBG:${LvsCommands.bytesToHex(cmd)}', silent: silent);
  }

  /// Limpia el log de actividad
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
      String label = '';
      if (activeSpeed != null) { cmd = LvsCommands.commandFor(activeSpeed!); label = activeSpeed!.name; }
      else if (activePattern != null) { cmd = LvsCommands.patternFor(activePattern!); label = activePattern!.name; }
      else if (activeIntensity != null) { cmd = LvsCommands.proportional(activeIntensity!); label = 'INT:${activeIntensity}%'; }
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
    _logs.add(LogEntry(DateTime.now(), msg, type));
    // 🔒 PERFORMANCE: Eliminar entradas antiguas en bloques para eficiencia
    if (_logs.length > 150) {
      _logs.removeRange(0, 50);  // Eliminar 50 entradas de una vez
    }
    notifyListeners();
  }

  void _setState(BleState s) {
    state = s;
    notifyListeners();
  }


  @override
  void dispose() {
    // 🔒 PERFORMANCE: Cancel all timers to prevent memory leaks
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
