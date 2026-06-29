// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/devices/models/contact.dart
// Modelo de datos para contactos en la libreta de direcciones
// ═══════════════════════════════════════════════════════════════

import 'user_profile.dart';

class Contact {
  final String id;
  final String userId;
  final String contactUserId;
  final UserProfile? profile;
  final DateTime createdAt;
  final DateTime? lastSessionAt;

  Contact({
    required this.id,
    required this.userId,
    required this.contactUserId,
    this.profile,
    required this.createdAt,
    this.lastSessionAt,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      contactUserId: json['contact_user_id']?.toString() ?? json['contactUserId']?.toString() ?? '',
      profile: json['profile'] != null
          ? UserProfile.fromJson(json['profile'] is Map<String, dynamic>
              ? json['profile'] as Map<String, dynamic>
              : {})
          : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      lastSessionAt: json['last_session_at'] != null
          ? DateTime.tryParse(json['last_session_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'contact_user_id': contactUserId,
    'created_at': createdAt.toIso8601String(),
    'last_session_at': lastSessionAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Contact && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Contact(id: $id, contactUserId: $contactUserId)';
}
