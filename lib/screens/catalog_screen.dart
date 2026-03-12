// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/screens/catalog_screen.dart · v3.0.0
// Catálogo: CRUD completo + QR real + búsqueda multiclave
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/catalog_service.dart';
import '../models/toy_model.dart';
import '../theme.dart';

// ══════════════════════════════════════════════════════════════
// Pantalla principal del Catálogo
// ══════════════════════════════════════════════════════════════
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogState = ref.watch(catalogProvider);

    return Scaffold(
      backgroundColor: LvsColors.bg,
      appBar: AppBar(
        title: const Text('CATÁLOGO VERIFICADO'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Refrescar desde Supabase
          IconButton(
            icon: const Icon(Icons.cleaning_services_rounded, color: LvsColors.pink),
            tooltip: 'Limpiar y Recargar Catálogo',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: LvsColors.bgCard,
                  title: const Text('Limpieza Profunda', style: TextStyle(color: Colors.white)),
                  content: const Text('Esto borrará los dispositivos guardados localmente y recargará todo desde Supabase. ¿Continuar?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: LvsColors.pink),
                      onPressed: () => Navigator.pop(ctx, true), 
                      child: const Text('LIMPIAR Y RECARGAR'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Limpiando caché local y recargando datos...')),
                );
                await ref.read(catalogProvider.notifier).nukeAndReload();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Catálogo reconstruido desde Supabase'),
                      backgroundColor: LvsColors.teal,
                    ),
                  );
                }
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: LvsColors.pink,
          labelColor: LvsColors.pink,
          unselectedLabelColor: LvsColors.text3,
          tabs: [
            Tab(icon: Image.asset('assets/icons/icon_tab_control.png', width: 24, height: 24), text: 'Mis Dispositivos'),
            Tab(icon: Image.asset('assets/icons/icon_add_device.png', width: 24, height: 24), text: 'Agregar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Catálogo con CRUD ─────────────────────────
          Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: catalogState.when(
                  data: (toys) {
                    final filteredToys = toys
                        .where((t) =>
                            t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            t.id.contains(_searchQuery))
                        .toList();

                    if (filteredToys.isEmpty) return _buildEmptyState();

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.70,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: filteredToys.length,
                      itemBuilder: (context, index) =>
                          _buildToyCard(filteredToys[index], toys),
                    );
                  },
                  loading: () => const Center(
                      child: CircularProgressIndicator(color: LvsColors.pink)),
                  error: (err, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: LvsColors.red, size: 48),
                        const SizedBox(height: 16),
                        const Text('Error al cargar catálogo',
                            style: TextStyle(color: Colors.white)),
                        TextButton(
                          onPressed: () =>
                              ref.read(catalogProvider.notifier).fetchCatalog(),
                          child: const Text('Reintentar',
                              style: TextStyle(color: LvsColors.pink)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Tab 2: Agregar ───────────────────────────────────
          _AddDeviceTab(onAdded: () => _tabController.animateTo(0)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: LvsColors.bgCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: LvsColors.pink.withValues(alpha: 0.2)),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Buscar por modelo o ID...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            prefixIcon: const Icon(Icons.search, color: LvsColors.pink),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.white38),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  // ── Helper para construir el ícono del dispositivo ───────────
  Widget _buildToyIcon(ToyModel toy) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: LvsColors.pink.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Image.asset(
          toy.iconAsset,
          width: 64,
          height: 64,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // ── Tarjeta de dispositivo con menú de acciones ──────────────

  Widget _buildToyCard(ToyModel toy, List<ToyModel> allToys) {
    return GestureDetector(
      onLongPress: () => _showCardMenu(toy, allToys),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: LvsColors.bgCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      color: Colors.white.withValues(alpha: 0.02),
                      child: toy.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: toy.imageUrl,
                              fit: BoxFit.contain,
                              placeholder: (_, __) => Center(
                                child: _buildToyIcon(toy),
                              ),
                              errorWidget: (_, __, ___) => Center(
                                child: _buildToyIcon(toy),
                              ),
                            )
                          : Center(child: _buildToyIcon(toy)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(toy.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: LvsColors.pink.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(toy.id,
                                  style: const TextStyle(
                                      color: LvsColors.pink,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 4),
                            if (toy.hasDualChannel)
                              Image.asset('assets/icons/icon_bluetooth.png', width: 26, height: 26),
                            if (toy.isPrecise)
                              const Icon(Icons.tune, color: LvsColors.teal, size: 13),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(toy.targetAnatomy.toUpperCase(),
                            style: TextStyle(
                                color: LvsColors.text3, fontSize: 8, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Badge de menú (top right) ──────────────────────
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => _showCardMenu(toy, allToys),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.more_vert, color: Colors.white54, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCardMenu(ToyModel toy, List<ToyModel> allToys) {
    showModalBottomSheet(
      context: context,
      backgroundColor: LvsColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            // Nombre
            Text(toy.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
            Text('ID: ${toy.id}',
                style: const TextStyle(color: LvsColors.pink, fontSize: 11)),
            const SizedBox(height: 20),
            // ── Acciones ─────────────────────────────────────
            _menuAction(
              iconWidget: Image.asset('assets/icons/icon_tab_settings.png', width: 24, height: 24),
              color: LvsColors.teal,
              label: 'Editar nombre / ID',
              onTap: () {
                Navigator.pop(ctx);
                _showEditDialog(toy);
              },
            ),
            const SizedBox(height: 10),
            _menuAction(
              icon: Icons.delete_outline_rounded,
              color: LvsColors.red,
              label: 'Eliminar del catálogo',
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(toy, allToys);
              },
            ),
            const SizedBox(height: 10),
            _menuAction(
              icon: Icons.cancel_outlined,
              color: LvsColors.text3,
              label: 'Cancelar',
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuAction({IconData? icon, Widget? iconWidget, required Color color, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            iconWidget ?? Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(ToyModel toy) {
    final nameCtrl = TextEditingController(text: toy.name);
    final idCtrl   = TextEditingController(text: toy.id);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LvsColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Editar Dispositivo', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _formField(nameCtrl, 'Nombre', Icons.label_outline),
            const SizedBox(height: 12),
            _formField(idCtrl, 'ID / Clave', Icons.vpn_key_rounded),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: LvsColors.text3)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: LvsColors.teal, foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(catalogProvider.notifier).updateDevice(
                toy.id,
                nameCtrl.text.trim(),
                idCtrl.text.trim(),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(ToyModel toy, List<ToyModel> allToys) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LvsColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('¿Eliminar del catálogo local?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${toy.name} será removido de tu lista local en la app.',
              style: const TextStyle(color: LvsColors.text2),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LvsColors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: LvsColors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: LvsColors.amber, size: 15),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'El dispositivo sigue en el servidor. Puedes vol- verlo a agregar cuando quieras.',
                      style: TextStyle(color: LvsColors.amber, fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: LvsColors.text3))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: LvsColors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(catalogProvider.notifier).removeDevice(toy.id);
            },
            child: const Text('Eliminar de la app'),
          ),
        ],
      ),
    );
  }

  Widget _formField(TextEditingController ctrl, String label, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LvsColors.pink.withValues(alpha: 0.2)),
      ),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: LvsColors.text3),
          prefixIcon: Icon(icon, color: LvsColors.pink, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text('No se encontraron resultados para "$_searchQuery"',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _tabController.animateTo(1),
            icon: const Icon(Icons.add, color: LvsColors.pink),
            label: const Text('Agregar dispositivo', style: TextStyle(color: LvsColors.pink)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Tab para Agregar Dispositivo — QR Real + Clave Manual
// ══════════════════════════════════════════════════════════════
class _AddDeviceTab extends ConsumerStatefulWidget {
  final VoidCallback? onAdded;
  const _AddDeviceTab({this.onAdded});

  @override
  ConsumerState<_AddDeviceTab> createState() => _AddDeviceTabState();
}

class _AddDeviceTabState extends ConsumerState<_AddDeviceTab> {
  final TextEditingController _keyController = TextEditingController();
  bool _isSearching = false;
  ToyModel? _foundDevice;
  String? _errorMsg;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _searchByKey(String key) async {
    if (key.trim().isEmpty) return;
    setState(() { _isSearching = true; _foundDevice = null; _errorMsg = null; });

    final result = await ref.read(catalogProvider.notifier).addByKey(key.trim());
    setState(() {
      _isSearching = false;
      if (result != null) {
        _foundDevice = result;
      } else {
        _errorMsg = 'No se encontró ningún dispositivo con ID "$key".\n'
            'Verifica la clave en el empaque del producto o en la documentación del fabricante.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: LvsColors.bgCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: LvsColors.pink.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: LvsColors.pink, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'El catálogo carga automáticamente desde el servidor. Usa esta sección para agregar un dispositivo que no aparezca en la lista, usando su clave o ID del empaque.',
                    style: TextStyle(color: LvsColors.text2, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Campo de clave
          Text('Clave o ID del Producto',
              style: TextStyle(color: LvsColors.text3, fontSize: 10, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: LvsColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: LvsColors.pink.withValues(alpha: 0.3)),
                  ),
                  child: TextField(
                    controller: _keyController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Ej: 8154',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                      prefixIcon: const Icon(Icons.vpn_key_rounded, color: LvsColors.pink, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    ),
                    onSubmitted: _searchByKey,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _searchByKey(_keyController.text),
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [LvsColors.pink, LvsColors.violet]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: LvsColors.pink.withValues(alpha: 0.4), blurRadius: 12)],
                  ),
                  child: const Icon(Icons.search_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),

          // Resultado
          if (_isSearching)
            const Center(child: CircularProgressIndicator(color: LvsColors.pink)),
          if (_foundDevice != null) _buildFoundCard(_foundDevice!),
          if (_errorMsg != null) _buildErrorCard(_errorMsg!),
        ],
      ),
    );
  }

  Widget _buildFoundCard(ToyModel toy) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: LvsColors.bgCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: LvsColors.teal.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [BoxShadow(color: LvsColors.teal.withValues(alpha: 0.15), blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: LvsColors.teal, size: 20),
              const SizedBox(width: 8),
              const Text('¡Dispositivo encontrado y agregado!',
                  style: TextStyle(color: LvsColors.teal, fontWeight: FontWeight.w900, fontSize: 13)),
            ],
          ),
          const Divider(color: Colors.white10, height: 20),
          _infoRow('Nombre', toy.name),
          _infoRow('ID', toy.id),
          _infoRow('Tipo', toy.stimulationType),
          _infoRow('Motor', toy.motorLogic),
          if (toy.isPrecise) _infoRow('Precisión', '0–255 niveles'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() { _keyController.clear(); _foundDevice = null; });
                  },
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: LvsColors.text3)),
                  child: const Text('Agregar otro', style: TextStyle(color: LvsColors.text3)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LvsColors.teal, foregroundColor: Colors.black),
                  onPressed: () {
                    setState(() { _keyController.clear(); _foundDevice = null; });
                    widget.onAdded?.call(); // Ir al tab de catálogo
                  },
                  child: const Text('Ver catálogo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LvsColors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LvsColors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: LvsColors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: const TextStyle(color: LvsColors.text2, fontSize: 12, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
              width: 72,
              child: Text(label,
                  style: TextStyle(color: LvsColors.text3, fontSize: 11))),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Pantalla de Escáner QR (mobile_scanner real)
// ══════════════════════════════════════════════════════════════
class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    _scanned = true;
    _ctrl.stop();
    Navigator.pop(context, barcode!.rawValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Escanear QR del Empaque',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _ctrl.toggleTorch(),
            tooltip: 'Linterna',
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android_rounded),
            onPressed: () => _ctrl.switchCamera(),
            tooltip: 'Cambiar cámara',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Cámara
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
          ),

          // Marco de guía
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: LvsColors.pink, width: 2.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  // Esquinas decorativas
                  _corner(Alignment.topLeft),
                  _corner(Alignment.topRight),
                  _corner(Alignment.bottomLeft),
                  _corner(Alignment.bottomRight),
                ],
              ),
            ),
          ),

          // Instrucción
          Positioned(
            bottom: 60,
            left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Apunta al código QR del empaque del producto',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _corner(Alignment align) {
    const size = 24.0;
    const thick = 4.0;
    return Align(
      alignment: align,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          border: Border(
            top: align == Alignment.topLeft || align == Alignment.topRight
                ? const BorderSide(color: LvsColors.teal, width: thick)
                : BorderSide.none,
            bottom: align == Alignment.bottomLeft || align == Alignment.bottomRight
                ? const BorderSide(color: LvsColors.teal, width: thick)
                : BorderSide.none,
            left: align == Alignment.topLeft || align == Alignment.bottomLeft
                ? const BorderSide(color: LvsColors.teal, width: thick)
                : BorderSide.none,
            right: align == Alignment.topRight || align == Alignment.bottomRight
                ? const BorderSide(color: LvsColors.teal, width: thick)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
