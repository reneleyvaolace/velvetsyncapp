import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lvs_control/ble/ble_service.dart';
import 'package:lvs_control/theme.dart';
import 'package:lvs_control/screens/dice_screen.dart';
import 'package:lvs_control/screens/roulette_screen.dart';
import 'package:lvs_control/screens/reader_screen.dart';
import 'package:lvs_control/screens/companion_screen.dart';
import 'package:lvs_control/screens/game_screen.dart';
import 'package:lvs_control/widgets/lvs_modes.dart';
import 'package:flutter/services.dart';

class ModesTab extends ConsumerStatefulWidget {
  const ModesTab({super.key});

  @override
  ConsumerState<ModesTab> createState() => _ModesTabState();
}

class _ModesTabState extends ConsumerState<ModesTab> {
  bool _shakeMode = false;

  @override
  Widget build(BuildContext context) {
    final ble = ref.read(bleProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 80,
          backgroundColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text('MODOS DE JUEGO', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4, color: LvsColors.text3
            )),
            centerTitle: true,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildCanvasCard(ble),
              const SizedBox(height: 20),
              _buildPatternsCard(ble),
              const SizedBox(height: 20),
              _buildGameGrid(context, ble),
              const SizedBox(height: 20),
              _buildShakeCard(ble),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildCanvasCard(BleService ble) {
    if (!ble.isConnected) return const _DisabledCard(title: 'CANVAS DE DIBUJO');
    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('CANVAS DE DIBUJO'),
          const SizedBox(height: 8),
          const Text('Control táctil dinámico (Empuje)', style: TextStyle(fontSize: 10, color: LvsColors.text3)),
          const SizedBox(height: 20),
          LvsCanvas(ble: ble),
        ],
      ),
    );
  }

  Widget _buildPatternsCard(BleService ble) {
    if (!ble.isConnected) return const _DisabledCard(title: 'RITMOS PREDISEÑADOS');
    final activePattern = ref.watch(bleProvider.select((p) => p.activePatternCh1));

    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('RITMOS PREDISEÑADOS'),
          const SizedBox(height: 20),
          PatternSelectorRow(
            activePattern: activePattern,
            color: LvsColors.violet,
            onSelect: (i) {
              if (i == 0) ble.setProportionalChannel1(0);
              else ble.setPatternChannel1(i);
            },
          ),
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
      childAspectRatio: 1.5,
      children: [
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
      ],
    );
  }

  Widget _buildShakeCard(BleService ble) {
    return CardGlass(
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MODO AGITAR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Control por movimiento', style: TextStyle(fontSize: 10, color: LvsColors.text3)),
              ],
            ),
          ),
          Switch(
            value: _shakeMode,
            onChanged: (v) => setState(() => _shakeMode = v),
            activeColor: LvsColors.pink,
          ),
        ],
      ),
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
        borderColor: color.withOpacity(0.2),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
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
