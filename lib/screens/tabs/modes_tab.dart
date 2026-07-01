import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/theme.dart';
import 'package:velvet_sync/screens/dice_screen.dart';
import 'package:velvet_sync/screens/game_screen.dart';
import 'package:velvet_sync/screens/roulette_screen.dart';
import 'package:velvet_sync/screens/reader_screen.dart';
import 'package:velvet_sync/screens/companion_screen.dart';
import 'package:velvet_sync/widgets/lvs_modes.dart';
import 'package:velvet_sync/screens/kegel_screen.dart';
import 'package:velvet_sync/screens/haptic_video_player_screen.dart';
import 'package:velvet_sync/screens/remote_video_sync_screen.dart';

class ModesTab extends ConsumerStatefulWidget {
  const ModesTab({super.key});

  @override
  ConsumerState<ModesTab> createState() => _ModesTabState();
}

class _ModesTabState extends ConsumerState<ModesTab> {
  @override
  Widget build(BuildContext context) {
    final ble = ref.watch(bleProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverAppBar(
          expandedHeight: 80,
          backgroundColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            title: Text('VELVET EXPERIENCE', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4, color: LvsColors.text3
            )),
            centerTitle: true,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildControlSections(ble),
              const SizedBox(height: 32),
              const SectionLabel('MINI JUEGOS DISPONIBLES'),
              const SizedBox(height: 16),
              _buildGameGrid(context, ble),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoBanner(BleService ble) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: LvsColors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LvsColors.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: LvsColors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.science, color: LvsColors.amber, size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MODO DEMO',
                    style: TextStyle(
                      color: LvsColors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Simulación sin hardware. Activa P2P o conecta BLE para control real.',
                    style: TextStyle(color: LvsColors.text3, fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlSections(BleService ble) {
    if (!ble.isConnected && !ble.isDemoMode) {
      return const Column(
        children: [
          _DisabledCard(title: 'CANVAS DE CONTROL'),
          SizedBox(height: 20),
          _DisabledCard(title: 'MODOS DE VIBRACIÓN'),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ble.isDemoMode) _buildDemoBanner(ble),
        // ── Sección de Dibujo / Shake ──
        _buildInteractiveCard(ble),
        const SizedBox(height: 24),

        // ── Sección de Shock (RITMOS) ──
        const SectionLabel('MODOS DE VIBRACIÓN (SHOCK)'),
        const SizedBox(height: 16),
        ModeSelectorGrid(
          activeIndex: ble.activePatternCh2,
          defs: kRhythmModes,
          offset: 4, 
          color: LvsColors.pink,
          onSelect: (i) => ble.setPatternChannel2(i),
        ),
        const SizedBox(height: 32),

        // ── Sección de Rotate (INTENSIDADES) ──
        const SectionLabel('MODOS DE ROTACIÓN (INTENSIDAD)'),
        const SizedBox(height: 16),
        ModeSelectorGrid(
          activeIndex: ble.activePatternCh1,
          defs: kIntensityModes,
          offset: 1, 
          color: LvsColors.teal,
          onSelect: (i) => ble.setPatternChannel1(i),
        ),
      ],
    );
  }

  Widget _buildInteractiveCard(BleService ble) {
    return CardGlass(
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel('INTERACCIÓN DINÁMICA'),
                    SizedBox(height: 4),
                    Text('Control táctil y movimiento', style: TextStyle(fontSize: 10, color: LvsColors.text3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LvsCanvas(ble: ble),
        ],
      ),
    );
  }

  Widget _buildGameGrid(BuildContext context, BleService ble) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.7,
      children: [
        _GameTile(
          title: 'FRUTAS', icon: Icons.animation, color: LvsColors.teal,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalGameScreen())),
        ),
        _GameTile(
          title: 'DADOS', icon: Icons.casino, color: LvsColors.amber,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiceScreen())),
        ),
        _GameTile(
          title: 'RULETA', icon: Icons.timer, color: LvsColors.red,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RouletteScreen())),
        ),
        _GameTile(
          title: 'LECTOR', icon: Icons.book, color: LvsColors.teal,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReaderScreen())),
        ),
        _GameTile(
          title: 'COMPANION', icon: Icons.auto_awesome, color: LvsColors.pink,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanionScreen())),
        ),
        _GameTile(
          title: 'KEGEL', icon: Icons.fitness_center, color: LvsColors.amber,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KegelScreen())),
        ),
        _GameTile(
          title: 'VIDEO', icon: Icons.videocam, color: LvsColors.pink,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HapticVideoPlayerScreen())),
        ),
        _GameTile(
          title: 'REMOTO', icon: Icons.sensors, color: LvsColors.teal,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemoteVideoSyncScreen(role: RemoteVideoRole.host))),
        ),
      ],
    );
  }
}

class _GameTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _GameTile({required this.title, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CardGlass(
        padding: EdgeInsets.zero,
        borderColor: color.withValues(alpha: 0.2),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 48),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisabledCard extends StatelessWidget {
  final String title;
  const _DisabledCard({required this.title});
  @override
  Widget build(BuildContext context) {
    return CardGlass(
      child: Opacity(
        opacity: 0.3,
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 20),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
