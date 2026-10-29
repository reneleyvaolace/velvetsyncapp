// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/calls/call_controller.dart
// Riverpod Controller para Videollamadas
// ════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/calls/call_models.dart';
import 'package:velvet_sync/services/calls/call_service.dart';
import 'package:velvet_sync/utils/logger.dart';

/// Provider del servicio de llamadas
final callServiceProvider = Provider<CallService>((ref) {
  return CallService();
});

/// Provider del estado actual de la llamada
final callStateProvider = StreamProvider<CallModel?>((ref) {
  final service = ref.watch(callServiceProvider);
  return service.callStateStream;
});

/// Provider del estado de inicialización
final callInitializedProvider = StateProvider<bool>((ref) => false);

/// Controller principal de llamadas
class CallController {
  final Ref _ref;
  CallController(this._ref);

  /// Inicializa el servicio de llamadas
  Future<void> initialize() async {
    if (_ref.read(callInitializedProvider)) return;

    try {
      final service = _ref.read(callServiceProvider);
      
      // Obtener App ID de Agora desde env
      final appId = _getAgoraAppId();
      if (appId.isEmpty) {
        lvsLog('⚠️ Agora App ID no configurado', tag: 'CALL_CONTROLLER');
        return;
      }

      await service.initialize(appId);
      _ref.read(callInitializedProvider.notifier).state = true;
      
      lvsLog('✅ CallController inicializado', tag: 'CALL_CONTROLLER');
    } catch (e) {
      lvsError('Error inicializando CallController: $e', tag: 'CALL_CONTROLLER');
    }
  }

  String _getAgoraAppId() {
    // TODO: Obtener de env o config
    return ''; // TODO: Configurar Agora App ID
  }

  /// Inicia llamada saliente
  Future<CallModel?> startCall({
    required String calleeId,
    required String calleeName,
    String? calleeAvatar,
    CallType type = CallType.video,
  }) async {
    try {
      final service = _ref.read(callServiceProvider);
      final call = await service.startCall(
        calleeId: calleeId,
        calleeName: calleeName,
        calleeAvatar: calleeAvatar,
        type: type,
      );
      return call;
    } catch (e) {
      lvsError('Error iniciando llamada: $e', tag: 'CALL_CONTROLLER');
      rethrow;
    }
  }

  /// Acepta llamada entrante
  Future<void> acceptCall(CallModel call) async {
    try {
      final service = _ref.read(callServiceProvider);
      await service.acceptCall(call);
    } catch (e) {
      lvsError('Error aceptando llamada: $e', tag: 'CALL_CONTROLLER');
      rethrow;
    }
  }

  /// Rechaza llamada
  Future<void> rejectCall(CallModel call, {String? reason}) async {
    try {
      final service = _ref.read(callServiceProvider);
      await service.rejectCall(call, reason: reason);
    } catch (e) {
      lvsError('Error rechazando llamada: $e', tag: 'CALL_CONTROLLER');
      rethrow;
    }
  }

  /// Finaliza llamada activa
  Future<void> endCall() async {
    try {
      final service = _ref.read(callServiceProvider);
      await service.endCall();
    } catch (e) {
      lvsError('Error finalizando llamada: $e', tag: 'CALL_CONTROLLER');
    }
  }

  /// Cancela llamada saliente
  Future<void> cancelCall() async {
    try {
      final service = _ref.read(callServiceProvider);
      await service.cancelCall();
    } catch (e) {
      lvsError('Error cancelando llamada: $e', tag: 'CALL_CONTROLLER');
    }
  }

  /// Alterna mute audio
  Future<void> toggleMute() async {
    try {
      final service = _ref.read(callServiceProvider);
      await service.toggleMute();
    } catch (e) {
      lvsError('Error toggle mute: $e', tag: 'CALL_CONTROLLER');
    }
  }

  /// Alterna mute video
  Future<void> toggleVideoMute() async {
    try {
      final service = _ref.read(callServiceProvider);
      await service.toggleVideoMute();
    } catch (e) {
      lvsError('Error toggle video mute: $e', tag: 'CALL_CONTROLLER');
    }
  }

  /// Alterna altavoz
  Future<void> toggleSpeaker() async {
    try {
      final service = _ref.read(callServiceProvider);
      await service.toggleSpeaker();
    } catch (e) {
      lvsError('Error toggle speaker: $e', tag: 'CALL_CONTROLLER');
    }
  }

  /// Cambia cámara
  Future<void> switchCamera() async {
    try {
      final service = _ref.read(callServiceProvider);
      await service.switchCamera();
    } catch (e) {
      lvsError('Error switching camera: $e', tag: 'CALL_CONTROLLER');
    }
  }

  /// Obtiene vista local para preview
  Widget? getLocalView() {
    try {
      final service = _ref.read(callServiceProvider);
      return service.getLocalView();
    } catch (e) {
      return null;
    }
  }

  /// Obtiene vista remota
  Widget? getRemoteView() {
    try {
      final service = _ref.read(callServiceProvider);
      return service.getRemoteView();
    } catch (e) {
      return null;
    }
  }

  /// Limpieza completa
  Future<void> dispose() async {
    try {
      final service = _ref.read(callServiceProvider);
      await service.dispose();
      _ref.read(callInitializedProvider.notifier).state = false;
    } catch (e) {
      lvsError('Error dispose CallController: $e', tag: 'CALL_CONTROLLER');
    }
  }
}

/// Provider del controller
final callControllerProvider = Provider<CallController>((ref) {
  return CallController(ref);
});