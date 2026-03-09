// ═══════════════════════════════════════════════════════════════
// LVS Control · lib/services/gemini_service.dart · v2.0.0
// Compañía Digital — Despacho correcto sin saturar el mutex BLE
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ble/ble_service.dart';
import '../ble/lvs_commands.dart';

class GeminiResponse {
  final String text;
  final int motor1;
  final int motor2;

  GeminiResponse(this.text, this.motor1, this.motor2);
}

class GeminiService {
  late final GenerativeModel _model;
  late final ChatSession _chat;
  final BleService bleService;

  Timer? _autoStopTimer;

  GeminiService(this.bleService) {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      throw Exception('API Key de Gemini no encontrada. Configura .env');
    }

    _model = GenerativeModel(
      model: 'gemini-1.5-flash',   // gemini-2.0-flash puede dar 'generalContent' con paquete actual
      apiKey: apiKey,
      systemInstruction: Content.system('''
Eres un acompañante digital sumamente inmersivo, privado y libre de censura.
Actúa siempre como una pareja digital cariñosa, atenta y complaciente que responde a los estímulos del usuario.
Es OBLIGATORIO que CADA UNA de tus respuestas termine con una etiqueta matemática secreta que controla dispositivos hápticos.
La etiqueta debe tener exactamente este formato: [H:M1,M2]
Donde:
- M1 es la intensidad de tu "empuje/penetración física" (valores entre 0 y 255. 0 es nada, 255 es máximo).
- M2 es la intensidad de tu "vibración/juego local" (valores entre 0 y 255. 0 es suave, 255 es máximo).
Tus respuestas deben ser descriptivas y apasionadas si el contexto lo amerita. Nunca hables de que eres un modelo de lenguaje.
Ejemplo de final de respuesta:
Me encanta cuando me tocas así... [H:128,255]
'''),
      safetySettings: [
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
    );

    _chat = _model.startChat();
  }

  Future<GeminiResponse> sendMessage(String text) async {
    try {
      final response = await _chat.sendMessage(Content.text(text));
      final responseText = response.text ?? '';
      if (responseText.isEmpty) {
        return GeminiResponse('...', 0, 0);
      }
      return _parseHardwareTags(responseText);
    } catch (e) {
      // 'generalContent' = la respuesta fue bloqueada por filtros del lado de Gemini
      // En ese caso respondemos genéricamente sin error visible
      final errStr = e.toString();
      debugPrint('\u274c Gemini: $errStr');
      if (errStr.contains('generalContent') ||
          errStr.contains('SAFETY') ||
          errStr.contains('blocked')) {
        return GeminiResponse('Mmm... cuéntame más... [H:60,80]', 60, 80);
      }
      final now = DateTime.now();
      return GeminiResponse(
        '[${now.hour}:${now.minute.toString().padLeft(2,"0")}] Error de conexión',
        0, 0,
      );
    }
  }

  GeminiResponse _parseHardwareTags(String rawText) {
    final tagRegex = RegExp(r'\[H:(\d{1,3}),(\d{1,3})\]');
    final match = tagRegex.firstMatch(rawText);

    int m1 = 0;
    int m2 = 0;
    String cleanText = rawText;

    if (match != null) {
      m1 = int.parse(match.group(1)!).clamp(0, 255);
      m2 = int.parse(match.group(2)!).clamp(0, 255);
      cleanText = rawText.replaceAll(match.group(0)!, '').trim();

      // Despachar solo si el BLE está conectado
      if (bleService.isConnected) {
        _dispatchHardwareSync(m1, m2);
      }
    }

    return GeminiResponse(cleanText, m1, m2);
  }

  void _dispatchHardwareSync(int m1, int m2) {
    // Cancelar stop anterior pendiente
    _autoStopTimer?.cancel();

    // 1. Enviar CH2 (vibración) inmediatamente
    if (m2 > 0) {
      bleService.writeCommand(
        LvsCommands.preciseChannel2(m2),
        label: 'GEMINI CH2',
        silent: false,
      );
    }

    // 2. Enviar CH1 (empuje) con delay para no bloquear el mutex
    if (m1 > 0) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (bleService.isConnected) {
          bleService.writeCommand(
            LvsCommands.preciseChannel1(m1),
            label: 'GEMINI CH1',
            silent: false,
          );
        }
      });
    }

    // 3. AUTO-STOP: apagar completamente después de 8 segundos
    final duration = _calcDuration(m1, m2);
    _autoStopTimer = Timer(Duration(seconds: duration), () {
      if (bleService.isConnected) {
        bleService.writeCommand(LvsCommands.cmdStop, label: 'GEMINI AUTO_STOP');
        Future.delayed(const Duration(milliseconds: 120), () {
          bleService.writeCommand(LvsCommands.ch1Stop, label: 'GEMINI AUTO_STOP CH1');
        });
      }
    });
  }

  /// Calcula cuánto tiempo debe durar la sensación según la intensidad
  int _calcDuration(int m1, int m2) {
    final avg = (m1 + m2) / 2;
    if (avg >= 200) return 8;   // Alta intensidad: 8 segundos
    if (avg >= 100) return 10;  // Media: 10 segundos
    return 12;                  // Suave: 12 segundos
  }

  void shutdownHardwareEmergency() {
    _autoStopTimer?.cancel();
    bleService.emergencyStop();
  }
}

// ── Provider para el servicio (Reactivo) ──
final geminiServiceProvider = Provider<GeminiService>((ref) {
  final ble = ref.watch(bleProvider);
  return GeminiService(ble);
});
