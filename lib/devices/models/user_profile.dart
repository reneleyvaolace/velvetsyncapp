// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/devices/models/user_profile.dart
// Modelo de datos para perfiles de usuario en la libreta de contactos
// ═══════════════════════════════════════════════════════════════

class UserProfile {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final DateTime? lastSeenAt;
  final bool isOnline;

  UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.lastSeenAt,
    this.isOnline = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? json['displayName']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString() ?? json['avatarUrl']?.toString(),
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'].toString())
          : null,
      isOnline: json['is_online'] == true || json['isOnline'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'last_seen_at': lastSeenAt?.toIso8601String(),
    'is_online': isOnline,
  };

  UserProfile copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    DateTime? lastSeenAt,
    bool? isOnline,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          id == other.id &&
          username == other.username;

  @override
  int get hashCode => Object.hash(id, username);

  @override
  String toString() => 'UserProfile(id: $id, username: $username)';
}
