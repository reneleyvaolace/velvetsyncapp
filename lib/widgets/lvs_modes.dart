import 'package:flutter/material.dart';
import 'package:velvet_sync/theme.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';

// ── Definición de Patrones ──────────────────────────────────────────
class _PatternDef {
  final String label;
  final String asset;       
  final IconData fallback;  

  const _PatternDef({required this.label, required this.asset, required this.fallback});
}

// ── Modos de Intensidad (Para el motor de rotación/constante) ────────
const List<_PatternDef> _kIntensityDefs = [
  _PatternDef(label: 'BAJO',   asset: 'assets/icons/icon_intensity.png',       fallback: Icons.keyboard_arrow_up),
  _PatternDef(label: 'MEDIO',  asset: 'assets/icons/icon_thrust.png',          fallback: Icons.bolt),
  _PatternDef(label: 'FUERTE', asset: 'assets/icons/icon_dual_motor.png',      fallback: Icons.rocket_launch),
];

// ── Modos de Ritmo (Shock/Vibración 1-9) ───────────────────────────
const List<_PatternDef> _kRhythmDefs = [
  _PatternDef(label: 'PULSO',   asset: 'assets/icons/icon_sync_music.png',     fallback: Icons.favorite),
  _PatternDef(label: 'OLA',     asset: 'assets/icons/icon_pulse_waves.png',    fallback: Icons.water),
  _PatternDef(label: 'RAMPA',   asset: 'assets/icons/icon_vibrator.png',       fallback: Icons.graphic_eq),
  _PatternDef(label: 'FLIP',    asset: 'assets/icons/icon_dual_motor.png',     fallback: Icons.gesture),
  _PatternDef(label: 'STORM',   asset: 'assets/icons/icon_cool_down.png',      fallback: Icons.cyclone),
  _PatternDef(label: 'CHAOS',   asset: 'assets/icons/icon_custom_pattern.png', fallback: Icons.crisis_alert),
  _PatternDef(label: 'BALA',    asset: 'assets/icons/icon_bullet.png',         fallback: Icons.adjust),
  _PatternDef(label: 'CONTROL', asset: 'assets/icons/icon_motion_control.png', fallback: Icons.tune),
  _PatternDef(label: 'HEART',   asset: 'assets/icons/icon_heart.png',          fallback: Icons.favorite),
];

// ── Grilla de Selección de Modos ───────────────────────────────────
class ModeSelectorGrid extends StatelessWidget {
  final int? activeIndex;
  final List<_PatternDef> defs;
  final int offset; // Para mapear el índice al comando correcto
  final Color color;
  final Function(int) onSelect;
  final int crossAxisCount;

  const ModeSelectorGrid({
    super.key,
    required this.activeIndex,
    required this.defs,
    required this.onSelect,
    this.offset = 0,
    this.color = LvsColors.violet,
    this.crossAxisCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: List.generate(defs.length, (index) {
        final realIndex = index + offset;
        return _PatternTile(
          index: realIndex,
          def: defs[index],
          isActive: activeIndex == realIndex,
          color: color,
          onTap: () => onSelect(realIndex),
        );
      }),
    );
  }
}

// ── Canvas de Dibujo Táctil ──────────────────────────────────────
class LvsCanvas extends StatelessWidget {
  final BleService ble;
  const LvsCanvas({super.key, required this.ble});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LvsColors.pink.withValues(alpha: 0.25)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gesture, color: LvsColors.text3, size: 32),
            SizedBox(height: 8),
            Text('Desliza para controlar intensidad', style: TextStyle(color: LvsColors.text3, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Tile individual de patrón ────────────────────────────────────
class _PatternTile extends StatelessWidget {
  final int index;
  final _PatternDef def;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _PatternTile({
    required this.index,
    required this.def,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color : Colors.white.withValues(alpha: 0.08),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AppIcon(asset: def.asset, fallback: def.fallback, color: color, active: isActive),
            const SizedBox(height: 6),
            Text(
              def.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: isActive ? Colors.white : LvsColors.text1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final String asset;
  final IconData fallback;
  final Color color;
  final bool active;

  const _AppIcon({required this.asset, required this.fallback, required this.color, required this.active});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Image.asset(
        asset,
        width: 32,
        height: 32,
        color: active ? color : LvsColors.text3,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (_, __, ___) => Icon(fallback, color: active ? color : LvsColors.text3, size: 24),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
        color: LvsColors.text3,
      ),
    );
  }
}

// Exportar listas para uso externo
const kIntensityModes = _kIntensityDefs;
const kRhythmModes = _kRhythmDefs;
