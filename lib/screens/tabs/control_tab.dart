import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lvs_control/ble/ble_service.dart';
import 'package:lvs_control/theme.dart';
import 'package:lvs_control/widgets/preregister_widget.dart';
import 'dart:math';

class ControlTab extends ConsumerWidget {
  const ControlTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleState = ref.watch(bleProvider.select((p) => p.state));
    final ble = ref.read(bleProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverHeader(ref),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildConnectCard(ref, ble),
              const SizedBox(height: 24),
              _buildControlCard(ref),
              const SizedBox(height: 40),
              if (bleState != BleState.connected)
                const Center(
                  child: Text(
                    'CONECTA UN DISPOSITIVO PARA EMPEZAR',
                    style: TextStyle(color: LvsColors.text3, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold),
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverHeader(WidgetRef ref) {
    final bleState = ref.watch(bleProvider.select((p) => p.state));
    final deviceName = ref.watch(bleProvider.select((p) => p.toyProfile?.name ?? p.connectedDeviceName));

    return SliverAppBar(
      expandedHeight: 120,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Image.asset('assets/images/logo_neon.png', width: 40, height: 40),
              const SizedBox(height: 8),
              const Text('VELVET SYNC', style: TextStyle(
                fontFamily: 'serif', fontSize: 14, letterSpacing: 4, color: Colors.white70, fontWeight: FontWeight.w200
              )),
              if (bleState == BleState.connected)
                Text(deviceName.toUpperCase(), style: const TextStyle(
                  fontSize: 8, fontWeight: FontWeight.w900, color: LvsColors.teal, letterSpacing: 1.5
                )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectCard(WidgetRef ref, BleService ble) {
    final bleState = ref.watch(bleProvider.select((p) => p.state));
    
    return CardGlass(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel('ESTADO DE CONEXIÓN'),
                    SizedBox(height: 4),
                    Text('Auto-Link activo para rMesh v2', style: TextStyle(fontSize: 10, color: LvsColors.text3)),
                  ],
                ),
              ),
              _BleStateBox(state: bleState),
            ],
          ),
          const Divider(height: 32),
          if (bleState != BleState.connected)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: ble.isScanning ? null : () => ble.connectToDevice(),
                    icon: const Icon(Icons.link, size: 18),
                    label: Text(ble.isScanning ? 'BUSCANDO...' : 'VINCULAR AHORA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LvsColors.pink.withOpacity(0.8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const PreRegisterButton(),
              ],
            )
          else
            ElevatedButton.icon(
              onPressed: () => ble.disconnect(),
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('DESCONECTAR DISPOSITIVO'),
              style: ElevatedButton.styleFrom(backgroundColor: LvsColors.red.withOpacity(0.5)),
            ),
        ],
      ),
    );
  }

  Widget _buildControlCard(WidgetRef ref) {
    final bleState = ref.watch(bleProvider.select((p) => p.state));
    if (bleState != BleState.connected) return const SizedBox.shrink();

    final ble = ref.read(bleProvider);
    final int maxIntensity = ref.watch(bleProvider.select((p) => p.displayIntensity));
    final activeSpeed = ref.watch(bleProvider.select((p) => p.activeSpeed));
    final intensityCh1 = ref.watch(bleProvider.select((p) => p.activeIntensityCh1));
    final intensityCh2 = ref.watch(bleProvider.select((p) => p.activeIntensityCh2));

    return Column(
      children: [
        const SectionLabel('INTENSIDAD MAESTRA'),
        const SizedBox(height: 30),
        
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
            Expanded(child: _NeonPresetBtn(label: 'LOW', active: activeSpeed == SpeedLevel.low, color: LvsColors.teal, icon: Icons.wifi_tethering, onTap: () => ble.selectSpeed(SpeedLevel.low))),
            const SizedBox(width: 12),
            Expanded(child: _NeonPresetBtn(label: 'MED', active: activeSpeed == SpeedLevel.medium, color: LvsColors.pink, icon: Icons.radio_button_checked, onTap: () => ble.selectSpeed(SpeedLevel.medium))),
            const SizedBox(width: 12),
            Expanded(child: _NeonPresetBtn(label: 'HIGH', active: activeSpeed == SpeedLevel.high, color: LvsColors.violet, icon: Icons.signal_cellular_alt, onTap: () => ble.selectSpeed(SpeedLevel.high))),
          ],
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
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('CANAL 1 (EMPUJE)', style: TextStyle(fontSize: 9, color: LvsColors.text3, fontWeight: FontWeight.w900)),
                  Text('AUTO-SYNC', style: TextStyle(fontSize: 9, color: LvsColors.teal, fontWeight: FontWeight.w900)),
                ],
              ),
              Slider(
                value: (ble.activePatternCh1 != null ? 0 : (intensityCh1 ?? 0)).toDouble(), min: 0, max: 100,
                onChanged: (v) => ble.setProportionalChannel1(v.round()),
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('CANAL 2 (VIBRACIÓN)', style: TextStyle(fontSize: 9, color: LvsColors.text3, fontWeight: FontWeight.w900)),
                  Text('AUTO-SYNC', style: TextStyle(fontSize: 9, color: LvsColors.pink, fontWeight: FontWeight.w900)),
                ],
              ),
              Slider(
                value: (ble.activePatternCh2 != null ? 0 : (intensityCh2 ?? 0)).toDouble(), min: 0, max: 100,
                onChanged: (v) => ble.setProportionalChannel2(v.round()),
              ),
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
      BleState.scanning   => ('Scanning', LvsColors.amber),
      BleState.connecting => ('Joining',  LvsColors.amber),
      BleState.error      => ('Error',    LvsColors.red),
      BleState.idle       => ('Offline',  LvsColors.text3),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
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
