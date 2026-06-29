import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:velvet_sync/services/ble/ble_types.dart';
import 'package:velvet_sync/theme.dart';

class BleStateBox extends StatelessWidget {
  final BleState state;
  const BleStateBox({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch(state) {
      BleState.connected  => ('Online',   LvsColors.teal),
      BleState.scanning   => ('Buscando', LvsColors.amber),
      BleState.connecting => ('Uniendo',  LvsColors.amber),
      BleState.error      => ('Error',    LvsColors.red),
      BleState.idle       => ('Offline',  LvsColors.text3),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BleDot(color: color, pulse: state == BleState.scanning || state == BleState.connecting),
          const SizedBox(width: 8),
          Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: color)),
        ],
      ),
    );
  }
}

class BleDot extends StatefulWidget {
  final Color color;
  final bool pulse;
  const BleDot({super.key, required this.color, required this.pulse});
  @override
  State<BleDot> createState() => _BleDotState();
}

class _BleDotState extends State<BleDot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return widget.pulse
      ? AnimatedBuilder(animation: _c, builder: (_, __) => _dot(_c.value))
      : _dot(1.0);
  }
  Widget _dot(double opacity) => Container(
    width: 6, height: 6, decoration: BoxDecoration(color: widget.color.withValues(alpha: opacity), shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: widget.color.withValues(alpha: opacity * 0.5), blurRadius: 4)]),
  );
}

class NeonPresetBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData icon;
  final Color color;

  const NeonPresetBtn({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? color : color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 12)] : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? color : color.withValues(alpha: 0.6), size: 16),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1,
              color: active ? Colors.white : LvsColors.text1
            )),
          ],
        ),
      ),
    );
  }
}
