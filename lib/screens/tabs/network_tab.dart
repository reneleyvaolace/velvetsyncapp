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
              CardGlass(
                child: Column(
                  children: [
                    Image.asset('assets/icons/icon_encryption.png', width: 52, height: 52),
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
              colors: [LvsColors.bgCard, LvsColors.pink.withOpacity(0.1)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/icons/icon_remote_session.png', 
                width: 52, height: 52,
                errorBuilder: (_, __, ___) => const Icon(Icons.settings_remote, color: LvsColors.pink, size: 40),
              ),
              SizedBox(width: 20),
              Expanded(
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
          child: Row(
            children: [
              Image.asset(
                'assets/icons/icon_catalog.png', 
                width: 52, height: 52,
                errorBuilder: (_, __, ___) => const Icon(Icons.auto_stories, color: LvsColors.violet, size: 40),
              ),
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
