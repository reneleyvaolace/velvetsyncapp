import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:velvet_sync/theme.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';

// ── Definición de Patrones ──────────────────────────────────────────
class _PatternDef {
  final String label;
  final String asset;       
  final IconData fallback;  

  const _PatternDef({required this.label, required this.asset, required this.fallback});
}

// ── Modos de Intensidad (Canal de Empuje/Rotación) ────────
const List<_PatternDef> _kIntensityDefs = [
  _PatternDef(label: 'BAJO',   asset: 'assets/icons/icon_intensity.png',       fallback: Icons.keyboard_arrow_up),
  _PatternDef(label: 'MEDIO',  asset: 'assets/icons/icon_heart.png',           fallback: Icons.bolt),
  _PatternDef(label: 'FUERTE', asset: 'assets/icons/icon_thrust.png',          fallback: Icons.rocket_launch),
];

// ── Modos de Ritmo (Canal de Vibración/Patrones) ───────────────────────────
const List<_PatternDef> _kRhythmDefs = [
  _PatternDef(label: 'PULSO',   asset: 'assets/icons/icon_sync_music.png',     fallback: Icons.favorite),
  _PatternDef(label: 'OLA',     asset: 'assets/icons/icon_pulse_waves.png',    fallback: Icons.water),
  _PatternDef(label: 'RAMPA',   asset: 'assets/icons/icon_motion_control.png', fallback: Icons.graphic_eq),
  _PatternDef(label: 'FLIP',    asset: 'assets/icons/icon_dual_motor.png',     fallback: Icons.gesture),
  _PatternDef(label: 'STORM',   asset: 'assets/icons/icon_cool_down.png',      fallback: Icons.cyclone),
  _PatternDef(label: 'CHAOS',   asset: 'assets/icons/icon_custom_pattern.png', fallback: Icons.crisis_alert),
  _PatternDef(label: 'SURF',    asset: 'assets/icons/icon_vibrator.png',       fallback: Icons.water), 
  _PatternDef(label: 'VOLCAN',  asset: 'assets/icons/icon_thrust.png',         fallback: Icons.volcano),
  _PatternDef(label: 'LATIDO',  asset: 'assets/icons/icon_heart.png',          fallback: Icons.favorite),
];

// ── Grilla de Selección de Modos ───────────────────────────────────
class ModeSelectorGrid extends StatelessWidget {
  final int? activeIndex;
  final List<_PatternDef> defs;
  final int offset; 
  final Color color;
  final Function(int) onSelect;
  final int crossAxisCount;

  const ModeSelectorGrid({
    super.key,
    required this.activeIndex,
    required this.defs,
    required this.onSelect,
    this.offset = 0,
    this.color = LvsColors.pink,
    this.crossAxisCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: defs.length,
      itemBuilder: (context, index) {
        final realIndex = index + offset;
        final def = defs[index];
        final isActive = activeIndex == realIndex;

        return _PatternTile(
          label: def.label,
          assetPath: def.asset,
          fallback: def.fallback,
          isActive: isActive,
          activeColor: color,
          onTap: () => onSelect(realIndex),
        );
      },
    );
  }
}

// ── Tile individual de patrón ────────────────────────────────────
class _PatternTile extends StatelessWidget {
  final String label;
  final String assetPath;
  final IconData fallback;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _PatternTile({
    required this.label,
    required this.assetPath,
    required this.fallback,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: isActive 
                    ? activeColor.withValues(alpha: 0.15) 
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? activeColor : Colors.white12,
                  width: isActive ? 1.8 : 1,
                ),
                boxShadow: isActive ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ] : [],
              ),
              child: Center(
                child: _AppIcon(
                  assetPath: assetPath,
                  fallback: fallback,
                  active: isActive,
                  activeColor: activeColor,
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
              color: isActive ? activeColor : LvsColors.text3,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final String assetPath;
  final IconData fallback;
  final bool active;
  final Color activeColor;
  final double size;

  const _AppIcon({
    required this.assetPath,
    required this.fallback,
    required this.active,
    required this.activeColor,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        color: active ? activeColor : null,
        colorBlendMode: active ? BlendMode.srcIn : null,
        opacity: active ? null : const AlwaysStoppedAnimation(0.5),
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            fallback,
            color: active ? activeColor : LvsColors.text3,
            size: size * 0.9,
          );
        },
      ),
    );
  }
}

// ── Canvas de Dibujo Táctil (Simplified for now) ──────────────────────────────────
class LvsCanvas extends StatelessWidget {
  final BleService ble;
  const LvsCanvas({super.key, required this.ble});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: LvsColors.pink.withValues(alpha: 0.15)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined, color: LvsColors.pink.withValues(alpha: 0.4), size: 42),
            const SizedBox(height: 12),
            const Text('CONTROL TÁCTIL ACTIVO', 
              style: TextStyle(color: LvsColors.text3, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ],
        ),
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
