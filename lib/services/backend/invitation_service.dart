// ════════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/backend/invitation_service.dart
// Servicio de invitaciones con Firebase Firestore
// ════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/types/result_types.dart';
import 'package:velvet_sync/utils/logger.dart';

final invitationServiceProvider = Provider<InvitationService>((ref) {
  return InvitationService();
});

enum InvitationError {
  notFound,
  alreadyExists,
  invalidCode,
  networkError,
  notAuthenticated,
  unknown,
}

extension InvitationErrorExtension on InvitationError {
  String get message {
    switch (this) {
      case InvitationError.notFound:
        return 'Invitación no encontrada';
      case InvitationError.alreadyExists:
        return 'La invitación ya existe';
      case InvitationError.invalidCode:
        return 'Código de invitación inválido';
      case InvitationError.networkError:
        return 'Error de red, inténtalo nuevamente';
      case InvitationError.notAuthenticated:
        return 'Usuario no autenticado';
      case InvitationError.unknown:
        return 'Ocurrió un error desconocido';
    }
  }
}

class InvitationService extends ChangeNotifier {
  static final InvitationService _instance = InvitationService._internal();
  factory InvitationService() => _instance;
  InvitationService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Crear una invitación de sesión
  Future<Result<String, InvitationError>> createInvitation({
    required String sessionId,
    required String sessionName,
    required int expiresInMinutes,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return const Failure(InvitationError.notAuthenticated);
      }

      final code = _generateInvitationCode();
      final expiresAt = DateTime.now().add(Duration(minutes: expiresInMinutes));

      await _firestore.collection('session_invites').add({
        'session_id': sessionId,
        'session_name': sessionName,
        'code': code,
        'from_user_id': userId,
        'status': 'pending',
        'expires_at': expiresAt,
        'created_at': FieldValue.serverTimestamp(),
      });

      return Success(code);
    } catch (e) {
      lvsLog('Error creando invitación: $e', tag: 'INVITATION');
      return const Failure(InvitationError.networkError);
    }
  }

  /// Validar y aceptar una invitación por código
  Future<Result<Map<String, dynamic>, InvitationError>> acceptInvitation(
    String code,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('session_invites')
          .where('code', isEqualTo: code)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return const Failure(InvitationError.invalidCode);
      }

      final doc = snapshot.docs.first;
      final data = doc.data();

      // Verificar expiración
      final expiresAt = (data['expires_at'] as Timestamp?)?.toDate();
      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        await doc.reference.update({'status': 'expired'});
        return const Failure(InvitationError.invalidCode);
      }

      // Marcar como aceptada
      await doc.reference.update({
        'status': 'accepted',
        'accepted_at': FieldValue.serverTimestamp(),
      });

      return Success({
        'session_id': data['session_id'],
        'session_name': data['session_name'],
        'invite_id': doc.id,
      });
    } catch (e) {
      lvsLog('Error aceptando invitación: $e', tag: 'INVITATION');
      return const Failure(InvitationError.networkError);
    }
  }

  /// Generar código de invitación aleatorio
  String _generateInvitationCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final code = List.generate(8, (i) => chars[(DateTime.now().millisecond + i) % chars.length]).join();
    return code;
  }

  /// Obtener invitaciones pendientes del usuario
  Future<List<Map<String, dynamic>>> getPendingInvitations() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];

      final snapshot = await _firestore
          .collection('session_invites')
          .where('from_user_id', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      lvsLog('Error obteniendo invitaciones: $e', tag: 'INVITATION');
      return [];
    }
  }

  /// Alias para getPendingInvitations (compatibilidad)
  Future<List<Map<String, dynamic>>> getPendingInvites() async {
    return getPendingInvitations();
  }
}
