// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/session_timer_service.dart
// Servicio de Temporizador de Sesión - Auto-desconexión de seguridad
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/logger.dart';

// ═══════════════════════════════════════════════════════════════
// Providers de Riverpod
// ═══════════════════════════════════════════════════════════════

/// Provider singleton del servicio
final sessionTimerServiceProvider = Provider<SessionTimerService>((ref) {
  return SessionTimerService();
});

/// Provider del estado actual del temporizador
final sessionTimerStateProvider = StateNotifierProvider<SessionTimerStateNotifier, SessionTimerState>((ref) {
  return SessionTimerStateNotifier(ref.watch(sessionTimerServiceProvider));
});

// ═══════════════════════════════════════════════════════════════
// Modelo de Estado
// ═══════════════════════════════════════════════════════════════

enum SessionTimerStatus {
  inactive,      // Temporizador apagado
  running,       // Temporizador en cuenta regresiva
  paused,        // Pausado (opcional)
  completed,     // Tiempo completado
}

class SessionTimerState {
  final SessionTimerStatus status;
  final int durationSeconds;      // Duración total configurada
  final int remainingSeconds;     // Tiempo restante
  final bool isWarning;           // True cuando queda < 1 minuto

  SessionTimerState({
    this.status = SessionTimerStatus.inactive,
    this.durationSeconds = 0,
    this.remainingSeconds = 0,
    this.isWarning = false,
  });

  SessionTimerState copyWith({
    SessionTimerStatus? status,
    int? durationSeconds,
    int? remainingSeconds,
    bool? isWarning,
  }) {
    return SessionTimerState(
      status: status ?? this.status,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isWarning: isWarning ?? this.isWarning,
    );
  }

  /// Formato legible del tiempo restante (MM:SS)
  String get formattedRemaining {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Formato de la duración total (MM:SS)
  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Progreso como porcentaje (0.0 - 1.0)
  double get progress {
    if (durationSeconds == 0) return 0.0;
    return 1.0 - (remainingSeconds / durationSeconds);
  }
}

// ═══════════════════════════════════════════════════════════════
// State Notifier
// ═══════════════════════════════════════════════════════════════

class SessionTimerStateNotifier extends StateNotifier<SessionTimerState> {
  final SessionTimerService _service;

  SessionTimerStateNotifier(this._service) : super(SessionTimerState()) {
    // Suscribirse a cambios del servicio
    _service.addListener(_onServiceChanged);
    _loadInitialState();
  }

  void _loadInitialState() {
    final duration = _service.durationSeconds;
    final remaining = _service.remainingSeconds;
    final isActive = _service.isActive;

    state = state.copyWith(
      status: isActive ? SessionTimerStatus.running : SessionTimerStatus.inactive,
      durationSeconds: duration,
      remainingSeconds: remaining,
      isWarning: remaining < 60 && remaining > 0,
    );
  }

  void _onServiceChanged() {
    final duration = _service.durationSeconds;
    final remaining = _service.remainingSeconds;
    final isActive = _service.isActive;

    state = state.copyWith(
      status: isActive ? SessionTimerStatus.running : SessionTimerStatus.inactive,
      durationSeconds: duration,
      remainingSeconds: remaining,
      isWarning: remaining < 60 && remaining > 0,
    );
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
// Servicio de Temporizador
// ═══════════════════════════════════════════════════════════════

/// Callback cuando el temporizador expira
typedef SessionTimerExpiredCallback = void Function();

class SessionTimerService extends ChangeNotifier {
  static const String _prefsKey = 'session_timer_';
  static const String _prefsKeyDuration = '${_prefsKey}duration';
  static const String _prefsKeyRemaining = '${_prefsKey}remaining';
  static const String _prefsKeyActive = '${_prefsKey}active';

  Timer? _timer;
  SessionTimerExpiredCallback? _onExpired;

  int _durationSeconds = 0;
  int _remainingSeconds = 0;
  bool _isActive = false;

  /// Duración total configurada en segundos
  int get durationSeconds => _durationSeconds;

  /// Tiempo restante en segundos
  int get remainingSeconds => _remainingSeconds;

  /// Si el temporizador está activo
  bool get isActive => _isActive;

  /// Si queda menos de 1 minuto
  bool get isWarning => _remainingSeconds < 60 && _remainingSeconds > 0;

  /// Callback cuando expira
  set onExpired(SessionTimerExpiredCallback callback) {
    _onExpired = callback;
  }

  // Storage seguro para datos sensibles
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Cargar estado desde FlutterSecureStorage (más seguro que SharedPreferences)
  Future<void> loadFromPrefs() async {
    try {
      final durationStr = await _secureStorage.read(key: _prefsKeyDuration);
      final remainingStr = await _secureStorage.read(key: _prefsKeyRemaining);
      final activeStr = await _secureStorage.read(key: _prefsKeyActive);

      _durationSeconds = int.tryParse(durationStr ?? '0') ?? 0;
      _remainingSeconds = int.tryParse(remainingStr ?? '$_durationSeconds') ?? _durationSeconds;
      _isActive = activeStr == 'true';

      lvsLog('Timer cargado: ${_durationSeconds}s, restante: ${_remainingSeconds}s, activo: $_isActive', tag: 'TIMER');

      // Si estaba activo, no auto-iniciamos por seguridad
      _isActive = false;

      notifyListeners();
    } catch (e) {
      lvsLog('Error cargando timer: $e', tag: 'TIMER');
    }
  }

  /// Guardar estado en FlutterSecureStorage (encriptado)
  Future<void> _saveToPrefs() async {
    try {
      await _secureStorage.write(key: _prefsKeyDuration, value: _durationSeconds.toString());
      await _secureStorage.write(key: _prefsKeyRemaining, value: _remainingSeconds.toString());
      await _secureStorage.write(key: _prefsKeyActive, value: _isActive.toString());

      lvsLog('Timer guardado de forma segura', tag: 'TIMER');
    } catch (e) {
      lvsLog('Error guardando timer: $e', tag: 'TIMER');
    }
  }

  /// Configurar duración del temporizador (en minutos)
  void setDurationMinutes(int minutes) {
    if (minutes < 1 || minutes > 120) {
      throw ArgumentError('La duración debe estar entre 1 y 120 minutos');
    }

    _durationSeconds = minutes * 60;
    _remainingSeconds = _durationSeconds;
    _isActive = false;
    _timer?.cancel();

    _saveToPrefs();
    notifyListeners();

    lvsLog('Temporizador configurado: $minutes minutos ($_durationSeconds segundos)', tag: 'TIMER');
  }

  /// Iniciar temporizador
  void start() {
    if (_durationSeconds == 0) {
      lvsLog('No se puede iniciar: duración no configurada', tag: 'TIMER');
      return;
    }

    if (_isActive) {
      lvsLog('Temporizador ya está activo', tag: 'TIMER');
      return;
    }

    _isActive = true;
    _saveToPrefs();
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;

        if (_remainingSeconds % 10 == 0) {
          await _saveToPrefs();
        }
        notifyListeners();

        if (_remainingSeconds == 60) {
          lvsLog('⚠️ ADVERTENCIA: Queda 1 minuto de sesión', tag: 'TIMER');
        } else if (_remainingSeconds == 10) {
          lvsLog('⚠️ ATENCIÓN: Quedan 10 segundos', tag: 'TIMER');
        }
      } else {
        timer.cancel();
        _onTimeExpired();
      }
    });

    lvsLog('Temporizador iniciado: ${_durationSeconds ~/ 60} minutos', tag: 'TIMER');
  }

  /// Pausar temporizador
  void pause() {
    if (!_isActive) return;

    _isActive = false;
    _timer?.cancel();
    _saveToPrefs();
    notifyListeners();

    lvsLog('Temporizador pausado', tag: 'TIMER');
  }

  /// Reanudar temporizador
  void resume() {
    if (_isActive || _remainingSeconds <= 0) return;

    start();
    lvsLog('Temporizador reanudado', tag: 'TIMER');
  }

  /// Detener y resetear temporizador
  void stop() {
    _isActive = false;
    _timer?.cancel();
    _remainingSeconds = _durationSeconds;
    _saveToPrefs();
    notifyListeners();

    lvsLog('Temporizador detenido y reseteado', tag: 'TIMER');
  }

  /// Cancelar completamente (sin resetear)
  void cancel() {
    _isActive = false;
    _timer?.cancel();
    _durationSeconds = 0;
    _remainingSeconds = 0;
    _saveToPrefs();
    notifyListeners();

    lvsLog('Temporizador cancelado', tag: 'TIMER');
  }

  /// Manejar tiempo expirado
  void _onTimeExpired() {
    _isActive = false;
    _saveToPrefs();
    notifyListeners();

    lvsLog('⏰ TIEMPO EXPIRADO - Ejecutando callback', tag: 'TIMER');

    // Ejecutar callback (auto-stop del dispositivo)
    _onExpired?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
// Widget Helper: Dialog para configurar temporizador
// ═══════════════════════════════════════════════════════════════

/// Muestra dialog para seleccionar duración del temporizador
Future<int?> showSessionTimerDialog(BuildContext context) async {
  int selectedMinutes = 15; // Default

  return await showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1A1A2E), width: 1),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, color: Color(0xFFFF1493), size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'TEMPORIZADOR DE SESIÓN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: 250, // Finite height for safety
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Selecciona la duración de la sesión',
                style: TextStyle(color: Color(0xFF888899), fontSize: 10),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Selector de minutos
              Container(
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF12121F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1A1A2E)),
                ),
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 32,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    setDialogState(() {
                      selectedMinutes = (index + 1) * 5;
                    });
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (context, index) {
                      final minutes = (index + 1) * 5;
                      final isSelected = minutes == selectedMinutes;
                      return Center(
                        child: Text(
                          '$minutes min',
                          style: TextStyle(
                            fontSize: isSelected ? 16 : 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? const Color(0xFFFF1493) : const Color(0xFF888899),
                          ),
                        ),
                      );
                    },
                    childCount: 24, // 5 a 120 minutos
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Vista previa
              Text(
                '$selectedMinutes min',
                style: const TextStyle(
                  color: Color(0xFFFF1493),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: Color(0xFF888899), fontSize: 11),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, selectedMinutes),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF1493),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text(
              'INICIAR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
