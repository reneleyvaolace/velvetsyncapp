// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/sync_service.dart
// Servicio de sincronización en tiempo real con Supabase
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/device_sync_model.dart';
import '../utils/logger.dart';
import 'supabase_service.dart';

// ═══════════════════════════════════════════════════════════════
// Providers de Riverpod
// ═══════════════════════════════════════════════════════════════

/// Provider que expone el SyncService como singleton
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService();
});

/// Provider que expone el stream de eventos de sincronización
final syncEventsProvider = StreamProvider<List<DeviceSyncEvent>>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.eventsStream;
});

/// Provider que expone el último evento recibido
final lastSyncEventProvider = StateProvider<DeviceSyncEvent?>((ref) => null);

/// Provider que expone el estado de conexión del canal realtime
final syncChannelStateProvider = StateProvider<SyncChannelState>((ref) {
  return SyncChannelState.disconnected;
});

// ═══════════════════════════════════════════════════════════════
// Estados del canal
// ═══════════════════════════════════════════════════════════════

enum SyncChannelState {
  /// Canal desconectado
  disconnected,
  
  /// Conectando al canal
  connecting,
  
  /// Canal suscrito y escuchando
  subscribed,
  
  /// Canal recibiendo eventos
  receiving,
  
  /// Error en el canal
  error,
}

// ═══════════════════════════════════════════════════════════════
// Callbacks para eventos del sistema
// ═══════════════════════════════════════════════════════════════

/// Callback para eventos de sincronización
typedef SyncEventCallback = void Function(DeviceSyncEvent event);

// ═══════════════════════════════════════════════════════════════
// SyncService
// ═══════════════════════════════════════════════════════════════

/// Servicio de sincronización en tiempo real con Supabase
/// Escucha cambios en la tabla `device_sync` y emite eventos al sistema
class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  SupabaseService? _supabaseService;
  RealtimeChannel? _channel;
  
  final List<DeviceSyncEvent> _recentEvents = [];
  final List<SyncEventCallback> _aiProfileListeners = [];
  
  StreamSubscription? _eventsSubscription;
  Timer? _heartbeatTimer;
  
  bool _isInitialized = false;
  SyncChannelState _state = SyncChannelState.disconnected;
  
  /// Stream controller para emitir eventos a los subscribers
  final _eventsController = StreamController<List<DeviceSyncEvent>>.broadcast();

  /// Stream de eventos de sincronización
  Stream<List<DeviceSyncEvent>> get eventsStream => _eventsController.stream;

  /// Lista de eventos recientes (últimos 50)
  List<DeviceSyncEvent> get recentEvents => List.unmodifiable(_recentEvents);

  /// Último evento recibido
  DeviceSyncEvent? get lastEvent => _recentEvents.isNotEmpty ? _recentEvents.last : null;

  /// Estado actual del canal
  SyncChannelState get state => _state;

  /// Verifica si el servicio está inicializado
  bool get isInitialized => _isInitialized;

  /// Verifica si el canal está recibiendo eventos
  bool get isReceiving => _state == SyncChannelState.receiving;

  /// Inicializa el servicio de sincronización
  /// Debe llamarse después de que SupabaseService esté inicializado
  Future<void> init() async {
    if (_isInitialized) {
      debugPrint('[SyncService] Ya está inicializado');
      return;
    }

    debugPrint('[SyncService] Iniciando servicio de sincronización...');
    _setState(SyncChannelState.connecting);

    try {
      // Obtener instancia de SupabaseService
      _supabaseService = SupabaseService();
      await _supabaseService!.initialize();

      // Suscribirse al canal de device_sync
      await _subscribeToChannel();

      // Configurar heartbeat para mantener conexión
      _startHeartbeat();

      _isInitialized = true;
      _setState(SyncChannelState.subscribed);
      
      lvsLog('SyncService inicializado - Canal: public:device_sync', tag: 'SYNC');
      notifyListeners();
    } catch (e) {
      debugPrint('[SyncService] Error al iniciar: $e');
      lvsLog('Error al iniciar SyncService: $e', tag: 'SYNC');
      _setState(SyncChannelState.error);
      rethrow;
    }
  }

  /// Suscribe al canal de Supabase para device_sync
  Future<void> _subscribeToChannel() async {
    final client = _supabaseService!.client;

    // Suscribirse a cambios en la tabla device_sync
    // Usamos el formato: schema:table
    _channel = client.channel('public:device_sync');

    // Configurar listener para cambios INSERT antes de suscribir
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'device_sync',
      callback: _onDatabaseChange,
    );

    // Suscribirse al canal usando callback
    _channel!.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint('[SyncService] Canal suscrito exitosamente');
        lvsLog('Canal public:device_sync suscrito', tag: 'SYNC');
        _setState(SyncChannelState.receiving);
      } else if (status == RealtimeSubscribeStatus.channelError) {
        // ⚠️ NO LOGUEAR ERRORES DE RED PARA NO SATURAR
        // debugPrint('[SyncService] Error en el canal: $error');
        final isNetworkError = error.toString().contains('SocketException') || 
                               error.toString().contains('Failed host lookup');
        if (!isNetworkError) {
          debugPrint('[SyncService] Error en el canal: $error');
          lvsLog('Error en canal realtime: $error', tag: 'SYNC');
        }
        _setState(SyncChannelState.error);
      } else if (status == RealtimeSubscribeStatus.timedOut) {
        // ⚠️ TIMEOUTS DE RED SON NORMALES SIN INTERNET
        // debugPrint('[SyncService] Timeout al suscribir');
        _setState(SyncChannelState.error);
      }
    });

    // Esperar un poco para dar tiempo a que se establezca la conexión
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Callback cuando hay cambios en la base de datos
  void _onDatabaseChange(PostgresChangePayload payload) {
    debugPrint('[SyncService] Cambio detectado');

    try {
      // Extraer el registro nuevo (INSERT)
      final record = payload.newRecord;

      // Mapear a DeviceSyncEvent
      final syncEvent = DeviceSyncEvent.fromMap(record);

      // Validar que el evento tenga datos válidos
      if (syncEvent.deviceId.isEmpty || syncEvent.command.isEmpty) {
        debugPrint('[SyncService] Evento inválido recibido');
        return;
      }

      debugPrint('[SyncService] Evento recibido: ${syncEvent.command} para ${syncEvent.deviceId}');
      lvsLog('SYNC: ${syncEvent.command} -> ${syncEvent.deviceId}', tag: 'SYNC');

      // Agregar a eventos recientes
      _addEvent(syncEvent);

      // Si es APPLY_AI_PROFILE, notificar a los listeners específicos
      if (syncEvent.isAiProfile) {
        _notifyAiProfileListeners(syncEvent);
      }

      // Actualizar estado
      if (_state != SyncChannelState.receiving) {
        _setState(SyncChannelState.receiving);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[SyncService] Error procesando evento: $e');
      lvsLog('Error procesando evento: $e', tag: 'SYNC');
    }
  }

  /// Agrega un evento a la lista de eventos recientes
  void _addEvent(DeviceSyncEvent event) {
    _recentEvents.add(event);
    
    // Mantener solo los últimos 50 eventos
    if (_recentEvents.length > 50) {
      _recentEvents.removeAt(0);
    }

    // Emitir a través del stream
    _eventsController.add(List.unmodifiable(_recentEvents));
  }

  /// Inicia el heartbeat para mantener la conexión activa
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      // ⚠️ SOLO LOGUEAR SI EL CANAL ESTÁ ACTIVO
      if (_channel != null && _state == SyncChannelState.receiving) {
        // debugPrint('[SyncService] Heartbeat - Canal activo');
      }
    });
  }

  /// Establece el estado del canal
  void _setState(SyncChannelState newState) {
    _state = newState;
    debugPrint('[SyncService] Estado: ${newState.name}');
  }

  // ═══════════════════════════════════════════════════════════════
  // Gestión de Listeners para APPLY_AI_PROFILE
  // ═══════════════════════════════════════════════════════════════

  /// Registra un listener para eventos APPLY_AI_PROFILE
  void addAiProfileListener(SyncEventCallback callback) {
    if (!_aiProfileListeners.contains(callback)) {
      _aiProfileListeners.add(callback);
      debugPrint('[SyncService] Listener AI Profile registrado');
    }
  }

  /// Remueve un listener para eventos APPLY_AI_PROFILE
  void removeAiProfileListener(SyncEventCallback callback) {
    _aiProfileListeners.remove(callback);
    debugPrint('[SyncService] Listener AI Profile removido');
  }

  /// Notifica a todos los listeners de APPLY_AI_PROFILE
  void _notifyAiProfileListeners(DeviceSyncEvent event) {
    debugPrint('[SyncService] Notificando ${_aiProfileListeners.length} listeners de AI Profile');
    
    for (final callback in _aiProfileListeners) {
      try {
        callback(event);
      } catch (e) {
        debugPrint('[SyncService] Error en listener AI Profile: $e');
        lvsLog('Error en listener AI Profile: $e', tag: 'SYNC');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Métodos de utilidad
  // ═══════════════════════════════════════════════════════════════

  /// Obtiene eventos filtrados por deviceId
  List<DeviceSyncEvent> getEventsForDevice(String deviceId) {
    return _recentEvents.where((e) => e.deviceId == deviceId).toList();
  }

  /// Obtiene eventos filtrados por comando
  List<DeviceSyncEvent> getEventsByCommand(String command) {
    return _recentEvents.where((e) => e.command == command).toList();
  }

  /// Limpia el historial de eventos
  void clearHistory() {
    _recentEvents.clear();
    _eventsController.add([]);
    debugPrint('[SyncService] Historial limpiado');
  }

  /// Remueve eventos antiguos (más de 5 minutos)
  void pruneOldEvents() {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(minutes: 5));
    
    _recentEvents.removeWhere((e) => e.timestamp.isBefore(cutoff));
    _eventsController.add(List.unmodifiable(_recentEvents));
    
    debugPrint('[SyncService] Eventos antiguos removidos. Restantes: ${_recentEvents.length}');
  }

  // ═══════════════════════════════════════════════════════════════
  // Cleanup
  // ═══════════════════════════════════════════════════════════════

  /// Cierra el canal y limpia recursos
  @override
  Future<void> dispose() async {
    debugPrint('[SyncService] Cerrando servicio...');

    _heartbeatTimer?.cancel();
    _eventsSubscription?.cancel();

    if (_channel != null) {
      await _channel!.unsubscribe();
      _channel = null;
    }

    await _eventsController.close();
    _aiProfileListeners.clear();
    _recentEvents.clear();

    _isInitialized = false;
    _setState(SyncChannelState.disconnected);

    lvsLog('SyncService cerrado', tag: 'SYNC');
    super.dispose();
  }
}
