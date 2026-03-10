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

class BleService extends ChangeNotifier {
  // ── Estado ─────────────────────────────────────────────────
  BleState state = BleState.idle;
  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic;
  ToyProfile? toyProfile;

  // Nombre real del hardware detectado en la sesión actual
  String connectedDeviceName = '';

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

  // Log
  final List<LogEntry> logs = [];

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
  Future<void> connectToDevice({List<ToyModel>? catalog}) async {
    if (state == BleState.scanning || state == BleState.connecting) return;
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
             _log('👁️ [DEEP] "$realName" RSSI: $rssi', 'info');
          }

          if (hasId || isBroadlink || matchesCatalog) {
            final why = matchesCatalog ? 'PRE-REGISTRADO' : (isBroadlink ? 'Broadlink' : 'ID');
            _log('🎯 MATCH ($why): "$realName" [$mac] RSSI: $rssi', 'success');
            found = r.device;
            FlutterBluePlus.stopScan();
          } else if (isDeepScan && rssi > -75) {
             // En Deep Scan somos más permisivos con la señal
            _log('✅ Deep Scan seleccionó: "$realName"', 'success');
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
    _log('Handshake: Verificando hardware activo...', 'info');

    // HANDSHAKE ACTIVO REAL: intentar enviar el paquete de verificación.
    // Si el periférico BLE del Android no puede iniciar advertising
    // (porque el hardware está apagado), writeCommand retorna false.
    final bool ok = await writeCommand(verificationCmd, label: 'VERIFY', silent: false);

    if (!ok) {
      _log('❌ Handshake fallido: el hardware no responde. Conexión rechazada.', 'error');
      connectedDeviceName = '';
      _setState(BleState.idle);
      return;
    }

    // Pausa para recibir el ACK (0x06) del hardware
    await Future.delayed(const Duration(milliseconds: 500));

    device = dev;
    batteryLevel = 100;
    _setState(BleState.connected);
    _log('✅ Handshake OK — ${toyProfile?.name ?? connectedDeviceName} vinculado.', 'success');
    await _updateNotification('Vinculado → ${toyProfile?.name ?? connectedDeviceName}');
  }



  Future<void> disconnect() async {
    _stopBurst();
    await device?.disconnect();
    await _handleDisconnect();
  }

  Future<void> _handleDisconnect() async {
    _stopBurst();
    _batterySub?.cancel();
    characteristic = null;
    device = null;
    activeSpeed = null;
    activePattern = null;
    activeIntensity = null;
    batteryLevel = 0;
    _setState(BleState.idle);
    await _updateNotification('Desconectado');
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
  // Fuerza el envío aunque el paquete sea idéntico al anterior
  Future<void> sendMultimediaSync(int ch1Val, int ch2Val) async {
    if (state != BleState.connected) return;

    // Reset de cache para forzar el envío (Gemini siempre debe activar el hardware)
    _lastPacket = null;

    // CH2 primero (vibración)
    final cmdCh2 = LvsCommands.preciseChannel2(ch2Val);
    await writeCommand(cmdCh2, label: 'GEMINI CH2', silent: false);

    // Delay entre canales para no saturar el HCI buffer
    await Future.delayed(const Duration(milliseconds: 200));
    _lastPacket = null; // reset antes del segundo canal

    // CH1 (empuje)
    if (ch1Val > 0) {
      await writeCommand(LvsCommands.preciseChannel1(ch1Val), label: 'GEMINI CH1', silent: false);
    } else if (_lastCh1Val > 0) {
      await writeCommand(LvsCommands.ch1Stop, label: 'GEMINI CH1 STOP', silent: false);
    }
    _lastCh1Val = ch1Val;
  }

  int _lastCh1Val = 0;
  bool _isWriting = false;
  List<int>? _lastPacket;

  // ══════════════════════════════════════════════════════════════
  // ESCRITURA Y COMANDOS
  // ══════════════════════════════════════════════════════════════
  Future<bool> writeCommand(List<int> cmdBytes, {String label = '', bool silent = false}) async {
    if (_isWriting) return false; // Mutex Lock: Previene desbordamiento en Android BLE Stack
    _isWriting = true;
    try {
      final packet = LvsCommands.buildPacket(cmdBytes, mode: packetMode);
      
      // OPTIMIZACIÓN: No reiniciar si el paquete es el mismo
      // El mutex se libera siempre en el bloque finally de abajo
      if (_lastPacket != null && listEquals(_lastPacket, packet)) {
        return true;
      }
      _lastPacket = packet;

      if (!silent) _log('→ [$label] ${LvsCommands.bytesToHex(packet)}', 'cmd');
      
      final data = AdvertiseData(
        serviceUuid: LvsCommands.serviceUuid, // Ahora usa el formato 128-bit correcto
        manufacturerId: LvsCommands.companyId, 
        manufacturerData: Uint8List.fromList(packet),
        includeDeviceName: false,
      );

      // Usamos AdvertiseSetParameters para activar Legacy Mode (indispensable para LVS-8154)
      final parameters = AdvertiseSetParameters(
        connectable: true,
        scannable: true,
        legacyMode: true, // Crucial para chips antiguos de Fastcon
        interval: 160,    // Aprox 100ms
      );

      // Limpieza segura del paquete previo (Evita que Android de Status Error 2)
      if (await _peripheral.isAdvertising) {
        await _peripheral.stop();
        await Future.delayed(const Duration(milliseconds: 20)); // Tiempo para vaciar buffer HCI
      }

      await _peripheral.start(
        advertiseData: data, 
        advertiseSetParameters: parameters,
      );
      
      return true;
    } catch (e) {
      if (!silent) _log('✗ Error Peripheral: $e', 'error');
      _lastPacket = null;
      return false;
    } finally {
      _isWriting = false;
    }
  }

  Future<void> selectSpeed(SpeedLevel level) async {
    _stopSequencer();
    activeSpeed = level;
    activePattern = null;
    activeIntensity = null;
    activeIntensityCh1 = null;
    activeIntensityCh2 = null;
    notifyListeners();
    final cmd = LvsCommands.commandFor(level);
    _startBurst(cmd, level.name);
  }

  Future<void> selectPattern(LvsPattern pattern) async {
    _stopSequencer();
    activePattern = pattern;
    activeSpeed = null;
    activeIntensity = null;
    activeIntensityCh1 = null;
    activeIntensityCh2 = null;
    notifyListeners();
    final cmd = LvsCommands.patternFor(pattern);
    _startBurst(cmd, pattern.name.toUpperCase());
  }

  Future<void> setProportionalIntensity(int intensity) async {
    if (isCooldownActive) return;
    _stopSequencer();
    final capped = (intensity * stealthIntensityCap).round();
    activeIntensity = capped;
    activeIntensityCh1 = null; activeIntensityCh2 = null; 
    activeSpeed = null; activePattern = null;
    notifyListeners();
    if (capped == 0) {
      emergencyStop();
    } else {
      final cmd = LvsCommands.proportional(capped);
      _startBurst(cmd, 'LVL:$capped');
    }
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
    logs.clear();
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
    logs.add(LogEntry(DateTime.now(), msg, type));
    if (logs.length > 50) logs.removeAt(0);
    notifyListeners();
  }

  void _setState(BleState s) {
    state = s;
    notifyListeners();
  }

  bool get isConnected => state == BleState.connected;
  bool get isScanning  => state == BleState.scanning;

  @override
  void dispose() {
    _stopBurst();
    _connSub?.cancel();
    _batterySub?.cancel();
    super.dispose();
  }
}

void startCallback() {}
