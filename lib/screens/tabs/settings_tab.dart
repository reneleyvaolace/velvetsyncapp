import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/theme.dart';
import 'package:velvet_sync/screens/debug_screen.dart';
import 'package:velvet_sync/services/session/session_timer_service.dart';
import 'package:velvet_sync/services/backend/auth_service.dart';
import 'package:velvet_sync/screens/contacts/my_profile_screen.dart';
import 'package:velvet_sync/screens/backup_screen.dart';
import 'package:velvet_sync/screens/auth_screen.dart';
import 'package:velvet_sync/screens/main_navigation.dart';

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(sessionTimerStateProvider);
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
              _buildSystemProCard(timerState),
              const SizedBox(height: 20),
              _buildAccountCard(),
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
        child: Row(
          children: [
            Icon(Icons.build_circle, color: LvsColors.amber, size: 32),
            const SizedBox(width: 14),
            const Expanded(child: Text('CONSOLA DE DEPURACIÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: LvsColors.amber))),
            const Icon(Icons.arrow_forward_ios, color: LvsColors.amber, size: 14),
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

            // ═══════════════════════════════════════════════════════════════
            // 1. TEMPORIZADOR DE SESIÓN (IMPLEMENTADO)
            // ═══════════════════════════════════════════════════════════════
            _buildTimerOption(timerState, timerService, ble),

            const Divider(height: 32, color: Colors.white10),

            // ═══════════════════════════════════════════════════════════════
            // 2. BLOQUEO DE VIAJE (IMPLEMENTADO)
            // ═══════════════════════════════════════════════════════════════
            _buildTravelLockOption(),

            const Divider(height: 32, color: Colors.white10),

            // ═══════════════════════════════════════════════════════════════
            // 3. MODO DEMO
            // ═══════════════════════════════════════════════════════════════
            _buildDemoModeOption(),

            const Divider(height: 32, color: Colors.white10),

            // ═══════════════════════════════════════════════════════════════
            // 4. RESPALDO EN NUBE (PRÓXIMAMENTE)
            // ═══════════════════════════════════════════════════════════════
            _buildCloudBackupOption(),

            const Divider(height: 32, color: Colors.white10),

            // ═══════════════════════════════════════════════════════════════
            // 5. ACTUALIZACIÓN FIRMWARE (PRÓXIMAMENTE)
            // ═══════════════════════════════════════════════════════════════
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
                child: const Icon(Icons.timer_outlined, size: 24, color: LvsColors.pink),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'TEMPORIZADOR',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
                          const Expanded(
                            child: Text(
                              'Auto-stop',
                              style: TextStyle(fontSize: 8, color: LvsColors.text3),
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
                            : 'Auto-desconexión',
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
      final minutes = await showSessionTimerDialog(context);
      if (minutes != null && minutes > 0) {
        timerService.onExpired = () {
          ble.emergencyStop();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⌛ TIEMPO EXPIRADO - Sesión finalizada'),
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

  Widget _buildTravelLockOption() {
    final ble = ref.watch(bleProvider);
    final isLocked = ble.isTravelLockActive;

    return InkWell(
      onTap: () async {
        final pin = await _showPinDialog(context);
        if (pin != null) {
          final success = await ble.toggleTravelLock(pin);
          if (!success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PIN INCORRECTO'), backgroundColor: LvsColors.red),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: isLocked ? LvsColors.red.withValues(alpha: 0.1) : LvsColors.violet.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(isLocked ? Icons.lock : Icons.lock_open, color: isLocked ? LvsColors.red : LvsColors.violet, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'BLOQUEO DE VIAJE',
                    style: TextStyle(
                      fontSize: 11, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 0.5,
                      color: isLocked ? LvsColors.red : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isLocked ? 'ESTADO: ACTIVADO' : 'ESTADO: DESACTIVADO',
                    style: TextStyle(
                      fontSize: 9, 
                      fontWeight: FontWeight.bold,
                      color: isLocked ? LvsColors.red : LvsColors.text3
                    ),
                  ),
                  if (!isLocked)
                    const Text(
                      'Evita encendidos accidentales',
                      style: TextStyle(fontSize: 8, color: LvsColors.text3),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: isLocked ? LvsColors.red : Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  Future<String?> _showPinDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LvsColors.bgCard,
        title: const Text('INGRESAR PIN (Default: 0000)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          style: const TextStyle(letterSpacing: 20, fontSize: 24),
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('CONFIRMAR')),
        ],
      ),
    );
  }

  Widget _buildDemoModeOption() {
    final ble = ref.watch(bleProvider);
    final isDemo = ble.isDemoMode;

    return InkWell(
      onTap: () => ble.toggleDemoMode(),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: isDemo
                    ? LvsColors.amber.withValues(alpha: 0.15)
                    : LvsColors.pink.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDemo
                      ? LvsColors.amber.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isDemo
                    ? const Icon(Icons.science, key: ValueKey('on'), color: LvsColors.amber, size: 20)
                    : const Icon(Icons.science_outlined, key: ValueKey('off'), color: LvsColors.pink, size: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'MODO DEMO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: isDemo ? LvsColors.amber : Colors.white,
                        ),
                      ),
                      if (isDemo) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: LvsColors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: LvsColors.amber.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'ACTIVO',
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
                              color: LvsColors.amber,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDemo
                        ? 'Simulando ${ble.activeToy?.name ?? "dispositivo"}'
                        : 'Probar sin hardware físico',
                    style: TextStyle(
                      fontSize: 9,
                      color: isDemo ? LvsColors.amber : LvsColors.text3,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDemo ? LvsColors.amber.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: isDemo
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: const Icon(Icons.check_circle, color: LvsColors.amber, size: 18),
                secondChild: const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudBackupOption() {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BackupScreen()),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.cloud_upload, color: LvsColors.teal, size: 38),
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
            const Icon(Icons.system_update_alt, color: LvsColors.violet, size: 38),
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

  Widget _buildAccountCard() {
    final auth = ref.watch(authServiceProvider);
    final isAnon = auth.isAnonymous;

    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('CUENTA'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: LvsColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Icon(isAnon ? Icons.person_outline : Icons.person, color: isAnon ? LvsColors.text3 : LvsColors.teal, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAnon ? 'INVITADO' : (auth.email ?? 'USUARIO'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isAnon ? LvsColors.text3 : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAnon ? 'Sin sesión iniciada' : 'Sesión activa',
                        style: const TextStyle(fontSize: 9, color: LvsColors.text3),
                      ),
                    ],
                  ),
                ),
                if (!isAnon)
                  TextButton(
                    onPressed: () async {
                      await auth.signOut();
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AuthScreen(
                              onSkip: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const MainNavigation()),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('CERRAR\nSESIÓN', style: TextStyle(fontSize: 8, color: LvsColors.red, letterSpacing: 1)),
                  ),
              ],
            ),
          ),
          if (!isAnon) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: LvsColors.bgCard,
                      title: const Text('ELIMINAR CUENTA', style: TextStyle(fontSize: 14, color: LvsColors.red)),
                      content: const Text(
                        'Esta acción eliminará permanentemente tu cuenta y todos tus datos. ¿Estás seguro?',
                        style: TextStyle(fontSize: 12, color: LvsColors.text3),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR', style: TextStyle(color: LvsColors.text3))),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ELIMINAR', style: TextStyle(color: LvsColors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final ok = await auth.deleteAccount();
                    if (ok && mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AuthScreen(
                            onSkip: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const MainNavigation()),
                            ),
                          ),
                        ),
                      );
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(auth.errorMessage ?? 'Error al eliminar cuenta'),
                          backgroundColor: LvsColors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.delete_forever, size: 16, color: LvsColors.red),
                label: const Text('ELIMINAR CUENTA', style: TextStyle(fontSize: 10, color: LvsColors.red, letterSpacing: 1)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
