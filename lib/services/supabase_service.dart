// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/supabase_service.dart
// Integración con Supabase para Catálogo, Errores y Sigilo
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/toy_model.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

class SupabaseService {
  static bool _isInitialized = false;
  
  static const String thermMax80 = 'THERM_MAX_80';

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    
    if (url.isEmpty || anonKey.contains('TU_SUPABASE')) {
      debugPrint('⚠️ Supabase no configurado o clave placeholder detectada.');
      return;
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
    _isInitialized = true;
    debugPrint('✅ Supabase Inicializado: $url');
  }

  SupabaseClient get client => Supabase.instance.client;

  // 1. Mapeo de Hardware (device_catalog)
  Future<List<ToyModel>> fetchDeviceCatalog() async {
    if (!_isInitialized) return [];
    try {
      final response = await client.from('device_catalog').select();
      return (response as List).map((data) => ToyModel.fromSupabase(data)).toList();
    } catch (e) {
      debugPrint('❌ Error fetchCatalog: $e');
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
          .or('id.eq.$id,name.ilike.%$id%')
          .limit(1)
          .maybeSingle();
      if (response == null) {
        debugPrint('ℹ️ Supabase: No se encontró match para "$id"');
        return null;
      }
      debugPrint('✅ Supabase: Match encontrado para "$id" -> ${response['name']}');
      return ToyModel.fromSupabase(response);
    } catch (e) {
      debugPrint('❌ Error fetchDeviceById: $e');
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
  // 5. Sesiones Compartidas (Link Remoto)
  Future<Map<String, dynamic>?> fetchSessionByToken(String token) async {
    if (!_isInitialized) return null;
    try {
      final response = await client
          .from('shared_session_view')
          .select()
          .eq('access_token', token)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('❌ Error fetchSessionByToken: $e');
      return null;
    }
  }
}
