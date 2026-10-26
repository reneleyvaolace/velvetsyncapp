// ═══════════════════════════════════════════════════════════════
// LVS Control · lib/services/ai_service.dart · v1.1.0
// Servicio Unificado de IA con Failover Dinámico
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:velvet_sync/config/env.dart';
import 'package:velvet_sync/services/ble/ble_service_platform.dart';
import 'package:velvet_sync/services/ble/lvs_commands.dart';
import 'package:velvet_sync/utils/logger.dart';

class AiResponse {
  final String text;
  final int motor1;
  final int motor2;
  final String provider;

  AiResponse(this.text, this.motor1, this.motor2, {this.provider = 'unknown'});
}

class AiService {
  final BleService bleService;

  Timer? _autoStopTimer;

  AiService(this.bleService);

  /// Envía un mensaje a la IA a través de la Edge Function `ai-proxy`.
  /// La clave de OpenRouter nunca sale del servidor.
  Future<AiResponse> sendMessage(String text) async {
    final message = text.trim();
    if (message.isEmpty) {
      return AiResponse('Escríbeme algo y te respondo... [H:0,0]', 0, 0, provider: 'local');
    }

    try {
      lvsLog('AI proxy: enviando ${message.length} caracteres', tag: 'AI');
      return await _callAiProxy(message);
    } on TimeoutException {
      lvsLog('AI proxy: timeout', tag: 'AI');
      return AiResponse(
        '⏰ La IA no respondió a tiempo. Intenta de nuevo. [H:0,0]',
        0,
        0,
        provider: 'timeout',
      );
    } on FunctionException catch (e) {
      // No registramos el cuerpo del error: puede contener detalles del proveedor.
      lvsLog('AI proxy: FunctionException (${e.status})', tag: 'AI');
      if (e.status == 429) {
        return AiResponse(
          'Estoy recibiendo muchos mensajes... dame un momento. [H:0,0]',
          0,
          0,
          provider: 'rate_limited',
        );
      }
      if (e.status == 401 || e.status == 403) {
        return AiResponse(
          '⚠️ Sesión no autorizada para usar la IA. [H:0,0]',
          0,
          0,
          provider: 'unauthorized',
        );
      }
      return _getFallbackResponse(message);
    } catch (e) {
      lvsLog('AI proxy error: ${e.runtimeType}', tag: 'AI');
      return _getFallbackResponse(message);
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

  Future<AiResponse> _callAiProxy(String text) async {
    if (!AppEnv.hasSupabase) {
      lvsLog('AI proxy: Supabase no configurado', tag: 'AI');
      return AiResponse(
        '⚠️ IA no configurada: falta SUPABASE_URL/SUPABASE_ANON_KEY. [H:0,0]',
        0,
        0,
        provider: 'offline',
      );
    }

    final response = await Supabase.instance.client.functions
        .invoke(
          AppEnv.aiProxyFunction,
          body: {'message': text},
        )
        .timeout(const Duration(seconds: 25));

    final data = response.data;
    final aiText = data is Map ? data['text']?.toString() : null;

    if (aiText == null || aiText.isEmpty) {
      lvsLog('AI proxy: respuesta vacía', tag: 'AI');
      return _getFallbackResponse(text);
    }

    lvsLog('AI proxy: respuesta OK (${aiText.length} caracteres)', tag: 'AI');
    return _handleSuccess(aiText, 'openrouter');
  }

  AiResponse _getFallbackResponse(String originalText) {
    // Respuestas de emergencia cuando TODAS las IAs fallan
    // IMPORTANTE: Todas con [H:0,0] para no activar motores
    final fallbackResponses = [
      'Mmm... mi conexión está inestable, pero sigo aquí... [H:0,0]',
      'Perdón, estoy teniendo problemas de conexión... [H:0,0]',
      'Mis circuitos están un poco ocupados ahora... [H:0,0]',
      'Dame un segundo, estoy procesando... [H:0,0]',
    ];

    final hash = originalText.length % fallbackResponses.length;
    final fallbackText = fallbackResponses[hash];
    final parsed = _parseHardwareTags(fallbackText);

    if (bleService.isConnected) {
      _dispatchHardwareDual(parsed.motor1, parsed.motor2);
    }

    return AiResponse(parsed.text, parsed.motor1, parsed.motor2, provider: 'fallback_local');
  }

  /// Procesa tags [H:m1,m2] en el texto
  AiResponse _parseHardwareTags(String rawText) {
    final tagRegex = RegExp(r'\[H:(\d{1,3}),(\d{1,3})\]');
    final match = tagRegex.firstMatch(rawText);

    var m1 = 0;
    var m2 = 0;
    var cleanText = rawText;

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
    lvsLog('Hardware: M1=$m1, M2=$m2, Duration=${duration}s', tag: 'AI');

    _autoStopTimer = Timer(Duration(seconds: duration), () {
      if (bleService.isConnected) {
        bleService.emergencyStop();
        lvsLog('Hardware: Auto-stop ejecutado', tag: 'AI');
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
