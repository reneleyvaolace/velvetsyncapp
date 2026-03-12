// ═══════════════════════════════════════════════════════════════
// LVS Control · lib/services/ai_service.dart · v1.1.0
// Servicio Unificado de IA con Failover Dinámico
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ble/ble_service.dart';
import '../ble/lvs_commands.dart';
import '../utils/logger.dart';

class AiResponse {
  final String text;
  final int motor1;
  final int motor2;
  final String provider;

  AiResponse(this.text, this.motor1, this.motor2, {this.provider = 'unknown'});
}

class AiService {
  final BleService bleService;
  final SupabaseClient supabase = Supabase.instance.client;
  
  Timer? _autoStopTimer;

  AiService(this.bleService);

  /// Envía un mensaje a la IA principal (Supabase Edge Function)
  /// con failover automático a una respuesta predefinida si hay error.
  Future<AiResponse> sendMessage(String text) async {
    try {
      lvsLog('Iniciando petición IA: "$text"', tag: 'AI');
      
      // 1. Intentar con el Proxy de Supabase (Gemini)
      final response = await supabase.functions.invoke(
        'gemini-proxy',
        body: {'prompt': text},
      ).timeout(const Duration(seconds: 10));

      lvsLog('Respuesta IA recibida: ${response.data}', tag: 'AI');

      if (response.status == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        
        // ✨ Log extra para debuggear la estructura
        lvsLog('Data keys: ${data.keys.toList()}', tag: 'AI');
        
        final aiText = data['text'] ?? data['message'] ?? '';
        return _handleSuccess(aiText, 'supabase');
      }
      
      throw Exception('Status ${response.status}');
      
    } catch (e) {
      lvsLog('Failover AI Activado: $e', tag: 'AI');
      return _handleFailover(text);
    }
  }

  AiResponse _handleSuccess(String rawText, String provider) {
    final parsed = _parseHardwareTags(rawText);
    
    // Sincronización de hardware si está conectado
    if (bleService.isConnected) {
      _dispatchHardwareDual(parsed.motor1, parsed.motor2);
    }
    
    return AiResponse(parsed.text, parsed.motor1, parsed.motor2, provider: provider);
  }

  AiResponse _handleFailover(String originalText) {
    // Respuesta de emergencia "Offline" o "Failover"
    const fallbackText = "Parece que mi conexión está un poco inestable... pero aún puedo sentirte. [H:80,100]";
    final parsed = _parseHardwareTags(fallbackText);
    
    if (bleService.isConnected) {
      _dispatchHardwareDual(parsed.motor1, parsed.motor2);
    }
    
    return AiResponse(parsed.text, parsed.motor1, parsed.motor2, provider: 'failover_local');
  }

  /// Procesa tags [H:m1,m2] en el texto
  AiResponse _parseHardwareTags(String rawText) {
    final tagRegex = RegExp(r'\[H:(\d{1,3}),(\d{1,3})\]');
    final match = tagRegex.firstMatch(rawText);

    int m1 = 0;
    int m2 = 0;
    String cleanText = rawText;

    if (match != null) {
      m1 = int.parse(match.group(1)!).clamp(0, 255);
      m2 = int.parse(match.group(2)!).clamp(0, 255);
      cleanText = rawText.replaceAll(match.group(0)!, '').trim();
    }

    return AiResponse(cleanText, m1, m2);
  }

  /// Despacho eficiente usando el comando F6 (Dual Sincronizado)
  void _dispatchHardwareDual(int m1, int m2) {
    _autoStopTimer?.cancel();

    // Usar el nuevo comando F6 de LvsCommands
    bleService.writeCommand(
      LvsCommands.dualMotor(m1, m2),
      label: 'AI DUAL (F6)',
      silent: false,
    );

    // Auto-stop tras N segundos para seguridad
    final duration = _calcDuration(m1, m2);
    _autoStopTimer = Timer(Duration(seconds: duration), () {
      if (bleService.isConnected) {
        bleService.emergencyStop();
      }
    });
  }

  int _calcDuration(int m1, int m2) {
    final avg = (m1 + m2) / 2;
    if (avg >= 200) return 8;
    if (avg >= 100) return 10;
    return 12;
  }
}

final aiServiceProvider = Provider<AiService>((ref) {
  final ble = ref.watch(bleProvider);
  return AiService(ble);
});
