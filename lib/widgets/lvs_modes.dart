import 'package:flutter/material.dart';
import 'package:velvet_sync/theme.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';

// ── Canvas de Dibujo Táctil ──────────────────────────────────────
class LvsCanvas extends StatelessWidget {
  final BleService ble;
  const LvsCanvas({super.key, required this.ble});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LvsColors.pink.withOpacity(0.25)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gesture, color: LvsColors.text3, size: 32),
            SizedBox(height: 8),
            Text('Desliza para controlar', style: TextStyle(color: LvsColors.text3, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Definición de Patrones con íconos propios de la app ──────────
class _PatternDef {
  final String label;
  final String asset;       // PNG propio de la app
  final IconData fallback;  // Material icon de respaldo

  const _PatternDef({required this.label, required this.asset, required this.fallback});
}

// 10 patrones: índice 0 = MANUAL (stop), 1-9 = patrones BLE
const List<_PatternDef> kPatternDefs = [
  _PatternDef(label: 'MANUAL',   asset: 'assets/icons/icon_dual_motor.png',   fallback: Icons.tune),
  _PatternDef(label: 'SUAVE',    asset: 'assets/icons/icon_vibrator.png',     fallback: Icons.keyboard_arrow_up),
  _PatternDef(label: 'MEDIO',    asset: 'assets/icons/icon_intensity.png',    fallback: Icons.bolt),
  _PatternDef(label: 'FUERTE',   asset: 'assets/icons/icon_thrust.png',       fallback: Icons.rocket_launch),
  _PatternDef(label: 'OLA',      asset: 'assets/icons/icon_pulse_waves.png',  fallback: Icons.water),
  _PatternDef(label: 'PULSO',    asset: 'assets/icons/icon_sync_music.png',   fallback: Icons.graphic_eq),
  _PatternDef(label: 'RAMPA',    asset: 'assets/icons/icon_motion_control.png', fallback: Icons.trending_up),
  _PatternDef(label: 'LATIDO',   asset: 'assets/icons/icon_heart.png',        fallback: Icons.favorite),
  _PatternDef(label: 'CAOS',     asset: 'assets/icons/icon_custom_pattern.png', fallback: Icons.flash_on),
  _PatternDef(label: 'TORNADO',  asset: 'assets/icons/icon_cool_down.png',    fallback: Icons.cyclone),
];

// ── Selector de Patrones en Grid con íconos PNG de la app ────────
class PatternSelectorRow extends StatelessWidget {
  final int activePattern;
  final Color color;
  final Function(int) onSelect;

  const PatternSelectorRow({
    super.key,
    required this.activePattern,
    required this.color,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: List.generate(kPatternDefs.length, (index) => _PatternTile(
        index: index,
        def: kPatternDefs[index],
        isActive: activePattern == index,
        color: color,
        onTap: () => onSelect(index),
      )),
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
          color: isActive ? color.withOpacity(0.18) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color : Colors.white.withOpacity(0.08),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: color.withOpacity(0.30), blurRadius: 14, spreadRadius: 0)]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícono PNG de la app con fallback a Material icon
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

// ── Widget de ícono PNG con ColorFilter dinámico ─────────────────
class _AppIcon extends StatelessWidget {
  final String asset;
  final IconData fallback;
  final Color color;
  final bool active;

  const _AppIcon({required this.asset, required this.fallback, required this.color, required this.active});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Image.asset(
        asset,
        width: 34,
        height: 34,
        color: active ? color : LvsColors.text3,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (_, __, ___) => Icon(fallback, color: active ? color : LvsColors.text3, size: 28),
      ),
    );
  }
}

// ── Etiqueta de sección ──────────────────────────────────────────
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
