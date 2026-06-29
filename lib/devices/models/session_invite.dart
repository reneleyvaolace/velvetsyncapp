class SessionInvite {
  final String id;
  final String sessionId;
  final String fromUserId;
  final String toUserId;
  final String accessToken;
  final String deviceId;
  final String status;
  final DateTime createdAt;

  SessionInvite({
    required this.id,
    required this.sessionId,
    required this.fromUserId,
    required this.toUserId,
    required this.accessToken,
    required this.deviceId,
    required this.status,
    required this.createdAt,
  });

  factory SessionInvite.fromJson(Map<String, dynamic> json) {
    return SessionInvite(
      id: json['id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      fromUserId: json['from_user_id']?.toString() ?? '',
      toUserId: json['to_user_id']?.toString() ?? '',
      accessToken: json['access_token']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'from_user_id': fromUserId,
    'to_user_id': toUserId,
    'access_token': accessToken,
    'device_id': deviceId,
    'status': status,
  };

  bool get isPending => status == 'pending';
}
