// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/screens/debug_screen.dart · v2.0.0
// Pantalla de depuración rediseñada con estética Velvet
// ═══════════════════════════════════════════════════════════════

// 🔒 SECURITY: Debug screen solo disponible en modo debug
import 'package:flutter/foundation.dart';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ble/ble_service.dart';
import '../ble/lvs_commands.dart';
import '../theme.dart';

class DebugMark {
  final int b0, b1, b2;
  final String key;
  DebugMark({required this.b0, required this.b1, required this.b2})
      : key = '${b0.toRadixString(16)}-${b1.toRadixString(16)}-$b2';

  String get hexStr => [b0, b1, b2].map((b) => b.toRadixString(16).padLeft(2,'0').toUpperCase()).join(' ');
}

class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});
  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  // ── Estado del debug ────────────────────────────────────
  int _b0 = 0xE6, _b1 = 0x8E, _b2 = 0x4F;
  SpeedLevel? _activePreset = SpeedLevel.high;
  bool _burstActive = false;
  Timer? _burstTimer;

  // ── Barrido automático ──────────────────────────────────
  bool _sweepActive = false;
  Timer? _sweepTimer;
  int _sweepFrom = 0x00, _sweepTo = 0xFF;
  int _sweepCurrent = 0;
  int _sweepDelayMs = 1000;

  // ── Marcadores ──────────────────────────────────────────
  final List<DebugMark> _marks = [];

  // ── Controllers ────────────────────────────────────────
  late TextEditingController _b0Ctrl, _b1Ctrl, _fromCtrl, _toCtrl;

  @override
  void initState() {
    super.initState();
    _b0Ctrl   = TextEditingController(text: 'E6');
    _b1Ctrl   = TextEditingController(text: '8E');
    _fromCtrl = TextEditingController(text: '00');
    _toCtrl   = TextEditingController(text: 'FF');
  }

  @override
  void dispose() {
    _burstTimer?.cancel();
    _sweepTimer?.cancel();
    _b0Ctrl.dispose(); _b1Ctrl.dispose();
    _fromCtrl.dispose(); _toCtrl.dispose();
    super.dispose();
  }

  void _setPreset(SpeedLevel? level) {
    setState(() => _activePreset = level);
    if (level == null) return;
    final p = LvsCommands.debugPresets[level]!;
    setState(() { _b0 = p['b0']!; _b1 = p['b1']!; _b2 = p['b2']!; });
    _b0Ctrl.text = _b0.toRadixString(16).padLeft(2,'0').toUpperCase();
    _b1Ctrl.text = _b1.toRadixString(16).padLeft(2,'0').toUpperCase();
    if (_burstActive) _restartBurst();
  }

  void _onSlider(double v) {
    setState(() { _b2 = v.round(); _activePreset = null; });
    if (_burstActive) _restartBurst();
  }

  void _toggleBurst(BleService ble) {
    setState(() => _burstActive = !_burstActive);
    if (_burstActive) {
      ble.writeDebugCommand(_b0, _b1, _b2);
      _burstTimer = Timer.periodic(
        Duration(milliseconds: ble.burstIntervalMs),
        (_) => ble.writeDebugCommand(_b0, _b1, _b2, silent: true),
      );
    } else {
      _burstTimer?.cancel();
      _burstTimer = null;
    }
  }

  void _restartBurst() {
    if (!_burstActive) return;
    _burstTimer?.cancel();
    final ble = ref.read(bleProvider);
    _burstTimer = Timer.periodic(
      Duration(milliseconds: ble.burstIntervalMs),
      (_) => ble.writeDebugCommand(_b0, _b1, _b2, silent: true),
    );
  }

  void _startSweep(BleService ble) {
    _sweepFrom = int.tryParse(_fromCtrl.text, radix: 16) ?? 0;
    _sweepTo   = int.tryParse(_toCtrl.text,   radix: 16) ?? 255;
    _sweepFrom = _sweepFrom.clamp(0, 255);
    _sweepTo   = _sweepTo.clamp(0, 255);

    final step  = _sweepTo >= _sweepFrom ? 1 : -1;
    _sweepCurrent = _sweepFrom;

    setState(() { _sweepActive = true; });

    void advance() {
      setState(() {
        _b2 = _sweepCurrent;
        _activePreset = null;
      });
      ble.writeDebugCommand(_b0, _b1, _sweepCurrent);

      if (_sweepCurrent == _sweepTo) {
        _stopSweep();
        return;
      }
      _sweepCurrent += step;
    }

    advance();
    _sweepTimer = Timer.periodic(Duration(milliseconds: _sweepDelayMs), (_) => advance());
  }

  void _stopSweep() {
    _sweepTimer?.cancel();
    _sweepTimer = null;
    setState(() => _sweepActive = false);
  }

  void _bookmark() {
    final mark = DebugMark(b0: _b0, b1: _b1, b2: _b2);
    if (_marks.any((m) => m.key == mark.key)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya está marcado'), duration: Duration(seconds: 1)));
      return;
    }
    setState(() => _marks.add(mark));
  }

  void _loadMark(DebugMark m) {
    setState(() { _b0 = m.b0; _b1 = m.b1; _b2 = m.b2; _activePreset = null; });
    _b0Ctrl.text = m.b0.toRadixString(16).padLeft(2,'0').toUpperCase();
    _b1Ctrl.text = m.b1.toRadixString(16).padLeft(2,'0').toUpperCase();
    if (_burstActive) _restartBurst();
  }

  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // 🔒 SECURITY: Prevenir uso en producción
    if (!kDebugMode) {
      return Scaffold(
        backgroundColor: LvsColors.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: LvsColors.text3),
              const SizedBox(height: 16),
              const Text('DEBUG SCREEN', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: LvsColors.text3)),
              const SizedBox(height: 8),
              const Text('No disponible en producción', style: TextStyle(
                fontSize: 12, color: LvsColors.text3)),
            ],
          ),
        ),
      );
    }

    final ble = ref.watch(bleProvider);

    return Scaffold(
      backgroundColor: LvsColors.bg,
      appBar: AppBar(
        title: const Text('COREAURA LAB', style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: LvsColors.amber)),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: LvsColors.amber,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // Display de Protocolo
          CardGlass(
            borderColor: LvsColors.amber.withOpacity(0.1),
            child: Column(
              children: [
                const SectionLabel('MANUAL BYTE FORGE', color: LvsColors.amber),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ByteCell(label: 'B0', hex: _b0Ctrl.text, color: LvsColors.amber),
                    const SizedBox(width: 8),
                    _ByteCell(label: 'B1', hex: _b1Ctrl.text, color: LvsColors.amber),
                    const SizedBox(width: 12),
                    _ByteCell(label: 'B2', hex: _b2.toRadixString(16).padLeft(2,'0').toUpperCase(), color: LvsColors.pink, highlight: true),
                  ],
                ),
                const SizedBox(height: 32),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: LvsColors.amber,
                    inactiveTrackColor: LvsColors.borderH,
                    thumbColor: LvsColors.amber,
                    trackHeight: 12,
                  ),
                  child: Slider(
                    value: _b2.toDouble(),
                    min: 0, max: 255,
                    onChanged: _onSlider,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('0x00', style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: LvsColors.text3)),
                    Text('INTENSIDAD: $_b2', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: LvsColors.amber)),
                    const Text('0xFF', style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: LvsColors.text3)),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Presets
          Row(
            children: [
              _DebugPresetBtn(label: 'STOP', active: _activePreset == SpeedLevel.stop, onTap: () => _setPreset(SpeedLevel.stop)),
              const SizedBox(width: 8),
              _DebugPresetBtn(label: 'HIGH', active: _activePreset == SpeedLevel.high, onTap: () => _setPreset(SpeedLevel.high)),
              const SizedBox(width: 8),
              _DebugPresetBtn(label: 'SYNC', active: _activePreset == null, onTap: () => setState(() => _activePreset = null)),
            ],
          ),

          const SizedBox(height: 24),

          // Acciones
          Row(
            children: [
              Expanded(
                child: _BigActionBtn(
                  label: _burstActive ? 'DETENER RÁFAGA' : 'INICIAR RÁFAGA',
                  icon: _burstActive ? Icons.stop_circle : Icons.bolt, // Usando bolt o flash
                  active: _burstActive,
                  color: LvsColors.amber,
                  enabled: ble.isConnected,
                  onTap: () => _toggleBurst(ble),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _bookmark,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: LvsColors.pink.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: LvsColors.pink.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.bookmark_add_outlined, color: LvsColors.pink),
                ),
              )
            ],
          ),

          const SizedBox(height: 24),

          // Barrido
          CardGlass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('SWEEP ENGINE (B2)'),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _HexInField(label: 'FROM', controller: _fromCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _HexInField(label: 'TO', controller: _toCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _HexInField(label: 'DELAY', controller: TextEditingController(text: '${_sweepDelayMs}ms'), readOnly: true)),
                  ],
                ),
                const SizedBox(height: 12),
                Slider(
                  value: _sweepDelayMs.toDouble(),
                  min: 100, max: 3000, divisions: 29,
                  activeColor: LvsColors.violet,
                  onChanged: (v) => setState(() => _sweepDelayMs = v.round()),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: ble.isConnected ? (_sweepActive ? _stopSweep : () => _startSweep(ble)) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _sweepActive ? LvsColors.red.withOpacity(0.2) : LvsColors.violet.withOpacity(0.2),
                      foregroundColor: _sweepActive ? LvsColors.red : LvsColors.violet,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: (_sweepActive ? LvsColors.red : LvsColors.violet).withOpacity(0.5)),
                    ),
                    child: Text(_sweepActive ? 'STOP SWEEP' : 'START SWEEP ENGINE', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (_marks.isNotEmpty) ...[
            const SectionLabel('SAVED MARKS'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: _marks.map((m) => GestureDetector(
                onTap: () => _loadMark(m),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: LvsColors.bgCardH,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: LvsColors.pink.withOpacity(0.2)),
                  ),
                  child: Text(m.hexStr, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: LvsColors.pink, fontWeight: FontWeight.bold)),
                ),
              )).toList(),
            ),
          ]
        ],
      ),
    );
  }
}

class _ByteCell extends StatelessWidget {
  final String label, hex;
  final Color color;
  final bool highlight;
  const _ByteCell({required this.label, required this.hex, required this.color, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: LvsColors.text3)),
        const SizedBox(height: 6),
        Container(
          width: 70, height: 70,
          decoration: BoxDecoration(
            color: highlight ? color.withOpacity(0.15) : LvsColors.bgCardH,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: highlight ? color : LvsColors.border, width: highlight ? 2 : 1),
            boxShadow: highlight ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12)] : [],
          ),
          alignment: Alignment.center,
          child: Text(hex, style: TextStyle(fontFamily: 'monospace', fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        ),
      ],
    );
  }
}

class _DebugPresetBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _DebugPresetBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? LvsColors.amber.withOpacity(0.1) : LvsColors.bgCardH,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? LvsColors.amber : LvsColors.border),
          ),
          child: Center(child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: active ? LvsColors.amber : LvsColors.text3))),
        ),
      ),
    );
  }
}

class _BigActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active, enabled;
  final Color color;
  final VoidCallback onTap;
  const _BigActionBtn({required this.label, required this.icon, required this.active, required this.enabled, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: active 
                ? LinearGradient(colors: [color.withOpacity(0.4), color.withOpacity(0.1)])
                : null,
            color: active ? null : LvsColors.bgCardH,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? color : LvsColors.borderH),
            boxShadow: active ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 15)] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: active ? Colors.white : color, size: 20),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: active ? Colors.white : color, letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HexInField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool readOnly;
  const _HexInField({required this.label, required this.controller, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: LvsColors.text3)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true, fillColor: LvsColors.bgCardH,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
