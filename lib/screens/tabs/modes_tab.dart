import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/theme.dart' hide SectionLabel;
import 'package:velvet_sync/screens/dice_screen.dart';
import 'package:velvet_sync/screens/placeholder_screens.dart';
import 'package:velvet_sync/screens/game_screen.dart';
import 'package:velvet_sync/widgets/lvs_modes.dart';
import 'package:velvet_sync/screens/kegel_screen.dart';

class ModesTab extends ConsumerStatefulWidget {
  const ModesTab({super.key});

  @override
  ConsumerState<ModesTab> createState() => _ModesTabState();
}

class _ModesTabState extends ConsumerState<ModesTab> {
  bool _shakeMode = false;

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

  Widget _buildControlSections(BleService ble) {
    if (!ble.isConnected) {
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
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel('INTERACCIÓN DINÁMICA'),
                    SizedBox(height: 4),
                    Text('Control táctil y movimiento', style: TextStyle(fontSize: 10, color: LvsColors.text3)),
                  ],
                ),
              ),
              Switch(
                value: _shakeMode,
                onChanged: (v) => setState(() => _shakeMode = v),
                activeTrackColor: LvsColors.pink,
              ),
              const Text('AGITAR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
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
          assetPath: 'assets/icons/icon_fruit_game.png',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalGameScreen())),
        ),
        _GameTile(
          title: 'DADOS', icon: Icons.casino, color: LvsColors.amber,
          assetPath: 'assets/icons/icon_tab_games.png',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiceScreen())),
        ),
        _GameTile(
          title: 'RULETA', icon: Icons.timer, color: LvsColors.red,
          assetPath: 'assets/icons/icon_game_roulette.png',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RouletteScreen())),
        ),
        _GameTile(
          title: 'LECTOR', icon: Icons.book, color: LvsColors.teal,
          assetPath: 'assets/icons/icon_reading_section.png',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReaderScreen())),
        ),
        _GameTile(
          title: 'COMPANION', icon: Icons.auto_awesome, color: LvsColors.pink,
          assetPath: 'assets/icons/icon_ai_assistant.png',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanionScreen())),
        ),
        _GameTile(
          title: 'KEGEL', icon: Icons.fitness_center, color: LvsColors.amber,
          assetPath: 'assets/icons/icon_kegel.png',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KegelScreen())),
        ),
      ],
    );
  }
}

class _GameTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? assetPath;
  final Color color;
  final VoidCallback onTap;
  const _GameTile({required this.title, required this.icon, this.assetPath, required this.color, required this.onTap});
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
              assetPath != null
                ? SizedBox(
                    width: 132,
                    height: 132,
                    child: ClipRect(
                      child: Transform.scale(
                        scale: 1.15, 
                        child: Image.asset(assetPath!, fit: BoxFit.cover),
                      ),
                    ),
                  )
                : Icon(icon, color: color, size: 132),
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
