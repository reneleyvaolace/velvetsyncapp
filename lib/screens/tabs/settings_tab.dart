import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lvs_control/ble/ble_service.dart';
import 'package:lvs_control/theme.dart';
import 'package:lvs_control/screens/debug_screen.dart';
import 'package:lvs_control/screens/web_catalog_screen.dart';
import 'package:flutter/services.dart';

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  int _sessionDuration = 30;
  bool _autoDisconnect = false;
  bool _hiddenTimer = false;
  int _hiddenTimerMin = 5;
  int _hiddenTimerMax = 30;

  @override
  Widget build(BuildContext context) {
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
              _buildWebCatalogCard(context),
              const SizedBox(height: 20),
              _buildSettingsCard(ble),
              const SizedBox(height: 20),
              _buildSystemProCard(ble),
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

  Widget _buildWebCatalogCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WebCatalogScreen()),
        );
      },
      child: CardGlass(
        borderColor: LvsColors.violet.withOpacity(0.3),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: LvsColors.violet.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LvsColors.violet.withOpacity(0.3)),
              ),
              child: const Icon(Icons.language, color: LvsColors.violet, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CATÁLOGO WEB', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1, color: LvsColors.violet)),
                  SizedBox(height: 4),
                  Text('Explorar catálogo online en Vercel', style: TextStyle(fontSize: 10, color: LvsColors.text3)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: LvsColors.violet, size: 14),
          ],
        ),
      ),
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
        child: Row(
          children: [
            Image.asset('assets/icons/icon_tab_settings.png', width: 32, height: 32),
            const SizedBox(width: 14),
            const Expanded(child: Text('CONSOLA DE DEPURACIÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: LvsColors.amber))),
            const Icon(Icons.arrow_forward_ios, color: LvsColors.amber, size: 14),
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
  Widget _buildSystemProCard(BleService ble) {
    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('MODO AVANZADO'),
          const SizedBox(height: 20),
          _buildProOption(
            icon: 'assets/icons/icon_timer.png',
            title: 'TEMPORIZADOR DE SESIÓN',
            subtitle: 'Auto-desconexión de seguridad',
            onTap: _showTimerDialog,
          ),
          const Divider(height: 32, color: Colors.white10),
          _buildProOption(
            icon: 'assets/icons/icon_travel_lock.png',
            title: 'BLOQUEO DE VIAJE',
            subtitle: 'Evita encendidos accidentales',
          ),
          const Divider(height: 32, color: Colors.white10),
           _buildProOption(
            icon: 'assets/icons/icon_cloud_save.png',
            title: 'RESPALDO EN NUBE',
            subtitle: 'Sincronizar perfiles y ritmos',
          ),
          const Divider(height: 32, color: Colors.white10),
           _buildProOption(
            icon: 'assets/icons/icon_firmware_update.png',
            title: 'ACTUALIZAR FIRMWARE',
            subtitle: 'v1.4.0 disponible para rMesh',
          ),
        ],
      ),
    );
  }

  Widget _buildProOption({required String icon, required String title, required String subtitle, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Image.asset(icon, width: 38, height: 38),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 9, color: LvsColors.text3)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  void _showTimerDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 8,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                const Row(
                  children: [
                    Icon(Icons.timer_outlined, color: LvsColors.pink, size: 20),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text('TEMPORIZADOR', style: TextStyle(color: LvsColors.text1, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Auto-desconexión
                const Text('AUTO-DESCONEXIÓN', style: TextStyle(color: LvsColors.teal, fontWeight: FontWeight.bold, fontSize: 10)),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Activar ($_sessionDuration min)', style: const TextStyle(color: LvsColors.text1, fontSize: 11)),
                  value: _autoDisconnect,
                  onChanged: (v) => setState(() => _autoDisconnect = v),
                  activeColor: LvsColors.teal,
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Slider(
                    value: _sessionDuration.toDouble(),
                    min: 5, max: 120, divisions: 23,
                    label: '$_sessionDuration min',
                    onChanged: _autoDisconnect ? (v) => setState(() => _sessionDuration = v.round()) : null,
                    activeColor: LvsColors.teal,
                  ),
                ),
                const Divider(height: 28, color: Colors.white10),
                // Temporizador oculto
                const Text('MODO DESAFÍO', style: TextStyle(color: LvsColors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Oculto ($_hiddenTimerMin-$_hiddenTimerMax min)', style: const TextStyle(color: LvsColors.text1, fontSize: 11)),
                  value: _hiddenTimer,
                  onChanged: (v) => setState(() => _hiddenTimer = v),
                  activeColor: LvsColors.red,
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mín: $_hiddenTimerMin', style: TextStyle(color: LvsColors.text2, fontSize: 9)),
                            Slider(
                              value: _hiddenTimerMin.toDouble(),
                              min: 1, max: _hiddenTimerMax - 1,
                              onChanged: _hiddenTimer ? (v) => setState(() => _hiddenTimerMin = v.round()) : null,
                              activeColor: LvsColors.red,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Máx: $_hiddenTimerMax', style: TextStyle(color: LvsColors.text2, fontSize: 9)),
                            Slider(
                              value: _hiddenTimerMax.toDouble(),
                              min: _hiddenTimerMin + 1, max: 60,
                              onChanged: _hiddenTimer ? (v) => setState(() => _hiddenTimerMax = v.round()) : null,
                              activeColor: LvsColors.red,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 8, right: 12),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: LvsColors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: LvsColors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: LvsColors.red, size: 14),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Ráfaga máxima aleatoria sin aviso',
                          style: TextStyle(color: LvsColors.red, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR', style: TextStyle(color: LvsColors.text3)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: LvsColors.pink),
            onPressed: () {
              Navigator.pop(ctx);
              _saveTimerSettings();
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  void _saveTimerSettings() {
    String msg;
    if (_autoDisconnect) {
      msg = 'Auto-desconexión en $_sessionDuration min';
    } else if (_hiddenTimer) {
      msg = 'Modo desafío: $_hiddenTimerMin-$_hiddenTimerMax min';
    } else {
      msg = 'Temporizadores desactivados';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: LvsColors.teal),
    );
  }
}
