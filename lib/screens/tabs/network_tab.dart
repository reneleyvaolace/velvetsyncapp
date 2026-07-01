import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/theme.dart';
import 'package:velvet_sync/screens/remote_session_screen.dart';
import 'package:velvet_sync/screens/contacts/contacts_screen.dart';

class NetworkTab extends ConsumerWidget {
  const NetworkTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverAppBar(
          expandedHeight: 80,
          backgroundColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            title: Text('SERVICIOS REMOTOS', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4, color: LvsColors.text3
            )),
            centerTitle: true,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildRemoteCard(context, ref),
              const SizedBox(height: 20),

              _buildContactsCard(context),
              const SizedBox(height: 40),
              CardGlass(
                child: Column(
                  children: [
                    const Icon(Icons.enhanced_encryption, size: 52, color: LvsColors.teal),
                    const SizedBox(height: 12),
                    const Text('CONEXIÓN ENCRIPTADA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    const Text(
                      'Todas las sesiones remotas utilizan cifrado de extremo a extremo y canales efímeros en tiempo real.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: LvsColors.text3),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildRemoteCard(BuildContext context, WidgetRef ref) {
    return CardGlass(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RemoteSessionScreen()),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [LvsColors.bgCard, LvsColors.pink.withValues(alpha: 0.1)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.public, color: LvsColors.pink, size: 40),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SESIÓN REMOTA', 
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 4),
                    Text('Control mutuo a cualquier distancia.', 
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: LvsColors.text3, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactsCard(BuildContext context) {
    return CardGlass(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ContactsScreen()),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [LvsColors.bgCard, LvsColors.pink.withValues(alpha: 0.1)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: LvsColors.pink.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.contacts, color: LvsColors.pink, size: 28),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CONTACTOS',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 4),
                    Text('Conecta con otros usuarios sin compartir tokens.',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: LvsColors.text3, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}
