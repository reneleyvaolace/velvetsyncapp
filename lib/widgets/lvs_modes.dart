import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:velvet_sync/theme.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';

// ── Definición de Patrones ──────────────────────────────────────────
class PatternDef {
  final String label;
  final String asset;       
  final IconData fallback;  

  const PatternDef({required this.label, required this.asset, required this.fallback});
}

// ── Modos de Intensidad (Canal de Empuje/Rotación) ────────
const List<PatternDef> _kIntensityDefs = [
  PatternDef(label: 'SUAVE',  asset: 'assets/icons/icon_intensity.png',       fallback: Icons.keyboard_arrow_up),
  PatternDef(label: 'MEDIO',  asset: 'assets/icons/icon_heart.png',           fallback: Icons.bolt),
  PatternDef(label: 'INTENSO', asset: 'assets/icons/icon_thrust.png',          fallback: Icons.rocket_launch),
];

// ── Modos de Ritmo (Canal de Vibración/Patrones) ───────────────────────────
const List<PatternDef> _kRhythmDefs = [
  PatternDef(label: 'PULSO',    asset: 'assets/icons/icon_sync_music.png',     fallback: Icons.favorite),
  PatternDef(label: 'OLA',      asset: 'assets/icons/icon_pulse_waves.png',    fallback: Icons.water_drop),
  PatternDef(label: 'RAMPA',    asset: 'assets/icons/icon_motion_control.png', fallback: Icons.trending_up),
  PatternDef(label: 'GIROS',    asset: 'assets/icons/icon_dual_motor.png',     fallback: Icons.swap_horiz),
  PatternDef(label: 'TORMENTA', asset: 'assets/icons/icon_cool_down.png',      fallback: Icons.thunderstorm),
  PatternDef(label: 'CAOS',     asset: 'assets/icons/icon_custom_pattern.png', fallback: Icons.blur_on),
  PatternDef(label: 'MAREA',    asset: 'assets/icons/icon_vibrator.png',       fallback: Icons.waves),
  PatternDef(label: 'VOLCÁN',   asset: 'assets/icons/icon_thrust.png',         fallback: Icons.whatshot),
  PatternDef(label: 'LATIDO',   asset: 'assets/icons/icon_heart.png',          fallback: Icons.monitor_heart),
];

// ── Grilla de Selección de Modos ───────────────────────────────────
class ModeSelectorGrid extends StatelessWidget {
  final int? activeIndex;
  final List<PatternDef> defs;
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
      child: Icon(
        fallback,
        color: active ? activeColor : LvsColors.text3,
        size: size,
      ),
    );
  }
}

// ── Canvas de Dibujo Táctil Dinámico ──────────────────────────────────
class LvsCanvas extends StatefulWidget {
  final BleService ble;
  const LvsCanvas({super.key, required this.ble});

  @override
  State<LvsCanvas> createState() => _LvsCanvasState();
}

class _LvsCanvasState extends State<LvsCanvas> {
  Timer? _throttle;
  double _intensity = 0;
  bool _active = false;

  void _update(Offset pos, Size size) {
    final val = ((size.height - pos.dy) / size.height * 100).clamp(0.0, 100.0);
    setState(() {
      _intensity = val;
      _active = true;
    });
    if (_throttle == null || !_throttle!.isActive) {
      widget.ble.setProportionalChannel1(_intensity.round());
      _throttle = Timer(const Duration(milliseconds: 60), () {
        if (_active) widget.ble.setProportionalChannel1(_intensity.round());
      });
    }
  }

  void _stop() {
    setState(() { _active = false; _intensity = 0; });
    _throttle?.cancel();
    widget.ble.setProportionalChannel1(0);
  }

  @override
  void dispose() {
    _throttle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 200);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) => _update(details.localPosition, size),
          onPanStart: (details) => _update(details.localPosition, size),
          onPanUpdate: (details) => _update(details.localPosition, size),
          onPanEnd: (_) => _stop(),
          onPanCancel: () => _stop(),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: LvsColors.pink.withValues(alpha: 0.2), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(
                painter: _CanvasPainter(_active ? _intensity : 0, LvsColors.pink),
              ),
            ),
          ),
        );
      }
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final double intensity;
  final Color color;
  _CanvasPainter(this.intensity, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity > 0) {
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.5)],
        ).createShader(Rect.fromLTRB(0, 0, size.width, size.height));

      final h = (intensity / 100) * size.height;
      canvas.drawRect(Rect.fromLTRB(0, size.height - h, size.width, size.height), paint);

      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawLine(Offset(0, size.height - h), Offset(size.width, size.height - h), linePaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${intensity.round()}%',
          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(size.width / 2 - textPainter.width / 2, size.height - h - 25));
    }
  }

  @override
  bool shouldRepaint(_CanvasPainter old) => old.intensity != intensity;
}

// Exportar listas para uso externo
const kIntensityModes = _kIntensityDefs;
const kRhythmModes = _kRhythmDefs;
