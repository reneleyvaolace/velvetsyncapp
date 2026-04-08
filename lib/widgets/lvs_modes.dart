import 'package:flutter/material.dart';
import 'package:velvet_sync/theme.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';

class LvsCanvas extends StatelessWidget {
  final BleService ble;
  const LvsCanvas({super.key, required this.ble});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha:0.1)),
      ),
      child: const Center(child: Text('Canvas de Dibujo (Simulado)', style: TextStyle(color: LvsColors.text3))),
    );
  }
}

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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(10, (index) => _PatternTile(
          index: index,
          isActive: activePattern == index,
          color: color,
          onTap: () => onSelect(index),
        )),
      ),
    );
  }
}

class _PatternTile extends StatelessWidget {
  final int index;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _PatternTile({required this.index, required this.isActive, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha:0.2) : Colors.white.withValues(alpha:0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isActive ? color : Colors.white.withValues(alpha:0.1)),
        ),
        child: Center(child: Text(index == 0 ? 'Off' : 'P$index', style: TextStyle(color: isActive ? color : LvsColors.text3))),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: LvsColors.text3));
  }
}
