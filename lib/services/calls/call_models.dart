// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/calls/call_models.dart
// Modelos para Videollamadas (Agora + Supabase Signaling)
// ════════════════════════════════════════════════════════════════

import 'package:supabase_flutter/supabase_flutter.dart';

/// Tipo de llamada
enum CallType {
  video,
  voice,
}

/// Dirección de la llamada
enum CallDirection {
  incoming,
  outgoing,
}

/// Estado de la llamada
enum CallState {
  idle,
  connecting,
  ringing,
  connecting_remote,
  active,
  reconnecting,
  ended,
  failed,
  rejected,
  missed,
}

/// Modelo de una llamada
class CallModel {
  final String id;
  final String callerId;
  final String calleeId;
  final String callerName;
  final String calleeName;
  final String? callerAvatar;
  final String? calleeAvatar;
  final CallType type;
  final CallDirection direction;
  final CallState state;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? channelName;
  final String? agoraToken;
  final String? errorMessage;
  /// Estado de controles de la llamada
  final bool isMuted;
  final bool isVideoMuted;
  final bool isSpeakerOn;

  const CallModel({
    required this.id,
    required this.callerId,
    required this.calleeId,
    required this.callerName,
    required this.calleeName,
    this.callerAvatar,
    this.calleeAvatar,
    required this.type,
    required this.direction,
    required this.state,
    this.startedAt,
    this.endedAt,
    this.channelName,
    this.agoraToken,
    this.errorMessage,
    this.isMuted = false,
    this.isVideoMuted = false,
    this.isSpeakerOn = true,
  });

  factory CallModel.fromSupabase(Map<String, dynamic> data) {
    return CallModel(
      id: data['id'] as String,
      callerId: data['caller_id'] as String,
      calleeId: data['callee_id'] as String,
      callerName: data['caller_name'] as String? ?? 'Desconocido',
      calleeName: data['callee_name'] as String? ?? 'Desconocido',
      callerAvatar: data['caller_avatar'] as String?,
      calleeAvatar: data['callee_avatar'] as String?,
      type: CallType.values.firstWhere(
        (e) => e.name == (data['call_type'] as String? ?? 'video'),
        orElse: () => CallType.video,
      ),
      direction: CallDirection.values.firstWhere(
        (e) => e.name == (data['direction'] as String? ?? 'outgoing'),
        orElse: () => CallDirection.outgoing,
      ),
      state: CallState.values.firstWhere(
        (e) => e.name == (data['state'] as String? ?? 'idle'),
        orElse: () => CallState.idle,
      ),
      startedAt: data['started_at'] != null
          ? DateTime.parse(data['started_at'] as String)
          : null,
      endedAt: data['ended_at'] != null
          ? DateTime.parse(data['ended_at'] as String)
          : null,
      channelName: data['channel_name'] as String?,
      agoraToken: data['agora_token'] as String?,
      errorMessage: data['error_message'] as String?,
      isMuted: data['is_muted'] as bool? ?? false,
      isVideoMuted: data['is_video_muted'] as bool? ?? false,
      isSpeakerOn: data['is_speaker_on'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'caller_id': callerId,
      'callee_id': calleeId,
      'caller_name': callerName,
      'callee_name': calleeName,
      'caller_avatar': callerAvatar,
      'callee_avatar': calleeAvatar,
      'call_type': type.name,
      'direction': direction.name,
      'state': state.name,
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'channel_name': channelName,
      'agora_token': agoraToken,
      'error_message': errorMessage,
      'is_muted': isMuted,
      'is_video_muted': isVideoMuted,
      'is_speaker_on': isSpeakerOn,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  CallModel copyWith({
    String? id,
    String? callerId,
    String? calleeId,
    String? callerName,
    String? calleeName,
    String? callerAvatar,
    String? calleeAvatar,
    CallType? type,
    CallDirection? direction,
    CallState? state,
    DateTime? startedAt,
    DateTime? endedAt,
    String? channelName,
    String? agoraToken,
    String? errorMessage,
    bool? isMuted,
    bool? isVideoMuted,
    bool? isSpeakerOn,
  }) {
    return CallModel(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      calleeId: calleeId ?? this.calleeId,
      callerName: callerName ?? this.callerName,
      calleeName: calleeName ?? this.calleeName,
      callerAvatar: callerAvatar ?? this.callerAvatar,
      calleeAvatar: calleeAvatar ?? this.calleeAvatar,
      type: type ?? this.type,
      direction: direction ?? this.direction,
      state: state ?? this.state,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      channelName: channelName ?? this.channelName,
      agoraToken: agoraToken ?? this.agoraToken,
      errorMessage: errorMessage ?? this.errorMessage,
      isMuted: isMuted ?? this.isMuted,
      isVideoMuted: isVideoMuted ?? this.isVideoMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
    );
  }

  /// Duración de la llamada en segundos
  int get durationSeconds {
    if (startedAt == null) return 0;
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt!).inSeconds;
  }

  /// Formato legible de duración
  String get formattedDuration {
    final secs = durationSeconds;
    final mins = secs ~/ 60;
    final secsRem = secs % 60;
    return '${mins.toString().padLeft(2, '0')}:${secsRem.toString().padLeft(2, '0')}';
  }
}

/// Evento de señalización WebRTC
class CallSignal {
  final String callId;
  final String fromUserId;
  final String toUserId;
  final SignalType type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  const CallSignal({
    required this.callId,
    required this.fromUserId,
    required this.toUserId,
    required this.type,
    required this.payload,
    required this.timestamp,
  });

  factory CallSignal.fromMap(Map<String, dynamic> map) {
    return CallSignal(
      callId: map['call_id'] as String,
      fromUserId: map['from_user_id'] as String,
      toUserId: map['to_user_id'] as String,
      type: SignalType.values.firstWhere(
        (e) => e.name == (map['type'] as String),
        orElse: () => SignalType.unknown,
      ),
      payload: Map<String, dynamic>.from(map['payload'] as Map),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'call_id': callId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'type': type.name,
      'payload': payload,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Tipos de señales de señalización
enum SignalType {
  offer,
  answer,
  iceCandidate,
  callStart,
  callAccept,
  callReject,
  callEnd,
  callCancel,
  iceRestart,
  renegotiate,
  muteAudio,
  muteVideo,
  switchCamera,
  unknown,
}