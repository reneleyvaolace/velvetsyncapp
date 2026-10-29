// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/screens/calls/outgoing_call_screen.dart
// Pantalla de llamada saliente
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/calls/call_models.dart';
import 'package:velvet_sync/services/calls/call_controller.dart';
import 'package:velvet_sync/theme.dart';
import 'package:velvet_sync/utils/logger.dart';

class OutgoingCallScreen extends ConsumerStatefulWidget {
  final CallModel call;
  const OutgoingCallScreen({super.key, required this.call});

  @override
  ConsumerState<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends ConsumerState<OutgoingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _timeoutTimer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Timeout de 60 segundos para contestar
    _timeoutTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) _cancelCall();
    });

    // Timer para mostrar duración de "llamando..."
    Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _cancelCall() async {
    _timeoutTimer?.cancel();
    try {
      await ref.read(callControllerProvider).cancelCall();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      lvsError('Error cancelando llamada: $e', tag: 'OUTGOING_CALL');
    }
  }

  void _endCall() async {
    _timeoutTimer?.cancel();
    try {
      await ref.read(callControllerProvider).endCall();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      lvsError('Error finalizando llamada: $e', tag: 'OUTGOING_CALL');
    }
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final callState = ref.watch(callStateProvider);
    final currentCall = callState.value ?? call;

    return Scaffold(
      backgroundColor: LvsColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Estado de la llamada
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getStateColor(currentCall.state).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      call.type == CallType.video 
                          ? Icons.videocam_rounded 
                          : Icons.call_rounded,
                      color: _getStateColor(currentCall.state),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getStateText(currentCall.state),
                      style: TextStyle(
                        color: _getStateColor(currentCall.state),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Avatar del callee
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _getStateColor(currentCall.state).withValues(alpha: 0.5),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getStateColor(currentCall.state).withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: call.calleeAvatar != null && call.calleeAvatar!.isNotEmpty
                        ? Image.network(
                            call.calleeAvatar!,
                            fit: BoxFit.cover,
                            width: 140,
                            height: 140,
                            errorBuilder: (_, __, ___) => _defaultAvatar(),
                          )
                        : _defaultAvatar(),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Nombre del callee
              Text(
                call.calleeName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Estado/timer
              Text(
                currentCall.state == CallState.ringing
                    ? 'Llamando... ${_formatTime(_seconds)}'
                    : _getStateSubtext(currentCall.state),
                style: TextStyle(
                  color: LvsColors.text3,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 40),

              // Controles
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (currentCall.state == CallState.active) ...[
                    // Mute audio
                    _buildControlButton(
                      icon: ref.watch(callStateProvider).value?.isMuted == true
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      label: 'Mute',
                      color: ref.watch(callStateProvider).value?.isMuted == true
                          ? LvsColors.red
                          : LvsColors.teal,
                      onTap: () => ref.read(callControllerProvider).toggleMute(),
                    ),
                    const SizedBox(width: 24),

                    // Mute video
                    _buildControlButton(
                      icon: ref.watch(callStateProvider).value?.isVideoMuted == true
                          ? Icons.videocam_off_rounded
                          : Icons.videocam_rounded,
                      label: 'Video',
                      color: ref.watch(callStateProvider).value?.isVideoMuted == true
                          ? LvsColors.red
                          : LvsColors.teal,
                      onTap: () => ref.read(callControllerProvider).toggleVideoMute(),
                    ),
                    const SizedBox(width: 24),

                    // Speaker
                    _buildControlButton(
                      icon: ref.watch(callStateProvider).value?.isSpeakerOn == true
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      label: 'Audio',
                      color: ref.watch(callStateProvider).value?.isSpeakerOn == true
                          ? LvsColors.teal
                          : LvsColors.violet,
                      onTap: () => ref.read(callControllerProvider).toggleSpeaker(),
                    ),
                    const SizedBox(width: 24),

                    // Switch camera
                    _buildControlButton(
                      icon: Icons.flip_camera_android_rounded,
                      label: 'Cámara',
                      color: LvsColors.violet,
                      onTap: () => ref.read(callControllerProvider).switchCamera(),
                    ),
                  ] else ...[
                    // Solo cancelar si no está activa
                    _buildActionButton(
                      icon: Icons.call_end_rounded,
                      label: currentCall.state == CallState.ringing
                          ? 'Cancelar'
                          : 'Colgar',
                      color: LvsColors.red,
                      onTap: currentCall.state == CallState.ringing
                          ? () => ref.read(callControllerProvider).cancelCall()
                          : () => ref.read(callControllerProvider).endCall(),
                      size: 72,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 40),

              // Timer
              if (currentCall.state == CallState.active)
                Text(
                  _formatTime(callState.value?.durationSeconds ?? _seconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStateColor(CallState state) {
    switch (state) {
      case CallState.connecting:
      case CallState.ringing:
        return LvsColors.amber;
      case CallState.active:
        return LvsColors.teal;
      case CallState.reconnecting:
        return LvsColors.amber;
      case CallState.ended:
      case CallState.rejected:
      case CallState.failed:
        return LvsColors.red;
      default:
        return LvsColors.text3;
    }
  }

  String _getStateText(CallState state) {
    switch (state) {
      case CallState.connecting:
        return 'CONECTANDO...';
      case CallState.ringing:
        return 'LLAMANDO...';
      case CallState.connecting:
        return 'CONECTANDO...';
      case CallState.active:
        return 'EN LLAMADA';
      case CallState.reconnecting:
        return 'RECONECTANDO...';
      case CallState.ended:
        return 'LLAMADA FINALIZADA';
      case CallState.rejected:
        return 'RECHAZADA';
      case CallState.failed:
        return 'ERROR';
      default:
        return 'ESPERANDO';
    }
  }

  String _getStateSubtext(CallState state) {
    switch (state) {
      case CallState.connecting:
        return 'Estableciendo conexión...';
      case CallState.ringing:
        return 'Esperando respuesta...';
      case CallState.active:
        return 'Conectado';
      case CallState.reconnecting:
        return 'Reconectando...';
      default:
        return '';
    }
  }

  Widget _defaultAvatar() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [LvsColors.pink, LvsColors.violet],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: 60,
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required double size,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.4),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}