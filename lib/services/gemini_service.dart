// ═══════════════════════════════════════════════════════════════
// LVS Control · lib/services/gemini_service.dart · v2.0.0
// Compañía Digital — Despacho correcto sin saturar el mutex BLE
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ble/ble_service.dart';
import '../ble/lvs_commands.dart';

class GeminiResponse {
  final String text;
  final int motor1;
  final int motor2;

  GeminiResponse(this.text, this.motor1, this.motor2);
}

class GeminiService {
  final BleService bleService;
  final SupabaseClient supabase = Supabase.instance.client;

  Timer? _autoStopTimer;

  GeminiService(this.bleService);

  Future<GeminiResponse> sendMessage(String text) async {
    try {
      final response = await supabase.functions.invoke(
        'gemini-proxy',
        body: {'prompt': text},
      );
      
      final Map<String, dynamic> data = response.data;
      final responseText = data['text'] ?? '';
      
      if (responseText.isEmpty) {
        return GeminiResponse('...', 0, 0);
      }
      return _parseHardwareTags(responseText);
    } catch (e) {
      debugPrint('❌ GeminiProxy Error: $e');
      return GeminiResponse('Mmm... cuéntame más... [H:60,80]', 60, 80);
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
