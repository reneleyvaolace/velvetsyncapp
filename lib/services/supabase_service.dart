// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/supabase_service.dart
// Integración con Supabase para Catálogo, Errores y Sigilo
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/toy_model.dart';
import '../utils/logger.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

class SupabaseService {
  static bool _isInitialized = false;
  
  static const String thermMax80 = 'THERM_MAX_80';
  
  // Canales para comunicación rápida (P2P Virtual)
  RealtimeChannel? _activeChannel;
  final String _clientId = DateTime.now().millisecondsSinceEpoch.toString(); // Identificador único por sesión de app

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 🔒 SECURITY: Credentials MUST come from .env file - no hardcoded fallbacks
    final String? url = dotenv.env['SUPABASE_URL'];
    final String? anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    // Validate credentials are present
    if (url == null || url.isEmpty) {
      throw StateError('SUPABASE_URL not found in .env file. Application cannot start without Supabase configuration.');
    }

    if (anonKey == null || anonKey.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY not found in .env file. Application cannot start without Supabase configuration.');
    }

    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
      _isInitialized = true;
      lvsLog('Supabase Inicializado OK: $url', tag: 'SUPABASE');
    } catch (e) {
      lvsLog('❌ Error crítico inicializando Supabase: $e', tag: 'SUPABASE');
      rethrow;
    }
  }

  SupabaseClient get client => Supabase.instance.client;

  // 1. Mapeo de Hardware (device_catalog)
  /// Obtiene el catálogo de dispositivos desde Supabase
  /// [limit] Cantidad máxima de dispositivos a retornar (por defecto 2000)
  Future<List<ToyModel>> fetchDeviceCatalog({int limit = 2000}) async {
    if (!_isInitialized) return [];
    try {
      // ✨ Optimización: Solo pedimos las columnas necesarias para la UI del catálogo
      // Evitamos traer 'raw_json_data' y otros campos pesados en la lista general
      // 🔒 PERFORMANCE: Timeout de 10 segundos para prevenir cuelgues en redes pobres
      final response = await client
          .from('device_catalog')
          .select('id, factory_model, model_name, usage_type, target_anatomy, stimulation_type, motor_logic, image_url, qr_code_url, supported_funcs, is_precise_new, broadcast_prefix')
          .limit(limit)
          .timeout(const Duration(seconds: 10), onTimeout: () => []);

      return (response as List).map((data) => ToyModel.fromSupabase(data)).toList();
    } catch (e) {
      lvsLog('Error fetchCatalog: $e', tag: 'SUPABASE');
      return [];
    }
  }

  // 1b. Buscar dispositivo individual por ID (para agregar por clave)
  Future<ToyModel?> fetchDeviceById(String id) async {
    if (!_isInitialized) return null;
    try {
      // 🔒 PERFORMANCE: Timeout de 8 segundos
      final response = await client
          .from('device_catalog')
          .select()
          .or('id.eq.$id,model_name.ilike.%$id%')
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 8), onTimeout: null);
      if (response == null) {
        lvsLog('No se encontró match para "$id"', tag: 'SUPABASE');
        return null;
      }
      final matchName = response['model_name'] ?? response['name'] ?? 'Generic';
      lvsLog('Match encontrado para "$id" -> $matchName', tag: 'SUPABASE');
      return ToyModel.fromSupabase(response);
    } catch (e) {
      lvsLog('Error fetchDeviceById: $e', tag: 'SUPABASE');
      return null;
    }
  }

  // 3. Gestión de Errores (Coreaura Lab)
  Future<String?> getTroubleshooting(String errorCode) async {
    if (!_isInitialized) return null;
    try {
      // 🔒 PERFORMANCE: Timeout de 5 segundos
      final data = await client
          .from('hardware_troubleshooting_steps')
          .select('steps')
          .eq('error_code', errorCode)
          .maybeSingle()
          .timeout(const Duration(seconds: 5), onTimeout: null);
      return data?['steps'];
    } catch (e) {
      return null;
    }
  }

  // 4. Privacidad y Sigilo
  Future<bool> isStealthActive() async {
    if (!_isInitialized) return false;
    try {
      final now = DateTime.now();
      final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00";

      // 🔒 PERFORMANCE: Timeout de 5 segundos
      final data = await client
          .from('stealth_policies')
          .select('max_intensity_cap')
          .filter('start_time', 'lte', timeStr)
          .filter('end_time', 'gte', timeStr)
          .maybeSingle()
          .timeout(const Duration(seconds: 5), onTimeout: null);

      return data != null;
    } catch (e) {
      return false;
    }
  }

  Future<double> getStealthIntensityCap() async {
    if (!_isInitialized) return 1.0;
    try {
      final now = DateTime.now();
      final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00";

      // 🔒 PERFORMANCE: Timeout de 5 segundos
      final data = await client
          .from('stealth_policies')
          .select('max_intensity_cap')
          .filter('start_time', 'lte', timeStr)
          .filter('end_time', 'gte', timeStr)
          .maybeSingle()
          .timeout(const Duration(seconds: 5), onTimeout: null);

      if (data == null) return 1.0;
      return (data['max_intensity_cap'] as num).toDouble() / 100.0;
    } catch (e) {
      return 1.0;
    }
  }

  // 5. Sesiones Compartidas (Link Remoto)
  /// Fetch session by token with expiration validation
  /// Returns null if session is expired or invalid
  Future<Map<String, dynamic>?> fetchSessionByToken(String token) async {
    if (!_isInitialized) return null;

    // 🔒 SECURITY: Validate token format before querying
    if (token.isEmpty) {
      lvsLog('Session token is empty', tag: 'SUPABASE');
      return null;
    }

    // Validate token format (alphanumeric, reasonable length)
    if (!RegExp(r'^[a-zA-Z0-9_-]{16,255}$').hasMatch(token)) {
      lvsLog('Invalid session token format', tag: 'SUPABASE');
      return null;
    }

    try {
      final now = DateTime.now().toIso8601String();

      // 🔒 SECURITY: Check expiration timestamp
      final response = await client
          .from('shared_sessions')
          .select()
          .eq('access_token', token)
          .eq('is_active', true)
          // Only return session if it hasn't expired
          .filter('expires_at', 'gt', now)
          .maybeSingle();

      if (response == null) {
        lvsLog('Session not found, expired, or inactive', tag: 'SUPABASE');
        return null;
      }

      return response;
    } catch (e) {
      lvsLog('Error fetchSessionByToken: $e', tag: 'SUPABASE');
      return null;
    }
  }

  // ── Rate Limiting para Sesiones Compartidas ──────────────────
  DateTime? _lastSessionCreationTime;
  static const Duration _sessionCreationCooldown = Duration(seconds: 5); // 5 segundos entre creaciones

  /// Crea una nueva sesión compartida en la DB y retorna sus datos (ID, Token)
  /// Incluye rate limiting para prevenir abuso
  Future<Map<String, dynamic>?> createSharedSession(String deviceId) async {
    if (!_isInitialized) return null;

    // 🔒 SECURITY: Rate limiting - prevent session creation abuse
    final now = DateTime.now();
    if (_lastSessionCreationTime != null) {
      final elapsed = now.difference(_lastSessionCreationTime!);
      if (elapsed < _sessionCreationCooldown) {
        final waitTime = (_sessionCreationCooldown - elapsed).inSeconds;
        lvsLog('Rate limit: Wait $waitTime seconds before creating another session', tag: 'SUPABASE');
        throw StateError('Please wait $waitTime seconds before creating another session');
      }
    }
    _lastSessionCreationTime = now;

    try {
      // 1. Intentar insertar con el ID del dispositivo
      final response = await client
          .from('shared_sessions')
          .insert({
            'device_id': deviceId,
            'is_active': true,
          })
          .select()
          .single();
      lvsLog('Sesión creada: ID ${response['id']}', tag: 'SUPABASE');
      return response;
    } catch (e) {
      lvsLog('⚠️ Fallo inicial en createSharedSession ($deviceId): $e', tag: 'SUPABASE');

      // 2. Reintento con ID genérico (por si el deviceId no existe en el catálogo remoto y hay FK)
      if (deviceId != '8154') {
        try {
          lvsLog('🔄 Reintentando con ID genérico...', tag: 'SUPABASE');
          final retryResponse = await client
              .from('shared_sessions')
              .insert({
                'device_id': '8154', // Usamos el ID del Knight No. 3 como fallback universal
                'is_active': true,
              })
              .select()
              .single();
          return retryResponse;
        } catch (e2) {
          lvsLog('❌ Error fatal en reintento: $e2', tag: 'SUPABASE');
          rethrow;
        }
      }
      rethrow;
    }
  }
  // ── Comunicación Ultrarrápida (Broadcast) ──────────────────
  
  /// Se une a una sala de control en tiempo real para una sesión
  void joinControlRoom(String sessionId, Function(Map<String, dynamic> payload, bool isSelf) onCommandReceived) {
    _activeChannel?.unsubscribe();
    
    _activeChannel = client.channel('session_$sessionId');
    
    _activeChannel!.onBroadcast(
      event: 'control_command',
      callback: (payload) {
        final String? senderId = payload['sender_id'];
        final bool isSelf = senderId == _clientId;
        lvsLog('Comando P2P (${isSelf ? 'Mío' : 'Socio'}): $payload', tag: 'SUPA');
        onCommandReceived(payload, isSelf);
      },
    ).subscribe();
    
    lvsLog('Unido a sala de control: session_$sessionId', tag: 'SUPA');
  }

  /// Envía un comando de intensidad sin pasar por la base de datos (Latencia mínima)
  Future<void> sendBroadcastCommand(String sessionId, String key, int value) async {
    final channel = client.channel('session_$sessionId');
    
    await channel.sendBroadcastMessage(
      event: 'control_command',
      payload: {
        'sender_id': _clientId,
        key: value, 
        'ts': DateTime.now().millisecondsSinceEpoch
      },
    );
  }

  void leaveControlRoom() {
    _activeChannel?.unsubscribe();
    _activeChannel = null;
  }
}
