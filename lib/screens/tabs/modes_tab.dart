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
import 'package:velvet_sync/devices/models/toy_model.dart';

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

    final toy = ble.activeToy;
    final hasDevicePatterns = toy != null && toy.patternGroups.length >= 2 &&
        toy.patternGroups.every((g) => g.buttons.length >= 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ble.isDemoMode) _buildDemoBanner(ble),
        _buildInteractiveCard(ble),
        const SizedBox(height: 24),

        if (hasDevicePatterns)
          ..._buildDevicePatterns(ble, toy)
        else ...[
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
        if (toy != null) _buildSpecialControls(ble, toy),
      ],
    );
  }

  List<Widget> _buildDevicePatterns(BleService ble, ToyModel toy) {
    final hasDual = toy.hasDualChannel && toy.patternGroups.length >= 2;
    final ch1Group = toy.patternGroups[0];
    final ch2Group = hasDual ? toy.patternGroups[1] : null;

    return [
      if (ch2Group != null) ...[
        SectionLabel('CANAL 2 · ${ch2Group.name}'),
        const SizedBox(height: 16),
        ModeSelectorGrid(
          activeIndex: ble.activePatternCh2,
          defs: ch2Group.buttons.map((b) =>
            PatternDef(label: b.name, asset: '', fallback: Icons.grid_4x4)
          ).toList(),
          offset: 0,
          color: LvsColors.pink,
          onSelect: (i) => ble.setDevicePatternCh2(ch2Group.buttons[i], i),
        ),
        const SizedBox(height: 32),
      ],
      SectionLabel('CANAL 1 · ${ch1Group.name}'),
      const SizedBox(height: 16),
      ModeSelectorGrid(
        activeIndex: ble.activePatternCh1,
        defs: ch1Group.buttons.map((b) =>
          PatternDef(label: b.name, asset: '', fallback: Icons.grid_4x4)
        ).toList(),
        offset: 0,
        color: LvsColors.teal,
        onSelect: (i) => ble.setDevicePatternCh1(ch1Group.buttons[i], i),
      ),
      const SizedBox(height: 32),
    ];
  }

  Widget _buildSpecialControls(BleService ble, ToyModel toy) {
    final children = <Widget>[];

    // ── Heating ─────────────────────────────────────────────────
    if (toy.supports('heating')) {
      children.add(const SizedBox(height: 24));
      children.add(const SectionLabel('CALEFACCIÓN'));
      children.add(const SizedBox(height: 12));
      children.add(_SpecialToggleCard(
        title: 'CALEFACTOR',
        icon: Icons.thermostat,
        color: LvsColors.red,
        isActive: ble.heatingActive,
        onToggle: (on) => ble.setHeating(on),
        child: ble.heatingActive
            ? Column(
                children: [
                  const SizedBox(height: 12),
                  _LevelSlider(
                    label: 'NIVEL DE CALOR',
                    value: ble.heatingLevel / 255.0,
                    color: LvsColors.red,
                    onChanged: (v) => ble.setHeatingLevel((v * 255).round()),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ));
    }

    // ── Strike ─────────────────────────────────────────────────
    if (toy.supports('strike')) {
      children.add(const SizedBox(height: 24));
      children.add(const SectionLabel('GOLPETEO'));
      children.add(const SizedBox(height: 12));
      children.add(_SpecialToggleCard(
        title: 'MODO GOLPETEO',
        icon: Icons.splitscreen,
        color: LvsColors.amber,
        isActive: ble.strikeIndex >= 0,
        onToggle: (on) => on ? ble.setStrike(0) : ble.stopStrike(),
        child: ble.strikeIndex >= 0
            ? Column(
                children: [
                  const SizedBox(height: 12),
                  ModeSelectorGrid(
                    activeIndex: ble.strikeIndex,
                    defs: List.generate(6, (i) =>
                      PatternDef(label: 'PAT${i + 1}', asset: '', fallback: Icons.grid_4x4)
                    ),
                    offset: 0,
                    color: LvsColors.amber,
                    crossAxisCount: 3,
                    onSelect: (i) => ble.setStrike(i),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ));
    }

    // ── Suction ─────────────────────────────────────────────────
    if (toy.supports('suction') || toy.stimulationType.toLowerCase().contains('succión')) {
      children.add(const SizedBox(height: 24));
      children.add(const SectionLabel('SUCCIÓN'));
      children.add(const SizedBox(height: 12));
      children.add(_SpecialToggleCard(
        title: 'BOMBA DE SUCCIÓN',
        icon: Icons.cyclone,
        color: LvsColors.teal,
        isActive: ble.suctionActive,
        onToggle: (on) => ble.setSuction(on),
        child: ble.suctionActive
            ? Column(
                children: [
                  const SizedBox(height: 12),
                  _LevelSlider(
                    label: 'INTENSIDAD DE SUCCIÓN',
                    value: ble.suctionLevel / 255.0,
                    color: LvsColors.teal,
                    onChanged: (v) => ble.setSuctionLevel((v * 255).round()),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ));
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Column(children: children);
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
    final toy = ble.activeToy;
    final tiles = <Widget>[
      if (toy == null || toy.supports('game'))
        _GameTile(
          title: 'FRUTAS', icon: Icons.animation, color: LvsColors.teal,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalGameScreen())),
        ),
      if (toy == null || toy.supports('shake'))
        _GameTile(
          title: 'DADOS', icon: Icons.casino, color: LvsColors.amber,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiceScreen())),
        ),
      if (toy == null || toy.supports('shake'))
        _GameTile(
          title: 'RULETA', icon: Icons.timer, color: LvsColors.red,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RouletteScreen())),
        ),
      if (toy == null || toy.supports('finger'))
        _GameTile(
          title: 'LECTOR', icon: Icons.book, color: LvsColors.teal,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReaderScreen())),
        ),
      if (toy == null || toy.supports('explore'))
        _GameTile(
          title: 'COMPANION', icon: Icons.auto_awesome, color: LvsColors.pink,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanionScreen())),
        ),
      if (toy == null || toy.supports('kegel'))
        _GameTile(
          title: 'KEGEL', icon: Icons.fitness_center, color: LvsColors.amber,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KegelScreen())),
        ),
      if (toy == null || toy.supports('video'))
        _GameTile(
          title: 'VIDEO', icon: Icons.videocam, color: LvsColors.pink,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HapticVideoPlayerScreen())),
        ),
      if (toy == null || toy.supports('intera'))
        _GameTile(
          title: 'REMOTO', icon: Icons.sensors, color: LvsColors.teal,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemoteVideoSyncScreen(role: RemoteVideoRole.host))),
        ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.7,
      children: tiles,
    );
  }
}

// ── Widgets para controles especiales ─────────────────────────

class _SpecialToggleCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isActive;
  final ValueChanged<bool> onToggle;
  final Widget child;

  const _SpecialToggleCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.onToggle,
    required this.child,
  });

  @override
  State<_SpecialToggleCard> createState() => _SpecialToggleCardState();
}

class _SpecialToggleCardState extends State<_SpecialToggleCard> {
  @override
  Widget build(BuildContext context) {
    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: widget.color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.title, style: TextStyle(
                  color: widget.color, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1,
                )),
              ),
              Switch(
                value: widget.isActive,
                activeThumbColor: widget.color,
                onChanged: (v) => widget.onToggle(v),
              ),
            ],
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _LevelSlider extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  const _LevelSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: LvsColors.text3, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.arrow_downward, size: 14, color: LvsColors.text3),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: color,
                  inactiveTrackColor: color.withValues(alpha: 0.2),
                  thumbColor: color,
                  overlayColor: color.withValues(alpha: 0.1),
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                ),
                child: Slider(value: value, onChanged: onChanged),
              ),
            ),
            const Icon(Icons.arrow_upward, size: 14, color: LvsColors.text3),
          ],
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
