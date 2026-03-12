// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/supabase_service.dart
// Integración con Supabase para Catálogo, Errores y Sigilo
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    
    const String url = 'https://wsgytnzigqlviqoktmdo.supabase.co';
    const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndzZ3l0bnppZ3Fsdmlxb2t0bWRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzMDk4NjQsImV4cCI6MjA3OTg4NTg2NH0.9Bp-bxWIEnsBEtXb1FaaNoxqRozTPnoYRInE8si8DjA';

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
      final response = await client.from('device_catalog').select().limit(limit);
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
      final response = await client
          .from('device_catalog')
          .select()
          .or('id.eq.$id,model_name.ilike.%$id%')
          .limit(1)
          .maybeSingle();
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

  // 3. Gestión de Errores (Bytemaster Lab)
  Future<String?> getTroubleshooting(String errorCode) async {
    if (!_isInitialized) return null;
    try {
      final data = await client
          .from('hardware_troubleshooting_steps')
          .select('steps')
          .eq('error_code', errorCode)
          .maybeSingle();
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
      
      final data = await client
          .from('stealth_policies')
          .select('max_intensity_cap')
          .filter('start_time', 'lte', timeStr)
          .filter('end_time', 'gte', timeStr)
          .maybeSingle();
      
      return data != null; // Si hay una política para esta hora, está activa.
    } catch (e) {
      return false;
    }
  }

  Future<double> getStealthIntensityCap() async {
    if (!_isInitialized) return 1.0;
    try {
      final now = DateTime.now();
      final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00";
      
      final data = await client
          .from('stealth_policies')
          .select('max_intensity_cap')
          .filter('start_time', 'lte', timeStr)
          .filter('end_time', 'gte', timeStr)
          .maybeSingle();
      
      if (data == null) return 1.0;
      return (data['max_intensity_cap'] as num).toDouble() / 100.0;
    } catch (e) {
      return 1.0;
    }
  }

  // 5. Sesiones Compartidas (Link Remoto)
  Future<Map<String, dynamic>?> fetchSessionByToken(String token) async {
    if (!_isInitialized) return null;
    try {
      // Consultar directamente la tabla base (la vista compartida fue eliminada en esta versión)
      final response = await client
          .from('shared_sessions')
          .select()
          .eq('access_token', token)
          .maybeSingle();
      
      return response;
    } catch (e) {
      debugPrint('❌ Error fetchSessionByToken: $e');
      return null;
    }
  }

  /// Crea una nueva sesión compartida en la DB y retorna sus datos (ID, Token)
  Future<Map<String, dynamic>?> createSharedSession(String deviceId) async {
    if (!_isInitialized) return null;
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
          throw e2; // Propagar el error para que la UI lo muestre
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
