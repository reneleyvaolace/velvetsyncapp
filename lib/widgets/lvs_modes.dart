import 'package:flutter/material.dart';
import 'package:lvs_control/ble/ble_service.dart';
import 'package:lvs_control/theme.dart';
import 'dart:async';

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
    setState(() { _intensity = val; _active = true; });
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
  void dispose() { _throttle?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 200);
        return GestureDetector(
          onPanStart: (details) => _update(details.localPosition, size),
          onPanUpdate: (details) => _update(details.localPosition, size),
          onPanEnd: (_) => _stop(),
          onPanCancel: () => _stop(),
          child: Container(
            height: 200, width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: LvsColors.pink.withOpacity(0.2), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(painter: _CanvasPainter(_active ? _intensity : 0, LvsColors.pink)),
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
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [color.withOpacity(0.1), color.withOpacity(0.5)],
        ).createShader(Rect.fromLTRB(0, 0, size.width, size.height));
      final h = (intensity / 100) * size.height;
      canvas.drawRect(Rect.fromLTRB(0, size.height - h, size.width, size.height), paint);
      final linePaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2;
      canvas.drawLine(Offset(0, size.height - h), Offset(size.width, size.height - h), linePaint);
      final textPainter = TextPainter(
        text: TextSpan(text: '${intensity.round()}%', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(size.width / 2 - textPainter.width / 2, size.height - h - 25));
    }
  }
  @override
  bool shouldRepaint(_CanvasPainter old) => old.intensity != intensity;
}

class PatternSelectorRow extends StatelessWidget {
  final int? activePattern;
  final Color color;
  final Function(int) onSelect;

  const PatternSelectorRow({super.key, this.activePattern, required this.color, required this.onSelect});

  static const Map<int, Map<String, dynamic>> _meta = {
    0: {'icon': Icons.tune, 'label': 'MANUAL'},
    1: {'icon': Icons.keyboard_double_arrow_up, 'label': 'SUAVE'},
    2: {'icon': Icons.bolt, 'label': 'MEDIO'},
    3: {'icon': Icons.rocket_launch, 'label': 'FUERTE'},
    4: {'icon': Icons.waves, 'label': 'OLA'},
    5: {'icon': Icons.graphic_eq, 'label': 'PULSO'},
    6: {'icon': Icons.trending_up, 'label': 'RAMPA'},
    7: {'icon': Icons.favorite, 'label': 'LATIDO'},
    8: {'icon': Icons.flash_on, 'label': 'CAOS'},
    9: {'icon': Icons.cyclone, 'label': 'TORNADO'},
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12, runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        for (int i = 0; i <= 9; i++)
          _PatternBtnV2(
            icon: _meta[i]!['icon'],
            label: _meta[i]!['label'],
            active: (i == 0) ? (activePattern == null) : (activePattern == i),
            color: color,
            onTap: () => onSelect(i),
          ),
      ],
    );
  }
}

class _PatternBtnV2 extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _PatternBtnV2({required this.icon, required this.label, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 68,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: active ? color.withOpacity(0.15) : LvsColors.bgCardH.withOpacity(0.5),
          border: Border.all(color: active ? color : LvsColors.borderH, width: active ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? color : LvsColors.text3, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 8, fontWeight: active ? FontWeight.w900 : FontWeight.w600, color: active ? color : LvsColors.text3)),
          ],
        ),
      ),
    );
  }
}
