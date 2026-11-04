// ════════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/calls/call_signaling.dart
// Signaling WebRTC via Firebase Firestore (migración desde Supabase Realtime)
// ════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:velvet_sync/services/calls/call_models.dart';
import 'package:velvet_sync/utils/logger.dart';

/// Servicio de señalización WebRTC usando Firebase Firestore
class CallSignalingService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _signalSubscription;
  StreamController<CallSignal>? _signalController;
  String? _currentCallId;
  String? _currentUserId;
  bool _isListening = false;

  /// Stream de señales entrantes
  Stream<CallSignal> get signalStream {
    _signalController ??= StreamController<CallSignal>.broadcast();
    return _signalController!.stream;
  }

  /// Inicializa el listener para una llamada específica
  Future<void> listenToCall(String callId, String currentUserId) async {
    if (_isListening && _currentCallId == callId) return;

    await _cleanup();

    _currentCallId = callId;
    _currentUserId = currentUserId;

    _signalSubscription = _firestore
        .collection('call_signals')
        .where('call_id', isEqualTo: callId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _handleSignal(change.doc.data());
        }
      }
    });

    _isListening = true;
    lvsLog('📡 Signaling escuchando call: $callId', tag: 'CALL_SIGNALING');
  }

  /// Maneja señal entrante
  void _handleSignal(Map<String, dynamic> record) {
    try {
      final signal = CallSignal.fromMap(record);

      // Ignorar señales propias
      if (signal.fromUserId == _currentUserId) return;

      lvsLog('📥 Señal recibida: ${signal.type.name} de ${signal.fromUserId}', tag: 'CALL_SIGNALING');

      _signalController?.add(signal);
    } catch (e) {
      lvsError('Error parseando señal: $e', tag: 'CALL_SIGNALING');
    }
  }

  /// Envía una señal
  Future<void> sendSignal({
    required String callId,
    required String toUserId,
    required SignalType type,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      final signal = {
        'call_id': callId,
        'from_user_id': currentUser.uid,
        'to_user_id': toUserId,
        'type': type.name,
        'payload': payload,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      };

      await _firestore.collection('call_signals').add(signal);

      lvsLog('📤 Señal enviada: ${type.name} a $callId', tag: 'CALL_SIGNALING');
    } catch (e) {
      lvsError('Error enviando señal: $e', tag: 'CALL_SIGNALING');
      rethrow;
    }
  }

  /// Envía offer SDP
  Future<void> sendOffer(String callId, String toUserId, String sdp) async {
    await sendSignal(
      callId: callId,
      toUserId: toUserId,
      type: SignalType.offer,
      payload: {'sdp': sdp, 'type': 'offer'},
    );
  }

  /// Envía answer SDP
  Future<void> sendAnswer(String callId, String toUserId, String sdp) async {
    await sendSignal(
      callId: callId,
      toUserId: toUserId,
      type: SignalType.answer,
      payload: {'sdp': sdp, 'type': 'answer'},
    );
  }

  /// Envía ICE candidate
  Future<void> sendIceCandidate(String callId, String toUserId, Map<String, dynamic> candidate) async {
    await sendSignal(
      callId: callId,
      toUserId: toUserId,
      type: SignalType.iceCandidate,
      payload: candidate,
    );
  }

  /// Acepta llamada entrante
  Future<void> acceptCall(String callId, String callerId) async {
    await sendSignal(
      callId: callId,
      toUserId: callerId,
      type: SignalType.callAccept,
      payload: {},
    );
  }

  /// Rechaza llamada
  Future<void> rejectCall(String callId, String callerId, {String? reason}) async {
    await sendSignal(
      callId: callId,
      toUserId: callerId,
      type: SignalType.callReject,
      payload: {'reason': reason ?? 'rejected'},
    );
  }

  /// Finaliza llamada
  Future<void> endCall(String callId, String otherUserId) async {
    await sendSignal(
      callId: callId,
      toUserId: otherUserId,
      type: SignalType.callEnd,
      payload: {},
    );
  }

  /// Cancela llamada saliente
  Future<void> cancelCall(String callId, String calleeId) async {
    await sendSignal(
      callId: callId,
      toUserId: calleeId,
      type: SignalType.callCancel,
      payload: {},
    );
  }

  /// Silencia/activa audio
  Future<void> setMuteAudio(String callId, String otherUserId, bool muted) async {
    await sendSignal(
      callId: callId,
      toUserId: otherUserId,
      type: SignalType.muteAudio,
      payload: {'muted': muted},
    );
  }

  /// Silencia/activa video
  Future<void> setMuteVideo(String callId, String otherUserId, bool muted) async {
    await sendSignal(
      callId: callId,
      toUserId: otherUserId,
      type: SignalType.muteVideo,
      payload: {'muted': muted},
    );
  }

  /// Cambia cámara
  Future<void> switchCamera(String callId, String otherUserId) async {
    await sendSignal(
      callId: callId,
      toUserId: otherUserId,
      type: SignalType.switchCamera,
      payload: {},
    );
  }

  /// Limpia recursos
  Future<void> _cleanup() async {
    _signalSubscription?.cancel();
    _signalSubscription = null;
    _isListening = false;
    _currentCallId = null;
  }

  /// Cierra el servicio
  Future<void> dispose() async {
    await _cleanup();
    await _signalController?.close();
    _signalController = null;
  }
}
