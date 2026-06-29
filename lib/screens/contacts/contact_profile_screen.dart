import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/backend/supabase_service.dart';
import 'package:velvet_sync/services/backend/contact_service.dart';
import 'package:velvet_sync/services/backend/invitation_service.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/devices/models/contact.dart';
import 'package:velvet_sync/devices/models/user_profile.dart';
import 'package:velvet_sync/screens/remote_session_screen.dart';
import 'package:velvet_sync/theme.dart';

class ContactProfileScreen extends ConsumerStatefulWidget {
  final Contact contact;

  const ContactProfileScreen({super.key, required this.contact});

  @override
  ConsumerState<ContactProfileScreen> createState() => _ContactProfileScreenState();
}

class _ContactProfileScreenState extends ConsumerState<ContactProfileScreen> {
  bool _isRemoving = false;
  bool _isSendingInvite = false;

  Future<void> _iniciarSesion() async {
    setState(() => _isSendingInvite = true);
    try {
      final ble = ref.read(bleProvider);
      final deviceId = ble.activeToy?.id ?? ble.toyProfile?.identifier ?? 'generic_lvs';
      final supabase = ref.read(supabaseServiceProvider);
      final session = await supabase.createSharedSession(deviceId);

      if (session == null) {
        if (mounted) {
          setState(() => _isSendingInvite = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al crear la sesión')),
          );
        }
        return;
      }

      final sessionId = session['id']?.toString() ?? '';
      final accessToken = session['access_token']?.toString() ?? '';

      final invites = ref.read(invitationServiceProvider);
      final result = await invites.sendInvite(
        sessionId: sessionId,
        toUserId: widget.contact.contactUserId,
        accessToken: accessToken,
        deviceId: deviceId,
      );

      if (mounted) {
        setState(() => _isSendingInvite = false);
        result.fold(
          (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al enviar invitación: ${error.message}')),
            );
          },
          (_) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RemoteSessionScreen(initialSessionData: session),
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingInvite = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _removeContact() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: LvsColors.red.withValues(alpha: 0.2)),
        ),
        title: const Text(
          'ELIMINAR CONTACTO',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
        ),
        content: Text(
          '¿Estás seguro de eliminar a ${widget.contact.profile?.displayName ?? widget.contact.contactUserId}?',
          textAlign: TextAlign.center,
          style: const TextStyle(color: LvsColors.text3, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR', style: TextStyle(color: LvsColors.text3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ELIMINAR', style: TextStyle(color: LvsColors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isRemoving = true);
      try {
        final result = await ref.read(contactServiceProvider).removeContact(widget.contact.id);
        if (mounted) {
          result.fold(
            (error) {
              setState(() => _isRemoving = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${error.message}')),
              );
            },
            (_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contacto eliminado')),
              );
              Navigator.pop(context, true);
            },
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isRemoving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  String _formatLastSeen(DateTime? lastSeenAt) {
    if (lastSeenAt == null) return 'Desconocido';
    final diff = DateTime.now().difference(lastSeenAt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Visto hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Visto hace ${diff.inHours}h';
    return 'Visto hace ${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.contact.profile;
    final isOnline = profile?.isOnline == true;
    final initial = (profile?.displayName.isNotEmpty == true
            ? profile!.displayName[0]
            : profile?.username[0] ?? '?')
        .toUpperCase();

    return Scaffold(
      backgroundColor: LvsColors.bg,
      appBar: AppBar(
        title: Text(profile?.username ?? 'CONTACTO'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
          child: Column(
            children: [
              _buildProfileInfo(initial, profile, isOnline),
              const SizedBox(height: 40),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfo(String initial, UserProfile? profile, bool isOnline) {
    return CardGlass(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: LvsColors.pink.withValues(alpha: 0.15),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: LvsColors.pink,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (isOnline)
                Positioned(
                  bottom: 4, right: 4,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(
                      color: LvsColors.teal,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: LvsColors.teal, blurRadius: 8, spreadRadius: 2)],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (profile != null) ...[
            Text(
              profile.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '@${profile.username}',
              style: const TextStyle(color: LvsColors.text3, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isOnline
                    ? LvsColors.teal.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isOnline
                      ? LvsColors.teal.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Text(
                isOnline ? 'En línea' : _formatLastSeen(profile.lastSeenAt),
                style: TextStyle(
                  color: isOnline ? LvsColors.teal : LvsColors.text3,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ] else ...[
            Text(
              'Usuario #${widget.contact.contactUserId}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: const Text(
                'Sin perfil disponible',
                style: TextStyle(color: LvsColors.text3, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isSendingInvite ? null : _iniciarSesion,
            icon: _isSendingInvite
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.settings_remote, size: 20),
            label: const Text(
              'INICIAR SESIÓN',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: LvsColors.teal,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _isRemoving ? null : _removeContact,
            icon: _isRemoving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: LvsColors.red),
                  )
                : const Icon(Icons.delete_outline, size: 20),
            label: const Text(
              'ELIMINAR CONTACTO',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: LvsColors.red,
              side: BorderSide(color: LvsColors.red.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }
}
