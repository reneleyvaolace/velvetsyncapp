import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lvs_control/ble/ble_service.dart';
import 'package:lvs_control/models/toy_model.dart';
import 'package:lvs_control/theme.dart';
import 'package:lvs_control/widgets/preregister_widget.dart';
import 'package:lvs_control/services/catalog_service.dart';
import 'package:lvs_control/ble/lvs_commands.dart';
import 'package:lvs_control/widgets/quick_add_control.dart';
import 'package:lvs_control/widgets/compatible_devices_row.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';

class ControlTab extends ConsumerWidget {
  const ControlTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleState = ref.watch(bleProvider.select((p) => p.state));
    final ble = ref.watch(bleProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverHeader(ref),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildConnectCard(ref, ble),
              const SizedBox(height: 16),
              // Quick Add — fuera del card para evitar overflow
              if (!ble.isConnected) ...([ 
                CardGlass(
                  padding: const EdgeInsets.all(20),
                  child: QuickAddControl(ref: ref),
                ),
                const SizedBox(height: 16),
                // Lista de dispositivos compatibles
                CardGlass(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: const CompatibleDevicesRow(),
                ),
              ]),
              const SizedBox(height: 24),
              _buildControlCard(ref),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverHeader(WidgetRef ref) {
    final deviceName = ref.watch(bleProvider.select((p) => p.activeToy?.name ?? 'DISPOSITIVO'));
    final isConnected = ref.watch(bleProvider.select((p) => p.isConnected));

    return SliverAppBar(
      expandedHeight: 100,
      backgroundColor: Colors.transparent,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('VELVET SYNC', style: GoogleFonts.cinzel(
              fontSize: 11, letterSpacing: 4, color: Colors.white70, fontWeight: FontWeight.w300
            )),
            Text(deviceName.toUpperCase(), style: TextStyle(
              fontSize: 7, fontWeight: FontWeight.w900, color: isConnected ? LvsColors.teal : LvsColors.text3, letterSpacing: 1.5
            )),
          ],
        ),
        background: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 25),
            child: Image.asset('assets/images/logo_neon.png', width: 62, height: 62),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectCard(WidgetRef ref, BleService ble) {
    final bleState = ref.watch(bleProvider.select((p) => p.state));
    
    return CardGlass(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset('assets/icons/icon_bluetooth.png', width: 20, height: 20),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: SectionLabel('ESTADO DE CONEXIÓN'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Auto-Link activo para rMesh v2', style: TextStyle(fontSize: 10, color: LvsColors.text3)),
                  ],
                ),
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _BleStateBox(state: bleState),
                    if (ble.isConnected) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StatusIcon(icon: 'assets/icons/icon_battery.png', label: '85%'),
                          const SizedBox(width: 4),
                          _StatusIcon(icon: 'assets/icons/icon_signal_strength.png', label: 'GOOD'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (!ble.isConnected) ...[  
            const Divider(height: 20),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.link_off, color: Colors.white24, size: 20),
                SizedBox(width: 10),
                Text(
                  'Sin dispositivo — usa el panel de abajo',
                  style: TextStyle(color: LvsColors.text3, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          // ═══════════════════════════════════════════════════════════════
          // ESTADO: DISPOSITIVO VINCULADO
          // ═══════════════════════════════════════════════════════════════
          const Divider(height: 24, color: Colors.white10),
          
          // Tarjeta del dispositivo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  LvsColors.teal.withOpacity(0.15),
                  LvsColors.bgCard.withOpacity(0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LvsColors.teal.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: LvsColors.teal.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                // Icono grande del dispositivo
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: LvsColors.teal.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: LvsColors.teal.withOpacity(0.5), width: 2),
                  ),
                  child: Icon(
                    _getDeviceIcon(ble.activeToy),
                    color: LvsColors.teal,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Nombre del dispositivo
                Text(
                  ble.activeToy?.name.toUpperCase() ?? ble.connectedDeviceName.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                
                // ID y tipo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: LvsColors.bgCardH.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ID: ${ble.activeToy?.id ?? ble.toyProfile?.identifier ?? "---"}',
                    style: const TextStyle(color: LvsColors.teal, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Botón de renombrar
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showRenameDialog(ref, ble),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('RENOMBRAR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LvsColors.teal,
                      side: BorderSide(color: LvsColors.teal.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Botón desvincular
          ElevatedButton.icon(
            onPressed: () => ble.disconnect(),
            icon: const Icon(Icons.link_off, size: 18),
            label: const Text('DESVINCULAR DISPOSITIVO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.15),
              foregroundColor: Colors.redAccent,
              elevation: 0,
              side: BorderSide(color: Colors.red.withOpacity(0.3)),
              minimumSize: const Size(double.infinity, 48),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
        ],
      ),
    );
  }

  void _showRenameDialog(WidgetRef ref, BleService ble) {
    final controller = TextEditingController(text: ble.activeToy?.name ?? ble.connectedDeviceName);
    showDialog(
      context: ref.context,
      builder: (context) => AlertDialog(
        backgroundColor: LvsColors.bg,
        title: const Text('RENOMBRAR DISPOSITIVO', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nombre personalizado',
            hintStyle: TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: LvsColors.pink)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                // Actualizar en el catálogo primero para persistencia
                ref.read(catalogProvider.notifier).updateDevice(
                  ble.activeToy?.id ?? '', 
                  controller.text, 
                  ''
                );
                Navigator.pop(context);
              }
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  Widget _buildControlCard(WidgetRef ref) {
    final ble = ref.watch(bleProvider);
    if (!ble.isConnected) return const SizedBox.shrink();

    final activeToy = ref.watch(bleProvider.select((p) => p.activeToy));
    final int maxIntensity = ref.watch(bleProvider.select((p) => p.displayIntensity));
    final activeSpeed = ref.watch(bleProvider.select((p) => p.activeSpeed));
    final intensityCh1 = ref.watch(bleProvider.select((p) => p.activeIntensityCh1));
    final intensityCh2 = ref.watch(bleProvider.select((p) => p.activeIntensityCh2));

    return Column(
      children: [
        if (activeToy != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: activeToy.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: activeToy.imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => Center(child: Image.asset(activeToy.iconAsset, width: 80, height: 80)),
                      errorWidget: (_, __, ___) => Center(child: Image.asset(activeToy.iconAsset, width: 80, height: 80)),
                    )
                  : Center(child: Image.asset(activeToy.iconAsset, width: 80, height: 80)),
              ),
            ),
          ),
        const SectionLabel('INTENSIDAD MAESTRA'),
        const SizedBox(height: 20),
        
        RepaintBoundary(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 260, height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: LvsColors.red.withValues(alpha: 0.15),   blurRadius: 60, spreadRadius: 5, offset: const Offset(-20, 0)),
                    BoxShadow(color: LvsColors.pink.withValues(alpha: 0.15), blurRadius: 60, spreadRadius: 5, offset: const Offset(-10, 0)),
                    BoxShadow(color: LvsColors.violet.withValues(alpha: 0.15), blurRadius: 60, spreadRadius: 5, offset: const Offset(20, 0)),
                  ]
                ),
              ),
              Container(
                width: 230, height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 12),
                ),
              ),
              SizedBox(
                width: 230, height: 230,
                child: ShaderMask(
                  shaderCallback: (r) => const SweepGradient(
                    colors: [LvsColors.pink, LvsColors.red, LvsColors.pink, LvsColors.violet, LvsColors.pink],
                    stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                    transform: GradientRotation(-pi/4),
                  ).createShader(r),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: maxIntensity.toDouble()),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    builder: (context, val, _) => CircularProgressIndicator(
                      value: val / 100,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${maxIntensity.round()}%', style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w200, color: Colors.white, letterSpacing: -2)),
                  const Text('POTENCIA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: LvsColors.text3, letterSpacing: 2)),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 40),
        
        Row(
          children: [
            Expanded(child: _NeonPresetBtn(label: 'BAJO', active: activeSpeed == SpeedLevel.low, color: LvsColors.teal, icon: Icons.wifi_tethering, onTap: () => ble.selectSpeed(SpeedLevel.low))),
            const SizedBox(width: 12),
            Expanded(child: _NeonPresetBtn(label: 'MED', active: activeSpeed == SpeedLevel.medium, color: LvsColors.pink, icon: Icons.radio_button_checked, onTap: () => ble.selectSpeed(SpeedLevel.medium))),
            const SizedBox(width: 12),
            Expanded(child: _NeonPresetBtn(label: 'ALTO', active: activeSpeed == SpeedLevel.high, color: LvsColors.violet, icon: Icons.signal_cellular_alt, onTap: () => ble.selectSpeed(SpeedLevel.high))),
          ],
        ),
        
        const SizedBox(height: 24),
        
        ElevatedButton.icon(
          onPressed: () => ble.emergencyStop(),
          icon: Image.asset('assets/icons/icon_cool_down.png', width: 28, height: 28),
          label: const Text('STOP DE EMERGENCIA (ALTO)', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          style: ElevatedButton.styleFrom(
            backgroundColor: LvsColors.red,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 12,
            shadowColor: LvsColors.red.withOpacity(0.4),
          ),
        ),
        
        const SizedBox(height: 32),
        
        SliderTheme(
          data: SliderTheme.of(ref.context).copyWith(
            activeTrackColor: LvsColors.teal,
            inactiveTrackColor: LvsColors.bgCardH,
            thumbColor: Colors.white,
            overlayColor: LvsColors.teal.withOpacity(0.1),
            trackHeight: 2,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(activeToy?.hasDualChannel ?? false ? 'CANAL 1 (EMPUJE)' : 'INTENSIDAD', style: const TextStyle(fontSize: 9, color: LvsColors.text3, fontWeight: FontWeight.w900)),
                  const Text('AUTO-SYNC', style: TextStyle(fontSize: 9, color: LvsColors.teal, fontWeight: FontWeight.w900)),
                ],
              ),
              Slider(
                value: (ble.activePatternCh1 != null ? 0 : (intensityCh1 ?? 0)).toDouble(), min: 0, max: 100,
                onChanged: (v) => ble.setProportionalChannel1(v.round()),
              ),
              if (activeToy?.hasDualChannel ?? false) ...[
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('CANAL 2 (VIBRACIÓN)', style: TextStyle(fontSize: 9, color: LvsColors.text3, fontWeight: FontWeight.w900)),
                    Text('PROPORCIONAL', style: TextStyle(fontSize: 9, color: LvsColors.pink, fontWeight: FontWeight.w900)),
                  ],
                ),
                Slider(
                  value: (intensityCh2 ?? 0).toDouble(), min: 0, max: 100,
                  onChanged: (v) => ble.setProportionalChannel2(v.round()),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// Estos widgets los extraeremos luego a un archivo común, por ahora los duplicamos para rapidez
class _BleStateBox extends StatelessWidget {
  final BleState state;
  const _BleStateBox({required this.state});
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: color, pulse: state == BleState.scanning || state == BleState.connecting),
          const SizedBox(width: 8),
          Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: color)),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final Color color;
  final bool pulse;
  const _Dot({required this.color, required this.pulse});
  @override
  State<_Dot> createState() => _DotState();
}
class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return widget.pulse ? AnimatedBuilder(animation: _c, builder: (_, __) => Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.color.withOpacity(_c.value), shape: BoxShape.circle))) : Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle));
  }
}

// ═══════════════════════════════════════════════════════════════
// Helper para obtener ícono del dispositivo
// ═══════════════════════════════════════════════════════════════
IconData _getDeviceIcon(ToyModel? toy) {
  if (toy == null) return Icons.devices;
  
  final name = toy.name.toLowerCase();
  final anatomy = toy.targetAnatomy.toLowerCase();
  final type = toy.usageType.toLowerCase();
  
  // Por anatomía
  if (anatomy.contains('anal') || name.contains('zen')) return Icons.spa;
  if (anatomy.contains('clitor') || name.contains('luna')) return Icons.local_florist;
  if (anatomy.contains('prostat')) return Icons.favorite;
  if (anatomy.contains('penian') || name.contains('ring')) return Icons.electric_bolt;
  if (anatomy.contains('kegel')) return Icons.self_improvement;
  
  // Por tipo
  if (type.contains('insertable')) return Icons.water_drop;
  if (type.contains('wearable')) return Icons.brightness_1;
  
  // Default
  return Icons.devices;
}

class _NeonPresetBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData icon;
  final Color color;
  const _NeonPresetBtn({required this.label, required this.active, required this.onTap, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? color : color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? color : color.withOpacity(0.6), size: 16),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1, color: active ? Colors.white : LvsColors.text1)),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final String icon;
  final String label;
  const _StatusIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(icon, width: 14, height: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white70)),
        ],
      ),
    );
  }
}
