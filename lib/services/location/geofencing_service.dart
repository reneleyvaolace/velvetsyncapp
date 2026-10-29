// ════════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/location/geofencing_service.dart
// Geofencing Service - STUB (requires geolocator/geofence packages)
// ════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/devices/models/toy_model.dart';
import 'package:velvet_sync/utils/logger.dart';

/// Tipo de zona geográfica
enum GeofenceType {
  home,           // Casa
  work,           // Trabajo
  custom,         // Personalizada
  partner,        // Ubicación pareja
  restricted,     // Zona restringida (apaga juguete)
  autoConnect,    // Auto-conexión al entrar
  autoDisconnect, // Auto-desconexión al salir
}

/// Zona geográfica (geofence)
class GeofenceZone {
  final String id;
  final String name;
  final GeofenceType type;
  final double latitude;
  final double longitude;
  final double radiusMeters;        // Radio en metros
  final bool isActive;
  final Map<String, dynamic> actions; // Acciones al entrar/salir
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? partnerId;          // Para zonas de pareja

  GeofenceZone({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.isActive = true,
    this.actions = const {},
    this.createdAt,
    this.updatedAt,
    this.partnerId,
  });

  /// Verifica si una coordenada está dentro de la zona
  bool contains(double lat, double lon) {
    final distance = _calculateDistance(
      latitude, longitude,
      lat, lon,
    );
    return distance <= radiusMeters;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0; // metros
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double deg) => deg * math.pi / 180.0;

  /// Obtiene acción para evento
  String? getAction(GeofenceEvent event) {
    final key = event == GeofenceEvent.enter ? 'onEnter' : 'onExit';
    return actions[key] as String?;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
    'isActive': isActive,
    'actions': actions,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'partnerId': partnerId,
  };

  factory GeofenceZone.fromJson(Map<String, dynamic> json) => GeofenceZone(
    id: json['id'],
    name: json['name'],
    type: GeofenceType.values.firstWhere((e) => e.name == json['type']),
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    radiusMeters: (json['radiusMeters'] as num).toDouble(),
    isActive: json['isActive'] as bool? ?? true,
    actions: Map<String, dynamic>.from(json['actions'] ?? {}),
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    partnerId: json['partnerId'] as String?,
  );
}

/// Eventos de geofence
enum GeofenceEvent {
  enter,   // Entrada a zona
  exit,    // Salida de zona
  dwell,   // Permanencia (dwell time)
}

/// Evento de geofence disparado
class GeofenceTriggeredEvent {
  final GeofenceZone zone;
  final GeofenceEvent event;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  GeofenceTriggeredEvent({
    required this.zone,
    required this.event,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  @override
  String toString() => 'GeofenceEvent(${event.name}) - ${zone.name} at ${timestamp}';
}

/// Configuración de geofencing
class GeofencingConfig {
  final bool enabled;
  final double minRadiusMeters;        // Radio mínimo (metros)
  final double maxRadiusMeters;        // Radio máximo (metros)
  final int locationUpdateIntervalMs;  // Intervalo actualización GPS
  final double distanceFilterMeters;   // Filtro distancia mínima
  final bool backgroundLocation;       // Ubicación en background
  final int dwellTimeSeconds;          // Tiempo permanencia para evento dwell
  final bool notifyOnEnter;            // Notificar al entrar
  final bool notifyOnExit;             // Notificar al salir
  final bool notifyOnDwell;            // Notificar en permanencia

  const GeofencingConfig({
    this.enabled = true,
    this.minRadiusMeters = 10.0,
    this.maxRadiusMeters = 5000.0,
    this.locationUpdateIntervalMs = 5000,
    this.distanceFilterMeters = 10.0,
    this.backgroundLocation = true,
    this.dwellTimeSeconds = 60,
    this.notifyOnEnter = true,
    this.notifyOnExit = true,
    this.notifyOnDwell = false,
  });

  GeofencingConfig copyWith({
    bool? enabled,
    double? minRadiusMeters,
    double? maxRadiusMeters,
    int? locationUpdateIntervalMs,
    double? distanceFilterMeters,
    bool? backgroundLocation,
    int? dwellTimeSeconds,
    bool? notifyOnEnter,
    bool? notifyOnExit,
    bool? notifyOnDwell,
  }) {
    return GeofencingConfig(
      enabled: enabled ?? this.enabled,
      minRadiusMeters: minRadiusMeters ?? this.minRadiusMeters,
      maxRadiusMeters: maxRadiusMeters ?? this.maxRadiusMeters,
      locationUpdateIntervalMs: locationUpdateIntervalMs ?? this.locationUpdateIntervalMs,
      distanceFilterMeters: distanceFilterMeters ?? this.distanceFilterMeters,
      backgroundLocation: backgroundLocation ?? this.backgroundLocation,
      dwellTimeSeconds: dwellTimeSeconds ?? this.dwellTimeSeconds,
      notifyOnEnter: notifyOnEnter ?? this.notifyOnEnter,
      notifyOnExit: notifyOnExit ?? this.notifyOnExit,
      notifyOnDwell: notifyOnDwell ?? this.notifyOnDwell,
    );
  }
}

/// Servicio de Geofencing (STUB - requiere paquetes geolocator/geofence)
class GeofencingService {
  final GeofencingConfig config;
  final BleService _bleService;

  final List<GeofenceZone> _zones = [];
  final Set<String> _activeZones = {};
  bool _isMonitoring = false;

  // Callbacks
  Function(GeofenceTriggeredEvent)? onGeofenceEvent;
  Function(String)? onError;
  Function(bool)? onMonitoringStateChange;
  Function(List<GeofenceZone>)? onZonesChanged;

  GeofencingService({
    required this.config,
    required BleService bleService,
  }) : _bleService = bleService;

  bool get isMonitoring => _isMonitoring;
  List<GeofenceZone> get zones => List.unmodifiable(_zones);
  Set<String> get activeZones => Set.unmodifiable(_activeZones);

  /// Inicializa el servicio
  Future<bool> initialize() async {
    lvsLog('GeofencingService inicializado (STUB)', tag: 'GEOFENCING');
    return true;
  }

  /// Agrega una zona
  void addZone(GeofenceZone zone) {
    if (_zones.any((z) => z.id == zone.id)) return;
    _zones.add(zone);
    lvsLog('Zona agregada: ${zone.name} (${zone.type.name})', tag: 'GEOFENCING');
  }

  /// Elimina una zona
  void removeZone(String zoneId) {
    _zones.removeWhere((z) => z.id == zoneId);
  }

  /// Inicia monitoreo (STUB)
  Future<void> startMonitoring() async {
    _isMonitoring = true;
    lvsLog('Monitoreo geofencing iniciado (STUB)', tag: 'GEOFENCING');
  }

  /// Detiene monitoreo
  void stopMonitoring() {
    _isMonitoring = false;
    lvsLog('Monitoreo geofencing detenido', tag: 'GEOFENCING');
  }

  /// Crea zona predefinida: Casa
  static GeofenceZone createHomeZone({
    required String id,
    required String name,
    required double latitude,
    required double longitude,
    double radiusMeters = 100.0,
  }) {
    return GeofenceZone(
      id: id,
      name: name,
      type: GeofenceType.home,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      actions: {
        'onEnter': 'connect',
        'onExit': 'disconnect',
      },
    );
  }

  /// Crea zona restringida
  static GeofenceZone createRestrictedZone({
    required String id,
    required String name,
    required double latitude,
    required double longitude,
    double radiusMeters = 50.0,
  }) {
    return GeofenceZone(
      id: id,
      name: name,
      type: GeofenceType.restricted,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      actions: {
        'onEnter': 'stop',
        'onExit': 'connect',
      },
    );
  }

  /// Crea zona de pareja
  static GeofenceZone createPartnerZone({
    required String id,
    required String name,
    required double latitude,
    required double longitude,
    required String partnerId,
    double radiusMeters = 200.0,
  }) {
    return GeofenceZone(
      id: id,
      name: name,
      type: GeofenceType.partner,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      partnerId: partnerId,
      actions: {
        'onEnter': 'connect',
        'onExit': 'disconnect',
      },
    );
  }

  /// Exporta zonas a JSON
  String exportZones() {
    return jsonEncode(_zones.map((z) => z.toJson()).toList());
  }

  void dispose() {
    // Cleanup
  }
}

/// Provider para Riverpod
final geofencingServiceProvider = Provider<GeofencingService>((ref) {
  final ble = ref.read(bleProvider);
  return GeofencingService(
    config: const GeofencingConfig(),
    bleService: ble,
  );
});