// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/widgets/quick_add_control.dart · v3.0.0
// Quick Add Dashboard: layout compacto sin overflow
// v3.0.0 → Fila 1: [TextField ID] [QR] / Fila 2: [Activar full-width]
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/catalog_service.dart';
import '../ble/ble_service.dart';
import '../theme.dart';

class QuickAddControl extends StatefulWidget {
  final WidgetRef ref;
  const QuickAddControl({super.key, required this.ref});

  @override
  State<QuickAddControl> createState() => _QuickAddControlState();
}

class _QuickAddControlState extends State<QuickAddControl> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _lastFeedback;
  bool _feedbackOk = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit([String? override]) async {
    final key = (override ?? _ctrl.text).trim();
    if (key.isEmpty) return;

    setState(() { _loading = true; _lastFeedback = null; });

    final toy = await widget.ref.read(catalogProvider.notifier).addByKey(key);
    
    // ✨ CAMBIO CRÍTICO: Activar inmediatamente en el dashboard
    if (toy != null) {
      widget.ref.read(bleProvider).setActiveToy(toy);
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _feedbackOk = toy != null;
        _lastFeedback = toy != null
            ? '✅ ${toy.name} vinculado. ¡Listo!'
            : '❌ No se encontró "$key". Verifica el ID del empaque.';
        if (toy != null) _ctrl.clear();
      });
    }
  }

  Future<void> _openQrScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScanScreen()),
    );
    if (result != null && result.isNotEmpty && mounted) {
      final extracted = _extractModelId(result);
      _ctrl.text = extracted;
      await _submit(extracted);
    }
  }

  String _extractModelId(String raw) {
    final trimmed = raw.trim();
    if (RegExp(r'^\d+$').hasMatch(trimmed)) return trimmed;
    final urlMatch = RegExp(r'[/?=](\d{3,6})(?:\D|$)').firstMatch(trimmed);
    if (urlMatch != null) return urlMatch.group(1)!;
    final numMatch = RegExp(r'\b(\d{3,6})\b').firstMatch(trimmed);
    if (numMatch != null) return numMatch.group(1)!;
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Fila 1: Campo ID + Botón QR ──────────────────────
        Row(
          children: [
            // TextField de ID
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: LvsColors.pink.withOpacity(0.35)),
                ),
                child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: 'ID  (ej: 8154)',
                    hintStyle: TextStyle(
                      color: Colors.white24,
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Botón QR
            GestureDetector(
              onTap: _loading ? null : _openQrScanner,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset('assets/icons/icon_qr_scan.png', color: LvsColors.teal),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ── Fila 2: Botón Activar full-width ─────────────────
        GestureDetector(
          onTap: _loading ? null : _submit,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 50,
            decoration: BoxDecoration(
              gradient: _loading ? null : LvsColors.pinkViolet,
              color: _loading ? LvsColors.bgCardH : null,
              borderRadius: BorderRadius.circular(14),
              boxShadow: _loading ? [] : [
                BoxShadow(color: LvsColors.pink.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))
              ],
            ),
            child: Center(
              child: _loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt, color: Colors.white, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'ACTIVAR DISPOSITIVO',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),

        // ── Feedback ────────────────────────────────────────
        if (_lastFeedback != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (_feedbackOk ? LvsColors.teal : LvsColors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (_feedbackOk ? LvsColors.teal : LvsColors.red).withOpacity(0.3),
              ),
            ),
            child: Text(
              _lastFeedback!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _feedbackOk ? LvsColors.teal : LvsColors.red,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Pantalla QR
// ══════════════════════════════════════════════════════════════
class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();
  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  final MobileScannerController _scanner = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() { _scanner.dispose(); super.dispose(); }

  void _onDetect(BarcodeCapture cap) {
    if (_scanned) return;
    final raw = cap.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _scanned = true;
    _scanner.stop();
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('ESCANEAR QR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 3)),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on_rounded), onPressed: () => _scanner.toggleTorch()),
          IconButton(icon: const Icon(Icons.flip_camera_ios_rounded), onPressed: () => _scanner.switchCamera()),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _scanner, onDetect: _onDetect),
          // Marco de enfoque
          Center(
            child: Container(
              width: 240, height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: LvsColors.pink, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          // Esquinas teal
          ...[ [true, true], [true, false], [false, true], [false, false] ].map((p) =>
            Positioned(
              top: p[0] ? MediaQuery.of(context).size.height / 2 - 120 - 1 : null,
              bottom: p[0] ? null : MediaQuery.of(context).size.height / 2 - 120 - 1,
              left: p[1] ? MediaQuery.of(context).size.width / 2 - 120 - 1 : null,
              right: p[1] ? null : MediaQuery.of(context).size.width / 2 - 120 - 1,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  border: Border(
                    top: p[0] ? const BorderSide(color: LvsColors.teal, width: 4) : BorderSide.none,
                    bottom: p[0] ? BorderSide.none : const BorderSide(color: LvsColors.teal, width: 4),
                    left: p[1] ? const BorderSide(color: LvsColors.teal, width: 4) : BorderSide.none,
                    right: p[1] ? BorderSide.none : const BorderSide(color: LvsColors.teal, width: 4),
                  ),
                ),
              ),
            )
          ),
          Positioned(
            bottom: 60, left: 0, right: 0,
            child: Column(
              children: [
                const Icon(Icons.qr_code_2, color: Colors.white54, size: 32),
                const SizedBox(height: 12),
                const Text('Apunta al QR del empaque del producto',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text('El ID se detectará automáticamente',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
