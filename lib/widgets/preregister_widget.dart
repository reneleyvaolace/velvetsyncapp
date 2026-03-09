// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/widgets/preregister_widget.dart · v1.0.0
// Widget de Pre-registro: agregar dispositivo por QR o clave
// antes/después del escaneo BLE para vincular automáticamente
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/toy_model.dart';
import '../services/catalog_service.dart';
import '../theme.dart';

/// Panel expandible para pre-registrar un dispositivo en el HomeScreen.
/// Se puede usar antes o después del escaneo BLE.
class PreregisterPanel extends ConsumerStatefulWidget {
  final VoidCallback? onAdded;
  const PreregisterPanel({super.key, this.onAdded});

  @override
  ConsumerState<PreregisterPanel> createState() => _PreregisterPanelState();
}

class _PreregisterPanelState extends ConsumerState<PreregisterPanel>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  final TextEditingController _keyCtrl = TextEditingController();
  bool _loading = false;
  String? _feedback;
  bool _feedbackOk = false;
  late AnimationController _anim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _fadeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _anim.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _anim.forward();
    } else {
      _anim.reverse();
      _feedback = null;
    }
  }

  Future<void> _addByKey(String key) async {
    if (key.trim().isEmpty) return;
    setState(() { _loading = true; _feedback = null; });

    final result = await ref.read(catalogProvider.notifier).addByKey(key.trim());
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result != null) {
        _feedbackOk = true;
        _feedback = '✅ ${result.name} registrado.\nEl dispositivo se vinculará automáticamente al detectarse.';
        _keyCtrl.clear();
        if (widget.onAdded != null) widget.onAdded!();
      } else {
        _feedbackOk = false;
        _feedback = '❌ No se encontró un dispositivo con clave "$key".\n'
            'Verifica el ID en el embalaje del producto.';
      }
      _loading = false;
    });
  }

  Future<void> _openQr() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScanPage()),
    );
    if (result != null && result.isNotEmpty && mounted) {
      _keyCtrl.text = result;
      _addByKey(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lista de pre-registrados para mostrar las chips
    final preregistered = ref.watch(catalogProvider).maybeWhen(
      data: (toys) => ref
          .read(catalogProvider.notifier)
          .preregistered,
      orElse: () => <ToyModel>[],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabecera (botón toggle) ─────────────────────────
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _toggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: LvsColors.bgCardH.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: (_expanded ? LvsColors.teal : Colors.white12)),
            ),
            child: Row(
              children: [
                Icon(Icons.devices_other_rounded,
                    color: _expanded ? LvsColors.teal : LvsColors.text3,
                    size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    preregistered.isEmpty
                        ? 'Pre-registrar dispositivo'
                        : 'Dispositivos pre-registrados (${preregistered.length})',
                    style: TextStyle(
                      color: _expanded ? LvsColors.teal : LvsColors.text3,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: LvsColors.text3,
                  size: 18,
                ),
              ],
            ),
          ),
        ),

        // ── Panel expandible ────────────────────────────────
        SizeTransition(
          sizeFactor: _fadeAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: LvsColors.bgCard.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: LvsColors.teal.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          color: LvsColors.teal, size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ingresa el ID o clave del producto para registrarlo. '
                          'Cuando el BLE lo detecte, se vinculará automáticamente sin necesidad de buscarlo otra vez.',
                          style: TextStyle(
                              color: LvsColors.text3,
                              fontSize: 11,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Chips de dispositivos ya registrados
                  if (preregistered.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: preregistered.map((toy) {
                        return Chip(
                          label: Text(toy.name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10)),
                          deleteIcon: const Icon(Icons.close, size: 13),
                          onDeleted: () {
                            ref
                                .read(catalogProvider.notifier)
                                .removeDevice(toy.id);
                          },
                          backgroundColor:
                              LvsColors.teal.withValues(alpha: 0.15),
                          side: BorderSide(
                              color: LvsColors.teal.withValues(alpha: 0.4)),
                          deleteIconColor: Colors.white54,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Campo de clave + botón buscar
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: LvsColors.pink.withValues(alpha: 0.3)),
                          ),
                          child: TextField(
                            controller: _keyCtrl,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'ID del producto  (ej: 8154)',
                              hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  fontSize: 12),
                              prefixIcon: const Icon(Icons.vpn_key_rounded,
                                  color: LvsColors.pink, size: 16),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 10),
                            ),
                            onSubmitted: _addByKey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Botón Buscar
                      _iconBtn(
                        icon: _loading
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.search_rounded,
                                color: Colors.white, size: 20),
                        color: LvsColors.pink,
                        onTap: () => _addByKey(_keyCtrl.text),
                      ),
                      const SizedBox(width: 6),

                      // Botón QR
                      _iconBtn(
                        icon: const Icon(Icons.qr_code_scanner_rounded,
                            color: Colors.white, size: 20),
                        color: LvsColors.teal,
                        onTap: _openQr,
                      ),
                    ],
                  ),

                  // Feedback
                  if (_feedback != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (_feedbackOk ? LvsColors.teal : LvsColors.red)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (_feedbackOk ? LvsColors.teal : LvsColors.red)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _feedback!,
                        style: TextStyle(
                          color: _feedbackOk ? LvsColors.teal : LvsColors.red,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconBtn({required Widget icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Center(child: icon),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Pantalla QR — compacta para uso desde Home
// ══════════════════════════════════════════════════════════════
class _QrScanPage extends StatefulWidget {
  const _QrScanPage();
  @override
  State<_QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<_QrScanPage> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onDetect(BarcodeCapture cap) {
    if (_scanned) return;
    final val = cap.barcodes.firstOrNull?.rawValue;
    if (val == null || val.isEmpty) return;
    _scanned = true;
    _ctrl.stop();
    Navigator.pop(context, val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Escanear QR',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on_rounded), onPressed: () => _ctrl.toggleTorch()),
          IconButton(icon: const Icon(Icons.flip_camera_ios_rounded), onPressed: () => _ctrl.switchCamera()),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _ctrl, onDetect: _onDetect),
          Center(
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: LvsColors.pink, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            bottom: 48, left: 0, right: 0,
            child: Center(
              child: Text('Apunta al QR del empaque',
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
