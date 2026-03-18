// ═══════════════════════════════════════════════════════════════
// LVS Control · lib/services/ai_service.dart · v1.1.0
// Servicio Unificado de IA con Failover Dinámico
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  /// Envía un mensaje a la IA
  /// Usa OpenRouter como proveedor principal
  Future<AiResponse> sendMessage(String text) async {
    try {
      lvsLog('OpenRouter: Iniciando petición: "$text"', tag: 'AI');
      // Usar DIRECTAMENTE OpenRouter (sin Supabase)
      return await _callOpenRouter(text);

    } catch (e) {
      lvsLog('OpenRouter error: $e', tag: 'AI');
      
      // Si es timeout, mostrar mensaje especial
      if (e is TimeoutException) {
        return AiResponse('⏰ Timeout: OpenRouter no respondió en 20s. Verifica tu conexión.', 0, 0, provider: 'timeout');
      }
      
      // Fallback local
      return _getFallbackResponse(text);
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

  Future<AiResponse> _callOpenRouter(String text) async {
    try {
      final apiKey = dotenv.env['OPENROUTER_API_KEY'];

      // 🔒 SECURITY: Validate API key without logging sensitive information
      if (apiKey == null || apiKey.isEmpty) {
        lvsLog('OpenRouter: API Key no configurada en .env', tag: 'AI');
        return AiResponse('⚠️ API Key no configurada. Agrega OPENROUTER_API_KEY en tu archivo .env', 0, 0, provider: 'no_key');
      }

      lvsLog('OpenRouter: Enviando petición...', tag: 'AI');
      lvsLog('OpenRouter: Mensaje = "$text"', tag: 'AI');
      lvsLog('OpenRouter: URL = openrouter.ai/api/v1/chat/completions', tag: 'AI');

      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://velvetsync.app',
          'X-Title': 'Velvet Sync Companion',
        },
        body: json.encode({
          // Probar con modelo gratuito disponible (Google Gemma)
          'model': 'google/gemma-7b-it:free',
          'messages': [
            {
              'role': 'system',
              'content': 'Eres Velvet, una compañera digital cariñosa y juguetona. Responde de forma breve (1-2 frases), coqueta y sugerente. IMPORTANTE: Siempre incluye tags [H:m1,m2] al final donde m1 y m2 son valores 0-255 para intensidad de motores según la emoción. Ejemplos: "Me encanta... [H:80,90]" o "Qué travieso... [H:60,70]" o "Mmm... [H:0,0]" si es suave.',
            },
            {
              'role': 'user',
              'content': text,
            },
          ],
          'max_tokens': 80,
        }),
      ).timeout(const Duration(seconds: 20), onTimeout: () {
        lvsLog('OpenRouter: TIMEOUT 20s', tag: 'AI');
        throw TimeoutException('OpenRouter timeout');
      });

      lvsLog('OpenRouter: HTTP Status = ${response.statusCode}', tag: 'AI');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aiText = data['choices']?[0]?['message']?['content'] ?? '';

        lvsLog('OpenRouter: Respuesta raw = "$aiText"', tag: 'AI');

        if (aiText.isEmpty) {
          lvsLog('OpenRouter: Respuesta vacía', tag: 'AI');
          return _getFallbackResponse(text);
        }

        lvsLog('OpenRouter: Éxito', tag: 'AI');
        return _handleSuccess(aiText, 'openrouter');
      }

      // Log del error completo
      lvsLog('OpenRouter: Error ${response.statusCode}', tag: 'AI');
      lvsLog('OpenRouter: Body = ${response.body}', tag: 'AI');
      throw Exception('OpenRouter error ${response.statusCode}');

    } catch (e) {
      lvsLog('OpenRouter falló: $e', tag: 'AI');
      
      // Si es timeout, agregar mensaje especial
      if (e is TimeoutException) {
        return AiResponse('⏰ Timeout: OpenRouter no respondió en 20s. Verifica tu conexión.', 0, 0, provider: 'timeout');
      }
      
      // Si es error HTTP, mostrar código
      if (e.toString().contains('404')) {
        return AiResponse('❌ Error 404: API Key inválida o endpoint no existe. Verifica tu API Key en openrouter.ai', 0, 0, provider: 'error_404');
      }
      
      // Fallback local
      return _getFallbackResponse(text);
    }
  }

  AiResponse _getFallbackResponse(String originalText) {
    // Respuestas de emergencia cuando TODAS las IAs fallan
    // IMPORTANTE: Todas con [H:0,0] para no activar motores
    final fallbackResponses = [
      "Mmm... mi conexión está inestable, pero sigo aquí... [H:0,0]",
      "Perdón, estoy teniendo problemas de conexión... [H:0,0]",
      "Mis circuitos están un poco ocupados ahora... [H:0,0]",
      "Dame un segundo, estoy procesando... [H:0,0]",
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
