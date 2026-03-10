import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lvs_control/ble/ble_service.dart';
import 'package:lvs_control/theme.dart';
import 'package:lvs_control/screens/debug_screen.dart';
import 'package:flutter/services.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ble = ref.watch(bleProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 80,
          backgroundColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text('SISTEMA Y CONFIGURACIÓN', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4, color: LvsColors.text3
            )),
            centerTitle: true,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildSettingsCard(ble),
              const SizedBox(height: 20),
              _buildDebugButton(context),
              const SizedBox(height: 20),
              _buildLogCard(ble),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(BleService ble) {
    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('PARÁMETROS TÉCNICOS'),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Frecuencia de Ráfaga', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${ble.burstIntervalMs}ms', style: const TextStyle(fontSize: 12, color: LvsColors.pink, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: ble.burstIntervalMs.toDouble(),
            min: 100, max: 1000, divisions: 18,
            onChanged: (v) => ble.setBurstInterval(v.round()),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('DEEP SCAN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: const Text('Ignorar filtros estándar rMesh', style: TextStyle(fontSize: 10, color: LvsColors.text3)),
            value: ble.isDeepScan,
            onChanged: (v) => ble.toggleDeepScan(),
            activeColor: LvsColors.pink,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildDebugButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebugScreen())),
      child: CardGlass(
        borderColor: LvsColors.amber.withOpacity(0.2),
        padding: const EdgeInsets.all(16),
        child: const Row(
          children: [
            Icon(Icons.terminal, color: LvsColors.amber, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text('CONSOLA DE DEPURACIÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: LvsColors.amber))),
            Icon(Icons.arrow_forward_ios, color: LvsColors.amber, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(BleService ble) {
    if (ble.logs.isEmpty) return const SizedBox.shrink();
    return CardGlass(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SectionLabel('ACTIVIDAD DEL SISTEMA'),
              const Spacer(),
              IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: LvsColors.text3), onPressed: ble.clearLogs),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: ble.logs.length,
              itemBuilder: (_, i) {
                final log = ble.logs[ble.logs.length - 1 - i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '[${log.time.hour}:${log.time.minute}] ${log.msg}',
                    style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: LvsColors.text3),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
