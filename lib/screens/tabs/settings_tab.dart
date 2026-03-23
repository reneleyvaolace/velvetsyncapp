import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lvs_control/ble/ble_service.dart';
import 'package:lvs_control/theme.dart';
import 'package:lvs_control/screens/debug_screen.dart';
import 'package:lvs_control/screens/web_catalog_screen.dart';
import '../../services/session_timer_service.dart';

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
  bool _travelLock = false;
  String _travelLockPin = '0000';

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(sessionTimerStateProvider);
    final burstInterval = ref.watch(bleProvider.select((p) => p.burstIntervalMs));
    final isDeepScan = ref.watch(bleProvider.select((p) => p.isDeepScan));
    final logs = ref.watch(bleProvider.select((p) => p.logs));

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 80,
          backgroundColor: Colors.transparent,
          flexibleSpace: const FlexibleSpaceBar(
            title: Text('SISTEMA Y CONFIGURACION', style: TextStyle(
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
              _buildSettingsCard(burstInterval, isDeepScan),
              const SizedBox(height: 20),
              _buildSystemProCard(timerState),
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

  Widget _buildSettingsCard(int burstInterval, bool isDeepScan) {
    final ble = ref.read(bleProvider);
    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('PARAMETROS TECNICOS'),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Frecuencia de Rafaga', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
            subtitle: const Text('Ignorar filtros estandar rMesh', style: TextStyle(fontSize: 10, color: LvsColors.text3)),
            value: isDeepScan,
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
            const Expanded(child: Text('CONSOLA DE DEPURACIÃ“N', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: LvsColors.amber))),
            const Icon(Icons.arrow_forward_ios, color: LvsColors.amber, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(List<LogEntry> logs) {
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
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '[${log.time.hour}:${log.time.minute.toString().padLeft(2, '0')}] ${log.msg}',
                    style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: LvsColors.text3),
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
  Widget _buildSystemProCard(SessionTimerState timerState) {
    final timerService = ref.read(sessionTimerServiceProvider);
    final ble = ref.read(bleProvider);

    return CardGlass(
      child: IntrinsicHeight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SectionLabel('MODO AVANZADO'),
            const SizedBox(height: 12),

            // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
            // 1. TEMPORIZADOR DE SESIÃ“N (IMPLEMENTADO)
            // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
            _buildTimerOption(timerState, timerService, ble),

            const Divider(height: 32, color: Colors.white10),

            // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
            // 2. BLOQUEO DE VIAJE (PRÃ“XIMAMENTE)
            // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
            _buildTravelLockOption(),

            const Divider(height: 32, color: Colors.white10),

            // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
            // 3. RESPALDO EN NUBE (PRÃ“XIMAMENTE)
            // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
            _buildCloudBackupOption(),

            const Divider(height: 32, color: Colors.white10),

            // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
            // 4. ACTUALIZACIÃ“N FIRMWARE (PRÃ“XIMAMENTE)
            // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
            _buildFirmwareUpdateOption(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerOption(SessionTimerState timerState, SessionTimerService timerService, BleService ble) {
    final isActive = timerState.status == SessionTimerStatus.running;
    final isWarning = timerState.isWarning;

    return SizedBox(
      height: 60,
      child: InkWell(
        onTap: () => _handleTimerAction(timerService, ble),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LvsColors.pink.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  'assets/icons/icon_timer.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.timer_outlined, size: 20, color: Color(0xFFFF1493)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isActive ? 'TEMPORIZADOR' : 'TEMPORIZADOR',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isWarning ? const Color(0xFFFF4444) : const Color(0xFF00C853),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (isActive) ...[
                      Row(
                        children: [
                          Text(
                            timerState.formattedRemaining,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isWarning ? const Color(0xFFFF4444) : const Color(0xFFFF1493),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Auto-stop',
                              style: const TextStyle(fontSize: 8, color: LvsColors.text3),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 3,
                        child: LinearProgressIndicator(
                          value: timerState.progress,
                          backgroundColor: const Color(0xFF1A1A2E),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isWarning ? const Color(0xFFFF4444) : const Color(0xFFFF1493),
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        timerState.durationSeconds > 0
                            ? 'Config: ${timerState.formattedDuration}'
                            : 'Auto-desconexion',
                        style: const TextStyle(fontSize: 8, color: LvsColors.text3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isActive ? Icons.stop : Icons.chevron_right,
                color: isActive ? const Color(0xFFFF4444) : Colors.white24,
                size: 18,
              ),
            ],
          ),
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
          content: const Text('Â¿QuÃ© deseas hacer?', style: TextStyle(color: Color(0xFF888899))),
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
        // Configurar callback de expiraciÃ³n (auto-stop)
        timerService.onExpired = () {
          // Detener dispositivo BLE cuando expira
          ble.emergencyStop();

          // Mostrar notificaciÃ³n
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('â° TIEMPO EXPIRADO - SesiÃ³n finalizada'),
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

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // PLACEHOLDERS - PRÃ“XIMAMENTE
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildTravelLockOption() {
    return SizedBox(
      height: 56,
      child: InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ðŸ”’ BLOQUEO DE VIAJE - PrÃ³ximamente'),
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
    ),
    );
  }

  Widget _buildCloudBackupOption() {
    return SizedBox(
      height: 56,
      child: InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('â˜ï¸ RESPALDO EN NUBE - PrÃ³ximamente'),
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
    ),
    );
  }

  Widget _buildFirmwareUpdateOption() {
    return SizedBox(
      height: 56,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ðŸ”„ ACTUALIZAR FIRMWARE - PrÃ³ximamente'),
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
    ),
    );
  }
}
