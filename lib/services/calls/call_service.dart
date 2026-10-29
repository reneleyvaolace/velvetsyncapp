// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/calls/call_service.dart
// Servicio principal de Videollamadas (Agora + Supabase Signaling)
// ════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:velvet_sync/services/calls/call_models.dart';
import 'package:velvet_sync/services/calls/call_signaling.dart';
import 'package:velvet_sync/utils/logger.dart';

/// Servicio principal de videollamadas (Agora + Supabase Signaling)
class CallService {
  final CallSignalingService _signaling = CallSignalingService();
  final SupabaseClient _supabase = Supabase.instance.client;

  RtcEngine? _engine;
  String? _currentCallId;
  String? _localUid;
  String? _remoteUid;
  CallModel? _currentCall;
  StreamSubscription<CallSignal>? _signalSubscription;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isVideoMuted = false;
  bool _isSpeakerOn = true;

  /// Estado actual de la llamada
  CallModel? get currentCall => _currentCall;
  bool get isInCall => _currentCall != null && _currentCall!.state == CallState.active;
  bool get isMuted => _isMuted;
  bool get isVideoMuted => _isVideoMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  /// Stream de estado de la llamada
  final StreamController<CallModel> _callStateController = StreamController<CallModel>.broadcast();
  Stream<CallModel> get callStateStream => _callStateController.stream;

  /// Inicializa Agora RTC Engine
  Future<void> initialize(String appId) async {
    if (_isInitialized) return;

    try {
      // Solicitar permisos
      await _requestPermissions();

      // Crear engine
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: appId));

      // Configurar eventos
      _setupEventHandlers();

      // Configurar audio/video
      await _engine!.enableVideo();
      await _engine!.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 720, height: 1280),
          frameRate: 30,
          bitrate: 1500,
          orientationMode: OrientationMode.orientationModeAdaptive,
        ),
      );

      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard,
        scenario: AudioScenarioType.audioScenarioChatroom,
      );

      // Configurar audio route
      await _engine!.setEnableSpeakerphone(_isSpeakerOn);

      _isInitialized = true;
      lvsLog('✅ Agora RTC Engine inicializado', tag: 'CALL_SERVICE');
    } catch (e) {
      lvsError('Error inicializando Agora: $e', tag: 'CALL_SERVICE');
      rethrow;
    }
  }

  /// Solicita permisos de cámara y micrófono
  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    if (statuses[Permission.camera]!.isDenied ||
        statuses[Permission.microphone]!.isDenied) {
      throw Exception('Permisos de cámara/micrófono denegados');
    }
  }

  /// Configura handlers de eventos Agora
  void _setupEventHandlers() {
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          lvsLog('✅ Unido al canal: ${connection.channelId}', tag: 'CALL_SERVICE');
          _updateCallState(state: CallState.active);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          lvsLog('👤 Usuario remoto unido: $remoteUid', tag: 'CALL_SERVICE');
          _remoteUid = remoteUid.toString();
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          lvsLog('👋 Usuario remoto desconectado: $remoteUid ($reason)', tag: 'CALL_SERVICE');
          _remoteUid = null;
          if (_currentCall?.state == CallState.active) {
            _endCallLocally();
          }
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          lvsLog('🚪 Salió del canal', tag: 'CALL_SERVICE');
        },
        onError: (ErrorCodeType err, String msg) {
          lvsError('Agora Error: $err - $msg', tag: 'CALL_SERVICE');
        },
        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
          lvsLog('🔗 Estado conexión: $state ($reason)', tag: 'CALL_SERVICE');
        },
        onAudioVolumeIndication: (RtcConnection connection, List<AudioVolumeInfo> speakers, int totalVolume, int speakerNumber) {
          // Para indicador de volumen
        },
        onFirstRemoteVideoFrame: (RtcConnection connection, int remoteUid, int width, int height, int elapsed) {
          lvsLog('🎬 Primer frame video remoto: $remoteUid (${width}x$height)', tag: 'CALL_SERVICE');
        },
        onVideoSizeChanged: (RtcConnection connection, VideoSourceType sourceType, int uid, int width, int height, int rotation) {
          lvsLog('📐 Tamaño video cambiado: ${width}x$height', tag: 'CALL_SERVICE');
        },
        onNetworkQuality: (RtcConnection connection, int remoteUid, QualityType txQuality, QualityType rxQuality) {
          // Calidad de red
        },
        onConnectionLost: (RtcConnection connection) {
          lvsLog('🔴 Conexión perdida, reconectando...', tag: 'CALL_SERVICE');
          _updateCallState(state: CallState.reconnecting);
        },
        onRejoinChannelSuccess: (RtcConnection connection, int elapsed) {
          lvsLog('🔌 Reconexión exitosa', tag: 'CALL_SERVICE');
          _updateCallState(state: CallState.active);
        },
      ),
    );
  }

  /// Inicia llamada saliente
  Future<CallModel> startCall({
    required String calleeId,
    required String calleeName,
    String? calleeAvatar,
    CallType type = CallType.video,
  }) async {
    if (!_isInitialized) {
      throw Exception('CallService no inicializado');
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) throw Exception('Usuario no autenticado');

    // Obtener perfil del caller
    final profile = await _getCurrentUserProfile();

    final callId = 'call_${DateTime.now().millisecondsSinceEpoch}_${currentUser.id.substring(0, 8)}';
    final channelName = 'call_$callId';

    final call = CallModel(
      id: callId,
      callerId: currentUser.id,
      calleeId: calleeId,
      callerName: profile['username'] ?? 'Usuario',
      calleeName: calleeName,
      callerAvatar: profile['avatar_url'] as String?,
      calleeAvatar: calleeAvatar,
      type: type,
      direction: CallDirection.outgoing,
      state: CallState.connecting,
      channelName: channelName,
      startedAt: DateTime.now(),
    );

    _currentCall = call;
    _currentCallId = callId;
    _localUid = currentUser.id;

    // Crear registro en BD
    await _createCallRecord(call);

    // Iniciar signaling
    await _signaling.listenToCall(callId, currentUser.id);
    _subscribeToSignals();

    // Generar token Agora (usando token simple para desarrollo)
    final token = _generateToken(callId, currentUser.id);

    // Unirse al canal
    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: 0,
      options: ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );

    _updateCallState(state: CallState.connecting);

    // Enviar signal de inicio
    await _signaling.sendSignal(
      callId: callId,
      toUserId: calleeId,
      type: SignalType.callStart,
      payload: {
        'channel_name': channelName,
        'agora_token': token,
        'call_type': type.name,
      },
    );

    _updateCallState(state: CallState.ringing);

    lvsLog('📞 Llamada iniciada: $callId a $calleeId', tag: 'CALL_SERVICE');
    return _currentCall!;
  }

  /// Acepta llamada entrante
  Future<void> acceptCall(CallModel call) async {
    if (!_isInitialized) throw Exception('CallService no inicializado');

    _currentCall = call;
    _currentCallId = call.id;
    _localUid = Supabase.instance.client.auth.currentUser!.id;

    await _signaling.listenToCall(call.id!, Supabase.instance.client.auth.currentUser!.id);
    _subscribeToSignals();

    // Unirse al canal con token recibido
    await _engine!.joinChannel(
      token: call.agoraToken ?? _generateToken(call.id!, Supabase.instance.client.auth.currentUser!.id),
      channelId: call.channelName!,
      uid: 0,
      options: ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );

    _updateCallState(state: CallState.connecting);

    // Enviar accept
    await _signaling.acceptCall(call.id!, call.callerId);

    // Actualizar estado en BD
    await _updateCallRecord(call.id!, {'state': CallState.connecting.name, 'started_at': DateTime.now().toIso8601String()});

    lvsLog('✅ Llamada aceptada: ${call.id}', tag: 'CALL_SERVICE');
  }

  /// Rechaza llamada entrante
  Future<void> rejectCall(CallModel call, {String? reason}) async {
    await _signaling.rejectCall(call.id!, call.callerId, reason: reason);
    await _updateCallRecord(call.id!, {'state': CallState.rejected.name, 'ended_at': DateTime.now().toIso8601String(), 'error_message': reason});
    _cleanup();
  }

  /// Finaliza llamada activa
  Future<void> endCall() async {
    if (_currentCall == null) return;

    final otherUserId = _currentCall!.direction == CallDirection.outgoing
        ? _currentCall!.calleeId
        : _currentCall!.callerId;

    await _signaling.endCall(_currentCallId!, otherUserId);
    await _updateCallRecord(_currentCallId!, {'state': CallState.ended.name, 'ended_at': DateTime.now().toIso8601String()});
    
    await _engine!.leaveChannel();
    _cleanup();
  }

  /// Cancela llamada saliente (antes de ser contestada)
  Future<void> cancelCall() async {
    if (_currentCall == null || _currentCall!.direction != CallDirection.outgoing) return;

    await _signaling.cancelCall(_currentCallId!, _currentCall!.calleeId);
    await _updateCallRecord(_currentCallId!, {'state': CallState.ended.name, 'ended_at': DateTime.now().toIso8601String()});
    
    await _engine!.leaveChannel();
    _cleanup();
  }

  /// Alterna mute audio
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _engine!.muteLocalAudioStream(_isMuted);
    if (_currentCall != null) {
      final otherId = _currentCall!.direction == CallDirection.outgoing
          ? _currentCall!.calleeId
          : _currentCall!.callerId;
      await _signaling.setMuteAudio(_currentCallId!, otherId, _isMuted);
      _currentCall = _currentCall!.copyWith(isMuted: _isMuted);
      _callStateController.add(_currentCall!);
    }
  }

  /// Alterna mute video
  Future<void> toggleVideoMute() async {
    _isVideoMuted = !_isVideoMuted;
    await _engine!.muteLocalVideoStream(_isVideoMuted);
    if (_currentCall != null) {
      final otherId = _currentCall!.direction == CallDirection.outgoing
          ? _currentCall!.calleeId
          : _currentCall!.callerId;
      await _signaling.setMuteVideo(_currentCallId!, otherId, _isVideoMuted);
      _currentCall = _currentCall!.copyWith(isVideoMuted: _isVideoMuted);
      _callStateController.add(_currentCall!);
    }
  }

  /// Alterna altavoz
  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await _engine!.setEnableSpeakerphone(_isSpeakerOn);
    if (_currentCall != null) {
      _currentCall = _currentCall!.copyWith(isSpeakerOn: _isSpeakerOn);
      _callStateController.add(_currentCall!);
    }
  }

  /// Cambia cámara frontal/trasera
  Future<void> switchCamera() async {
    await _engine!.switchCamera();
    if (_currentCall != null) {
      final otherId = _currentCall!.direction == CallDirection.outgoing
          ? _currentCall!.calleeId
          : _currentCall!.callerId;
      await _signaling.switchCamera(_currentCallId!, otherId);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // MÉTODOS PRIVADOS
  // ═══════════════════════════════════════════════════════════════

  void _subscribeToSignals() {
    _signalSubscription?.cancel();
    _signalSubscription = _signaling.signalStream.listen(_handleSignal);
  }

  Future<void> _handleSignal(CallSignal signal) async {
    switch (signal.type) {
      case SignalType.offer:
        // TODO: Handle WebRTC offer if using hybrid
        break;
      case SignalType.answer:
        break;
      case SignalType.iceCandidate:
        break;
      case SignalType.callAccept:
        _updateCallState(state: CallState.connecting);
        break;
      case SignalType.callReject:
        _updateCallState(state: CallState.rejected, errorMessage: signal.payload['reason']);
        _cleanup();
        break;
      case SignalType.callEnd:
        _endCallLocally();
        break;
      case SignalType.callCancel:
        _updateCallState(state: CallState.ended);
        _cleanup();
        break;
      case SignalType.muteAudio:
        // Remote mute notification
        break;
      case SignalType.muteVideo:
        break;
      case SignalType.switchCamera:
        break;
      default:
        break;
    }
  }

  void _updateCallState({CallState? state, String? errorMessage}) {
    if (_currentCall == null) return;
    _currentCall = _currentCall!.copyWith(
      state: state,
      errorMessage: errorMessage,
      endedAt: (state == CallState.ended || state == CallState.rejected || state == CallState.failed) 
          ? DateTime.now() 
          : null,
      startedAt: state == CallState.active && _currentCall!.startedAt == null 
          ? DateTime.now() 
          : _currentCall!.startedAt,
    );
    _callStateController.add(_currentCall!);
  }

  void _endCallLocally() {
    if (_currentCall == null) return;
    _updateCallState(state: CallState.ended);
    _cleanup();
  }

  void _cleanup() {
    _signalSubscription?.cancel();
    _signalSubscription = null;
    _signaling.dispose();
    _currentCall = null;
    _currentCallId = null;
    _remoteUid = null;
  }

  Future<Map<String, dynamic>> _getCurrentUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return {};
    final data = await Supabase.instance.client
        .from('profiles')
        .select('username, avatar_url')
        .eq('id', user.id)
        .maybeSingle();
    return data ?? {};
  }

  Future<void> _createCallRecord(CallModel call) async {
    await _supabase.from('calls').insert(call.toSupabase());
  }

  Future<void> _updateCallRecord(String callId, Map<String, dynamic> updates) async {
    await _supabase.from('calls').update(updates).eq('id', callId);
  }

  String _generateToken(String channelName, String uid) {
    // TODO: Implementar generación de token real con Agora Dynamic Key
    // Para desarrollo: token temporal
    return '00000000000000000000000000000000';
  }

  /// Obtiene vista local (para preview)
  Widget? getLocalView() {
    if (!_isInitialized) return null;
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine!,
        canvas: VideoCanvas(uid: 0),
      ),
    );
  }

  /// Obtiene vista remota
  Widget? getRemoteView() {
    if (!_isInitialized || _remoteUid == null) return null;
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine!,
        canvas: VideoCanvas(uid: int.parse(_remoteUid!)),
        connection: RtcConnection(channelId: _currentCallId!),
      ),
    );
  }

  /// Limpieza completa
  Future<void> dispose() async {
    _callStateController.close();
    await _signaling.dispose();
    if (_engine != null) {
      await _engine!.leaveChannel();
      await _engine!.release();
      _engine = null;
    }
    _isInitialized = false;
  }
}