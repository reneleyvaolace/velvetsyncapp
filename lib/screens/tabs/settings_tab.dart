import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lvs_control/ble/ble_service.dart';
import 'package:lvs_control/theme.dart';
import 'package:lvs_control/screens/debug_screen.dart';
import 'package:flutter/services.dart';
import '../../services/session_timer_service.dart';
import '../../ble/ble_service.dart' as ble_service;

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(sessionTimerStateProvider);
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
              _buildSystemProCard(timerState),
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
  Widget _buildSystemProCard(SessionTimerState timerState) {
    final timerService = ref.read(sessionTimerServiceProvider);
    final ble = ref.read(bleProvider);

    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('MODO AVANZADO'),
          const SizedBox(height: 12),

          // ═══════════════════════════════════════════════════════════════
          // 1. TEMPORIZADOR DE SESIÓN (IMPLEMENTADO)
          // ═══════════════════════════════════════════════════════════════
          _buildTimerOption(timerState, timerService, ble),

          const Divider(height: 32, color: Colors.white10),

          // ═══════════════════════════════════════════════════════════════
          // 2. BLOQUEO DE VIAJE (PRÓXIMAMENTE)
          // ═══════════════════════════════════════════════════════════════
          _buildTravelLockOption(),

          const Divider(height: 32, color: Colors.white10),

          // ═══════════════════════════════════════════════════════════════
          // 3. RESPALDO EN NUBE (PRÓXIMAMENTE)
          // ═══════════════════════════════════════════════════════════════
          _buildCloudBackupOption(),

          const Divider(height: 32, color: Colors.white10),

          // ═══════════════════════════════════════════════════════════════
          // 4. ACTUALIZACIÓN FIRMWARE (PRÓXIMAMENTE)
          // ═══════════════════════════════════════════════════════════════
          _buildFirmwareUpdateOption(),
        ],
      ),
    );
  }

  Widget _buildTimerOption(SessionTimerState timerState, SessionTimerService timerService, BleService ble) {
    final isActive = timerState.status == SessionTimerStatus.running;
    final isWarning = timerState.isWarning;

    return InkWell(
      onTap: () => _handleTimerAction(timerService, ble),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Ícono con animación si está activo
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive
                    ? (isWarning ? const Color(0xFFFF1493).withOpacity(0.2) : const Color(0xFFFF1493).withOpacity(0.1))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isActive ? Icons.timer : Icons.timer_outlined,
                color: isWarning ? const Color(0xFFFF4444) : const Color(0xFFFF1493),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'TEMPORIZADOR DE SESIÓN',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isWarning ? const Color(0xFFFF4444) : const Color(0xFF00C853),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isWarning ? '⚠️' : '●',
                            style: const TextStyle(fontSize: 8, color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (isActive) ...[
                    // Tiempo restante grande
                    Text(
                      timerState.formattedRemaining,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isWarning ? const Color(0xFFFF4444) : const Color(0xFFFF1493),
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Barra de progreso
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: timerState.progress,
                        backgroundColor: const Color(0xFF1A1A2E),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isWarning ? const Color(0xFFFF4444) : const Color(0xFFFF1493),
                        ),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Auto-desconexión en ${timerState.formattedRemaining}',
                      style: const TextStyle(fontSize: 9, color: LvsColors.text3),
                    ),
                  ] else ...[
                    const Text(
                      'Auto-desconexión de seguridad',
                      style: TextStyle(fontSize: 9, color: LvsColors.text3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timerState.durationSeconds > 0
                          ? 'Configurado: ${timerState.formattedDuration}'
                          : 'No configurado',
                      style: const TextStyle(fontSize: 9, color: LvsColors.text3),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              isActive ? Icons.stop : Icons.chevron_right,
              color: isActive ? const Color(0xFFFF4444) : Colors.white24,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTimerAction(SessionTimerService timerService, BleService ble) async {
    final isActive = timerService.isActive;

    if (isActive) {
      // Mostrar opciones: Pausar o Detener
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF0A0A14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('TEMPORIZADOR ACTIVO', style: TextStyle(color: Colors.white)),
          content: const Text('¿Qué deseas hacer?', style: TextStyle(color: Color(0xFF888899))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'pause'),
              child: const Text('PAUSAR', style: TextStyle(color: Color(0xFFFF1493))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'stop'),
              child: const Text('DETENER', style: TextStyle(color: Color(0xFFFF4444))),
            ),
          ],
        ),
      );

      if (action == 'pause') {
        timerService.pause();
      } else if (action == 'stop') {
        timerService.stop();
      }
    } else {
      // Mostrar dialog para configurar
      final minutes = await showSessionTimerDialog(context);
      if (minutes != null && minutes > 0) {
        // Configurar callback de expiración (auto-stop)
        timerService.onExpired = () {
          // Detener dispositivo BLE cuando expira
          ble.emergencyStop();

          // Mostrar notificación
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⏰ TIEMPO EXPIRADO - Sesión finalizada'),
                backgroundColor: Color(0xFFFF1493),
                duration: Duration(seconds: 5),
              ),
            );
          }
        };

        timerService.setDurationMinutes(minutes);
        timerService.start();
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // PLACEHOLDERS - PRÓXIMAMENTE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTravelLockOption() {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔒 BLOQUEO DE VIAJE - Próximamente'),
            backgroundColor: Color(0xFF888899),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Image.asset('assets/icons/icon_travel_lock.png', width: 38, height: 38),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BLOQUEO DE VIAJE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Evita encendidos accidentales',
                    style: TextStyle(fontSize: 9, color: LvsColors.text3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudBackupOption() {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('☁️ RESPALDO EN NUBE - Próximamente'),
            backgroundColor: Color(0xFF888899),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Image.asset('assets/icons/icon_cloud_save.png', width: 38, height: 38),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RESPALDO EN NUBE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Sincronizar perfiles y ritmos',
                    style: TextStyle(fontSize: 9, color: LvsColors.text3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildFirmwareUpdateOption() {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔄 ACTUALIZAR FIRMWARE - Próximamente'),
            backgroundColor: Color(0xFF888899),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Image.asset('assets/icons/icon_firmware_update.png', width: 38, height: 38),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACTUALIZAR FIRMWARE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Verificar actualizaciones OTA',
                    style: TextStyle(fontSize: 9, color: LvsColors.text3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildProOption({required String icon, required String title, required String subtitle}) {
    return Row(
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
    );
  }
}
