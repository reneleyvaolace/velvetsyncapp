// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/backend/invitation_service.dart
// Servicio de invitaciones a sesiones entre contactos
//
// SQL Migration (ejecutar en Supabase SQL Editor):
// ═══════════════════════════════════════════════════════════════
// CREATE TABLE IF NOT EXISTS session_invites (
//   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
//   session_id TEXT NOT NULL,
//   from_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
//   to_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
//   access_token TEXT NOT NULL,
//   device_id TEXT NOT NULL DEFAULT '',
//   status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'expired')),
//   created_at TIMESTAMPTZ DEFAULT NOW()
// );
//
// CREATE INDEX IF NOT EXISTS idx_invites_to_user ON session_invites(to_user_id, status);
// CREATE INDEX IF NOT EXISTS idx_invites_from_user ON session_invites(from_user_id, status);
// ═══════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:velvet_sync/devices/models/session_invite.dart';
import 'package:velvet_sync/types/result_types.dart';
import 'package:velvet_sync/utils/logger.dart';

final invitationServiceProvider = Provider<InvitationService>((ref) {
  return InvitationService();
});

enum InvitationError {
  notAuthenticated,
  networkError,
  notFound,
  alreadyAccepted,
  unknown,
}

extension InvitationErrorExtension on InvitationError {
  String get message {
    switch (this) {
      case InvitationError.notAuthenticated:
        return 'Not authenticated';
      case InvitationError.networkError:
        return 'Network error';
      case InvitationError.notFound:
        return 'Invitation not found';
      case InvitationError.alreadyAccepted:
        return 'Invitation already accepted';
      case InvitationError.unknown:
        return 'Unknown error';
    }
  }
}

class InvitationService {
  SupabaseClient get _client => Supabase.instance.client;

  String? get _currentUserId => _client.auth.currentUser?.id;

  /// Send a session invitation to a contact
  Future<Result<SessionInvite, InvitationError>> sendInvite({
    required String sessionId,
    required String toUserId,
    required String accessToken,
    required String deviceId,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return const Failure(InvitationError.notAuthenticated);
    }

    try {
      final response = await _client.from('session_invites').insert({
        'session_id': sessionId,
        'from_user_id': currentUserId,
        'to_user_id': toUserId,
        'access_token': accessToken,
        'device_id': deviceId,
        'status': 'pending',
      }).select().single().timeout(const Duration(seconds: 10));

      return Success(SessionInvite.fromJson(response));
    } catch (e) {
      lvsLog('Error sending invite: $e', tag: 'INVITE');
      return const Failure(InvitationError.networkError);
    }
  }

  /// Get pending invitations for the current user
  Future<Result<List<SessionInvite>, InvitationError>> getPendingInvites() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return const Failure(InvitationError.notAuthenticated);
    }

    try {
      final response = await _client.from('session_invites')
          .select()
          .eq('to_user_id', currentUserId)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      final invites = (response as List).map((e) => SessionInvite.fromJson(e)).toList();
      return Success(invites);
    } catch (e) {
      lvsLog('Error getting pending invites: $e', tag: 'INVITE');
      return const Failure(InvitationError.networkError);
    }
  }

  /// Get sent invitations (from current user to others)
  Future<Result<List<SessionInvite>, InvitationError>> getSentInvites() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return const Failure(InvitationError.notAuthenticated);
    }

    try {
      final response = await _client.from('session_invites')
          .select()
          .eq('from_user_id', currentUserId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      final invites = (response as List).map((e) => SessionInvite.fromJson(e)).toList();
      return Success(invites);
    } catch (e) {
      lvsLog('Error getting sent invites: $e', tag: 'INVITE');
      return const Failure(InvitationError.networkError);
    }
  }

  /// Get invite by session ID (for the current user)
  Future<Result<SessionInvite?, InvitationError>> getInviteBySessionId(String sessionId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return const Failure(InvitationError.notAuthenticated);
    }

    try {
      final response = await _client.from('session_invites')
          .select()
          .eq('session_id', sessionId)
          .eq('to_user_id', currentUserId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (response == null) return const Success(null);
      return Success(SessionInvite.fromJson(response));
    } catch (e) {
      lvsLog('Error getting invite by session: $e', tag: 'INVITE');
      return const Failure(InvitationError.networkError);
    }
  }

  /// Accept an invitation
  Future<Result<SessionInvite, InvitationError>> acceptInvite(String inviteId) async {
    try {
      final response = await _client.from('session_invites')
          .update({'status': 'accepted'})
          .eq('id', inviteId)
          .eq('status', 'pending')
          .select()
          .single()
          .timeout(const Duration(seconds: 10));

      return Success(SessionInvite.fromJson(response));
    } catch (e) {
      lvsLog('Error accepting invite: $e', tag: 'INVITE');
      return const Failure(InvitationError.notFound);
    }
  }

  /// Reject an invitation
  Future<Result<SessionInvite, InvitationError>> rejectInvite(String inviteId) async {
    try {
      final response = await _client.from('session_invites')
          .update({'status': 'rejected'})
          .eq('id', inviteId)
          .eq('status', 'pending')
          .select()
          .single()
          .timeout(const Duration(seconds: 10));

      return Success(SessionInvite.fromJson(response));
    } catch (e) {
      lvsLog('Error rejecting invite: $e', tag: 'INVITE');
      return const Failure(InvitationError.notFound);
    }
  }

  /// Expire old pending invites for the current user
  Future<void> expireOldInvites() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    try {
      await _client.from('session_invites')
          .update({'status': 'expired'})
          .eq('to_user_id', currentUserId)
          .eq('status', 'pending')
          .lt('created_at', DateTime.now().subtract(const Duration(hours: 24)).toIso8601String())
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      lvsLog('Error expiring old invites: $e', tag: 'INVITE');
    }
  }
}
