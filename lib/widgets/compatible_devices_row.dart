// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/widgets/compatible_devices_row.dart · v2.0.0
// Lista horizontal de dispositivos compatibles en el Dashboard
// v2.0.0 → Usa serverCatalogProvider (catálogo completo del servidor)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/toy_model.dart';
import '../services/catalog_service.dart';
import '../ble/ble_service.dart';
import '../theme.dart';
import '../utils/snack_helper.dart';

class CompatibleDevicesRow extends ConsumerWidget {
  const CompatibleDevicesRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ← USA el catálogo del servidor (inicializado con fallback local)
    final toys = ref.watch(serverCatalogProvider);
    final isLoading = ref.watch(catalogLoadingProvider);

    // ✨ FIX: Siempre hay dispositivos disponibles inmediatamente

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header de sección ─────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const SectionLabel('DISPOSITIVOS COMPATIBLES'),
                if (isLoading) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: LvsColors.teal,
                    ),
                  ),
                ],
              ],
            ),
            Text(
              '${toys.length} MODELOS',
              style: const TextStyle(
                fontSize: 9, color: LvsColors.teal,
                fontWeight: FontWeight.w700, letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Scroll horizontal de tarjetas ─────────────────
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: toys.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) => _DeviceChip(toy: toys[i], ref: ref),
          ),
        ),
      ],
    );
  }
}

// ── Chip individual de dispositivo ────────────────────────────
class _DeviceChip extends StatelessWidget {
  final ToyModel toy;
  final WidgetRef ref;
  const _DeviceChip({required this.toy, required this.ref});

  /// Ícono Material representativo según tipo de dispositivo
  IconData get _icon {
    final s = toy.stimulationType.toLowerCase();
    final n = toy.name.toLowerCase();
    final u = toy.usageType.toLowerCase();
    if (toy.hasDualChannel || s.contains('empuje')) return Icons.multiple_stop_rounded;
    if (n.contains('egg') || n.contains('huevo') || u.contains('egg')) return Icons.egg_rounded;
    if (n.contains('bullet') || n.contains('bala') || u.contains('bullet')) return Icons.bolt_rounded;
    return Icons.vibration_rounded;
  }

  /// Color temático
  Color get _color {
    if (toy.hasDualChannel || toy.stimulationType.toLowerCase().contains('empuje')) {
      return LvsColors.teal;
    }
    return LvsColors.pink;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _activate(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 90,
        decoration: BoxDecoration(
          color: LvsColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: _color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Imagen de red o ícono Material garantizado ─────
            toy.imageUrl.isNotEmpty
                ? SizedBox(
                    width: 56, height: 56,
                    child: CachedNetworkImage(
                      imageUrl: toy.imageUrl,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => _buildIconWidget(),
                    ),
                  )
                : _buildIconWidget(),

            const SizedBox(height: 6),

            // ── Nombre truncado ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                toy.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 3),

            // ── ID badge ────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: _color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'ID: ${toy.id}',
                style: TextStyle(
                  color: _color, fontSize: 7, fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconWidget() {
    return Container(
      width: 56, height: 56,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withOpacity(0.2)),
      ),
      child: Image.asset(
        toy.iconAsset,
        width: 32,
        height: 32,
        fit: BoxFit.contain,
      ),
    );
  }

  void _activate(BuildContext context) async {
    final result = await ref.read(catalogProvider.notifier).addByKey(toy.id);
    if (context.mounted) {
      final ble = ref.read(bleProvider);
      final ok = result != null;
      
      if (ok) {
        // ✨ Establecer como activo inmediatamente en el Dashboard
        ble.setActiveToy(result);
      }

      LvsSnack.show(
        context,
        ok: ok,
        message: ok
            ? '${result.name} vinculado\nListo para controlar'
            : 'No se encontró el dispositivo "${toy.id}".',
      );
    }
  }
}
