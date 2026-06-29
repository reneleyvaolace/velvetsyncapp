import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/backend/supabase_service.dart';
import 'package:velvet_sync/services/backend/contact_service.dart';
import 'package:velvet_sync/services/backend/invitation_service.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/devices/models/contact.dart';
import 'package:velvet_sync/devices/models/session_invite.dart';
import 'package:velvet_sync/screens/remote_session_screen.dart';
import 'package:velvet_sync/theme.dart';
import 'add_contact_screen.dart';
import 'contact_profile_screen.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  List<Contact> _contacts = [];
  List<SessionInvite> _pendingInvites = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    _error = null;

    try {
      final contactsResult = await ref.read(contactServiceProvider).getContacts();
      final invitesResult = await ref.read(invitationServiceProvider).getPendingInvites();

      if (mounted) {
        contactsResult.fold(
          (error) => setState(() { _error = error.message; _isLoading = false; }),
          (contacts) {
            invitesResult.fold(
              (_) => setState(() { _contacts = contacts; _pendingInvites = []; _isLoading = false; }),
              (invites) => setState(() { _contacts = contacts; _pendingInvites = invites; _isLoading = false; }),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _isLoading = false; });
      }
    }
  }

  Future<void> _iniciarSesion(Contact contact) async {
    final contactUserId = contact.contactUserId;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => const Center(child: CircularProgressIndicator(color: LvsColors.pink)),
    );

    try {
      final ble = ref.read(bleProvider);
      final deviceId = ble.activeToy?.id ?? ble.toyProfile?.identifier ?? 'generic_lvs';
      final supabase = ref.read(supabaseServiceProvider);
      final session = await supabase.createSharedSession(deviceId);

      if (mounted) Navigator.pop(context);

      if (session == null) {
        if (mounted) {
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
        toUserId: contactUserId,
        accessToken: accessToken,
        deviceId: deviceId,
      );

      if (mounted) {
        result.fold(
          (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al enviar invitación: ${error.message}')),
            );
          },
          (_) {
            _loadContacts();
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _acceptInvite(SessionInvite invite) async {
    final invites = ref.read(invitationServiceProvider);
    final result = await invites.acceptInvite(invite.id);

    if (mounted) {
      result.fold(
        (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${error.message}')),
          );
        },
        (_) {
          setState(() => _pendingInvites.removeWhere((i) => i.id == invite.id));
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RemoteSessionScreen(prefilledToken: invite.accessToken),
            ),
          );
        },
      );
    }
  }

  Future<void> _rejectInvite(SessionInvite invite) async {
    final invites = ref.read(invitationServiceProvider);
    await invites.rejectInvite(invite.id);
    if (mounted) {
      setState(() => _pendingInvites.removeWhere((i) => i.id == invite.id));
    }
  }

  void _showContactOptions(Contact contact) {
    final profile = contact.profile;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              if (profile != null) ...[
                CircleAvatar(
                  radius: 32,
                  backgroundColor: LvsColors.pink.withValues(alpha: 0.2),
                  child: Text(
                    profile.displayName.isNotEmpty
                        ? profile.displayName[0].toUpperCase()
                        : profile.username[0].toUpperCase(),
                    style: const TextStyle(
                      color: LvsColors.pink,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  profile.displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(
                  '@${profile.username}',
                  style: const TextStyle(color: LvsColors.text3, fontSize: 13),
                ),
                const SizedBox(height: 24),
              ],
              _optionButton(
                icon: Icons.settings_remote,
                label: 'INICIAR SESIÓN',
                color: LvsColors.teal,
                onTap: () {
                  Navigator.pop(ctx);
                  _iniciarSesion(contact);
                },
              ),
              const SizedBox(height: 8),
              _optionButton(
                icon: Icons.person_outline,
                label: 'VER PERFIL',
                color: LvsColors.text1,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContactProfileScreen(contact: contact),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _optionButton(
                icon: Icons.delete_outline,
                label: 'ELIMINAR',
                color: LvsColors.red,
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(contact);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: 0.2)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Contact contact) async {
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
          '¿Estás seguro de eliminar a ${contact.profile?.displayName ?? contact.contactUserId}?',
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
      try {
        final result = await ref.read(contactServiceProvider).removeContact(contact.id);
        if (mounted) {
          result.fold(
            (error) => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${error.message}')),
            ),
            (_) {
              setState(() => _contacts.removeWhere((c) => c.id == contact.id));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contacto eliminado')),
              );
            },
          );
        }
      } catch (e) {
        if (mounted) {
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
    return Scaffold(
      backgroundColor: LvsColors.bg,
      appBar: AppBar(
        title: const Text('CONTACTOS'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: LvsColors.pink),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddContactScreen()),
              );
              if (result == true) _loadContacts();
            },
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddContactScreen()),
          );
          if (result == true) _loadContacts();
        },
        backgroundColor: LvsColors.pink,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: LvsColors.pink));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: LvsColors.red, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Error al cargar contactos',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: LvsColors.text3, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadContacts,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('REINTENTAR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LvsColors.pink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_contacts.isEmpty && _pendingInvites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: LvsColors.bgCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: const Icon(Icons.people_outline, color: LvsColors.text3, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'No tienes contactos',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Añade contactos para iniciar sesiones remotas sin compartir tokens manualmente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: LvsColors.text3, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddContactScreen()),
                  );
                  if (result == true) _loadContacts();
                },
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('AÑADIR CONTACTO'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LvsColors.pink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hasInvites = _pendingInvites.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _loadContacts,
      color: LvsColors.pink,
      backgroundColor: LvsColors.bgCard,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _contacts.length + (hasInvites ? 1 : 0),
        itemBuilder: (context, index) {
          if (hasInvites && index == 0) {
            return _buildPendingInvitesSection();
          }
          final contactIndex = hasInvites ? index - 1 : index;
          return _buildContactTile(_contacts[contactIndex]);
        },
      ),
    );
  }

  Widget _buildPendingInvitesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 8, bottom: 12),
          child: Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: LvsColors.pink,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: LvsColors.pink, blurRadius: 6, spreadRadius: 1)],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'INVITACIONES (${_pendingInvites.length})',
                style: const TextStyle(
                  color: LvsColors.pink,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        ...(_pendingInvites.map((invite) => _buildInviteTile(invite))),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInviteTile(SessionInvite invite) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CardGlass(
        padding: const EdgeInsets.all(16),
        borderColor: LvsColors.pink.withValues(alpha: 0.3),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LvsColors.pink.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.settings_remote, color: LvsColors.pink, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Invitación de sesión',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Alguien quiere que controles su dispositivo',
                    style: TextStyle(color: LvsColors.text3.withValues(alpha: 0.8), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _rejectInvite(invite),
              style: TextButton.styleFrom(
                foregroundColor: LvsColors.text3,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('RECHAZAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ),
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: () => _acceptInvite(invite),
              style: ElevatedButton.styleFrom(
                backgroundColor: LvsColors.pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('ACEPTAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile(Contact contact) {
    final profile = contact.profile;
    final isOnline = profile?.isOnline == true;
    final initial = (profile?.displayName.isNotEmpty == true
            ? profile!.displayName[0]
            : profile?.username[0] ?? '?')
        .toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CardGlass(
        padding: const EdgeInsets.all(12),
        borderColor: isOnline ? LvsColors.teal.withValues(alpha: 0.2) : null,
        child: InkWell(
          onTap: () => _showContactOptions(contact),
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: LvsColors.bgCardH,
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: isOnline ? LvsColors.teal : LvsColors.text3,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 12, height: 12,
                        decoration: const BoxDecoration(
                          color: LvsColors.teal,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: LvsColors.teal, blurRadius: 6, spreadRadius: 1)],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (profile != null) ...[
                      Text(
                        profile.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${profile.username}',
                        style: const TextStyle(color: LvsColors.text3, fontSize: 12),
                      ),
                    ] else ...[
                      Text(
                        contact.contactUserId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      profile != null
                          ? _formatLastSeen(profile.lastSeenAt)
                          : 'Sin perfil',
                      style: TextStyle(
                        color: isOnline ? LvsColors.teal : LvsColors.text3,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.2),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
