import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/theme.dart';
import 'package:velvet_sync/screens/debug_screen.dart';
import 'package:velvet_sync/screens/contacts/my_profile_screen.dart';
import 'package:velvet_sync/widgets/settings_account_card.dart';
import 'package:velvet_sync/widgets/settings_system_card.dart';

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  @override
  Widget build(BuildContext context) {
    final burstInterval = ref.watch(bleProvider.select((p) => p.burstIntervalMs));
    final isDeepScan = ref.watch(bleProvider.select((p) => p.isDeepScan));
    final logs = ref.watch(bleProvider.select((p) => p.logs));

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverAppBar(
          expandedHeight: 80,
          backgroundColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            title: Text('SISTEMA Y CONFIGURACIÓN', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4, color: LvsColors.text3
            )),
            centerTitle: true,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([

              _buildMyProfileCard(context),
              const SizedBox(height: 20),
              _buildSettingsCard(burstInterval, isDeepScan),
              const SizedBox(height: 20),
              const SettingsSystemCard(),
              const SizedBox(height: 20),
              const SettingsAccountCard(),
              const SizedBox(height: 20),
              _buildDebugButton(context),
              const SizedBox(height: 20),
              _buildLogCard(logs),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildMyProfileCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyProfileScreen()),
        );
      },
      child: CardGlass(
        borderColor: LvsColors.teal.withValues(alpha: 0.3),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: LvsColors.teal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LvsColors.teal.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.person, color: LvsColors.teal, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MI PERFIL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1, color: LvsColors.teal)),
                  SizedBox(height: 4),
                  Text('Ver nombre de usuario y editar datos', style: TextStyle(fontSize: 10, color: LvsColors.text3)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: LvsColors.teal, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(int burstInterval, bool isDeepScan) {
    final ble = ref.read(bleProvider);
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
              Text('$burstInterval ms', style: const TextStyle(fontSize: 12, color: LvsColors.pink, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: burstInterval.toDouble(),
            min: 100, max: 1000, divisions: 18,
            onChanged: (v) => ble.setBurstInterval(v.round()),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('DEEP SCAN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: const Text('Ignorar filtros estándar rMesh', style: TextStyle(fontSize: 10, color: LvsColors.text3)),
            value: isDeepScan,
            onChanged: (v) => ble.toggleDeepScan(),
            activeTrackColor: LvsColors.pink,
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
        borderColor: LvsColors.amber.withValues(alpha: 0.2),
        padding: const EdgeInsets.all(16),
        child: const Row(
          children: [
            Icon(Icons.build_circle, color: LvsColors.amber, size: 32),
            SizedBox(width: 14),
            Expanded(child: Text('CONSOLA DE DEPURACIÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: LvsColors.amber))),
            Icon(Icons.arrow_forward_ios, color: LvsColors.amber, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(List<BleLogEntry> logs) {
    final ble = ref.read(bleProvider);
    if (logs.isEmpty) return const SizedBox.shrink();
    
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
              itemCount: logs.length,
              cacheExtent: 50,
              itemBuilder: (_, i) {
                final log = logs[logs.length - 1 - i];
                Color logColor;
                switch (log.type) {
                  case 'error':
                    logColor = LvsColors.red;
                    break;
                  case 'warn':
                    logColor = LvsColors.amber;
                    break;
                  case 'success':
                    logColor = LvsColors.teal;
                    break;
                  case 'cmd':
                    logColor = const Color(0xFF00F5FF);
                    break;
                  case 'debug':
                    logColor = const Color(0xFF00FFCC);
                    break;
                  default:
                    logColor = const Color(0xFFFFD700);
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '[${log.time.hour}:${log.time.minute.toString().padLeft(2, '0')}] ${log.msg}',
                    style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: logColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
