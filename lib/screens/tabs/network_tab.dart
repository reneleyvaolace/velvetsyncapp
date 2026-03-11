import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lvs_control/theme.dart';
import 'package:lvs_control/screens/remote_session_screen.dart';
import 'package:lvs_control/screens/catalog_screen.dart';
import 'package:lvs_control/services/supabase_service.dart';
import 'package:lvs_control/ble/ble_service.dart';

class NetworkTab extends ConsumerWidget {
  const NetworkTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 80,
          backgroundColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text('SERVICIOS REMOTOS', style: TextStyle(
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
              _buildCatalogCard(context),
              const SizedBox(height: 40),
              const CardGlass(
                child: Column(
                  children: [
                    Icon(Icons.security, color: LvsColors.teal, size: 32),
                    SizedBox(height: 12),
                    Text('CONEXIÓN ENCRIPTADA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    SizedBox(height: 8),
                    Text(
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
        onTap: () async {
          final supabase = ref.read(supabaseServiceProvider);
          final ble = ref.read(bleProvider);

          if (!ble.isConnected) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Conecta un dispositivo para iniciar sesión remota'))
            );
            return;
          }

          final session = await supabase.createSharedSession(ble.activeToy?.id ?? ble.toyProfile?.identifier ?? 'generic_lvs');
          if (session != null) {
            final sessionId = session['id'].toString();
            supabase.joinControlRoom(sessionId, (payload) {
              if (ble.isConnected) {
                final int ch1 = (payload['intensity_ch1'] ?? 0).toInt();
                final int ch2 = (payload['intensity_ch2'] ?? 0).toInt();
                ble.sendMultimediaSync(ch1, ch2);
              }
            });
            Navigator.push(context, MaterialPageRoute(builder: (_) => const RemoteSessionScreen()));
          }
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [LvsColors.bgCard, LvsColors.pink.withOpacity(0.1)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.public, color: LvsColors.pink, size: 40),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SESIÓN REMOTA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 4),
                    Text('Control mutuo a cualquier distancia.', style: TextStyle(color: LvsColors.text3, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogCard(BuildContext context) {
    return CardGlass(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogScreen())),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [LvsColors.bgCard, LvsColors.violet.withOpacity(0.1)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_stories, color: LvsColors.violet, size: 40),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CATÁLOGO LVS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 4),
                    Text('Descubre y profila nuevos dispositivos.', style: TextStyle(color: LvsColors.text3, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}
