import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/services/session/session_timer_service.dart';
import 'package:velvet_sync/screens/backup_screen.dart';
import 'package:velvet_sync/theme.dart';

class SettingsSystemCard extends ConsumerWidget {
  const SettingsSystemCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(sessionTimerStateProvider);

    return CardGlass(
      child: IntrinsicHeight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SectionLabel('MODO AVANZADO'),
            const SizedBox(height: 12),
            _TimerOption(timerState: timerState),
            const Divider(height: 32, color: Colors.white10),
            _TravelLockOption(),
            const Divider(height: 32, color: Colors.white10),
            _DemoModeOption(),
            const Divider(height: 32, color: Colors.white10),
            const _CloudBackupOption(),
            const Divider(height: 32, color: Colors.white10),
            const _FirmwareUpdateOption(),
          ],
        ),
      ),
    );
  }
}

class _TimerOption extends ConsumerStatefulWidget {
  final SessionTimerState timerState;
  const _TimerOption({required this.timerState});

  @override
  ConsumerState<_TimerOption> createState() => _TimerOptionState();
}

class _TimerOptionState extends ConsumerState<_TimerOption> {
  @override
  Widget build(BuildContext context) {
    final isActive = widget.timerState.status == SessionTimerStatus.running;
    final isWarning = widget.timerState.isWarning;

    return SizedBox(
      height: 60,
      child: InkWell(
        onTap: () => _handleTimerAction(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
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
                            width: 8, height: 8,
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
                            widget.timerState.formattedRemaining,
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
                          value: widget.timerState.progress,
                          backgroundColor: const Color(0xFF1A1A2E),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isWarning ? const Color(0xFFFF4444) : const Color(0xFFFF1493),
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        widget.timerState.durationSeconds > 0
                            ? 'Config: ${widget.timerState.formattedDuration}'
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

  Future<void> _handleTimerAction(BuildContext context) async {
    final timerService = ref.read(sessionTimerServiceProvider);
    final ble = ref.read(bleProvider);
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
          if (context.mounted) {
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
}

class _TravelLockOption extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ble = ref.watch(bleProvider);
    final isLocked = ble.isTravelLockActive;

    return InkWell(
      onTap: () async {
        final pin = await _showPinDialog(context);
        if (pin != null) {
          final success = await ble.toggleTravelLock(pin);
          if (!success && context.mounted) {
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
                      color: isLocked ? LvsColors.red : LvsColors.text3,
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
}

class _DemoModeOption extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                color: isDemo ? LvsColors.amber.withValues(alpha: 0.15) : LvsColors.pink.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDemo ? LvsColors.amber.withValues(alpha: 0.4) : Colors.transparent,
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
                            style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: LvsColors.amber, letterSpacing: 1),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDemo ? 'Simulando ${ble.activeToy?.name ?? "dispositivo"}' : 'Probar sin hardware físico',
                    style: TextStyle(fontSize: 9, color: isDemo ? LvsColors.amber : LvsColors.text3),
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
                crossFadeState: isDemo ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                firstChild: const Icon(Icons.check_circle, color: LvsColors.amber, size: 18),
                secondChild: const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloudBackupOption extends StatelessWidget {
  const _CloudBackupOption();
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen())),
      borderRadius: BorderRadius.circular(8),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.cloud_upload, color: LvsColors.teal, size: 38),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RESPALDO EN NUBE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  SizedBox(height: 2),
                  Text('Sincronizar perfiles y ritmos', style: TextStyle(fontSize: 9, color: LvsColors.text3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}

class _FirmwareUpdateOption extends StatelessWidget {
  const _FirmwareUpdateOption();
  @override
  Widget build(BuildContext context) {
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
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.system_update_alt, color: LvsColors.violet, size: 38),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ACTUALIZAR FIRMWARE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  SizedBox(height: 2),
                  Text('Verificar actualizaciones OTA', style: TextStyle(fontSize: 9, color: LvsColors.text3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}
