// ════════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/calls/call_models.dart
// Modelos para Videollamadas (Agora + Firebase Firestore Signaling)
// ════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory CallModel.fromFirestore(Map<String, dynamic> data) {
    return CallModel(
      id: data['id'] as String,
      callerId: data['callerId'] as String,
      calleeId: data['calleeId'] as String,
      callerName: data['callerName'] as String? ?? 'Desconocido',
      calleeName: data['calleeName'] as String? ?? 'Desconocido',
      callerAvatar: data['callerAvatar'] as String?,
      calleeAvatar: data['calleeAvatar'] as String?,
      type: CallType.values.firstWhere(
        (e) => e.name == (data['type'] as String? ?? 'video'),
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
      startedAt: data['startedAt'] != null
          ? (data['startedAt'] as Timestamp).toDate()
          : null,
      endedAt: data['endedAt'] != null
          ? (data['endedAt'] as Timestamp).toDate()
          : null,
      channelName: data['channelName'] as String?,
      agoraToken: data['agoraToken'] as String?,
      errorMessage: data['errorMessage'] as String?,
      isMuted: data['isMuted'] as bool? ?? false,
      isVideoMuted: data['isVideoMuted'] as bool? ?? false,
      isSpeakerOn: data['isSpeakerOn'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'callerId': callerId,
      'calleeId': calleeId,
      'callerName': callerName,
      'calleeName': calleeName,
      'callerAvatar': callerAvatar,
      'calleeAvatar': calleeAvatar,
      'type': type.name,
      'direction': direction.name,
      'state': state.name,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'channelName': channelName,
      'agoraToken': agoraToken,
      'errorMessage': errorMessage,
      'isMuted': isMuted,
      'isVideoMuted': isVideoMuted,
      'isSpeakerOn': isSpeakerOn,
      'updatedAt': FieldValue.serverTimestamp(),
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
