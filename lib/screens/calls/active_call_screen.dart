// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/screens/calls/active_call_screen.dart
// Pantalla de llamada activa (controles durante la llamada)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/calls/call_models.dart';
import 'package:velvet_sync/services/calls/call_controller.dart';
import 'package:velvet_sync/theme.dart';
import 'package:velvet_sync/utils/logger.dart';

class ActiveCallScreen extends ConsumerWidget {
  final CallModel call;
  const ActiveCallScreen({super.key, required this.call});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callStateProvider);
    final currentCall = callState.value ?? call;
    final controller = ref.read(callControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video remoto (fullscreen)
          Positioned.fill(
            child: controller.getRemoteView() ??
                Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.videocam_off_rounded,
                          color: Colors.white54,
                          size: 80,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Esperando video...',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
          ),
        
        // Video local (picture-in-picture)
        Positioned(
          top: 60,
          right: 16,
          child: GestureDetector(
            onTap: () => controller.switchCamera(),
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: controller.getLocalView() ??
                    Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: Icon(Icons.person, color: Colors.white54, size: 40),
                      ),
                    ),
              ),
            ),
          ),
        
        // Controles inferiores
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Timer y estado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final callState = ref.watch(callStateProvider);
                        final secs = callState.value?.durationSeconds ?? 0;
                        final mins = secs ~/ 60;
                        final sec = secs % 60;
                        return Text(
                          '${mins.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                    Row(
                      children: [
                        _ConnectionQualityIndicator(),
                        const SizedBox(width: 12),
                        _BatteryIndicator(),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Controles principales
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallControlButton(
                      icon: ref.watch(callStateProvider).value?.isMuted == true
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      label: 'Mute',
                      color: ref.watch(callStateProvider).value?.isMuted == true
                          ? Colors.red
                          : Colors.white,
                      onTap: () => ref.read(callControllerProvider).toggleMute(),
                    ),
                    _CallControlButton(
                      icon: ref.watch(callStateProvider).value?.isVideoMuted == true
                          ? Icons.videocam_off_rounded
                          : Icons.videocam_rounded,
                      label: 'Video',
                      color: ref.watch(callStateProvider).value?.isVideoMuted == true
                          ? Colors.red
                          : Colors.white,
                      onTap: () => ref.read(callControllerProvider).toggleVideoMute(),
                    ),
                    _CallControlButton(
                      icon: ref.watch(callStateProvider).value?.isSpeakerOn == true
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      label: 'Audio',
                      color: ref.watch(callStateProvider).value?.isSpeakerOn == true
                          ? Colors.cyan
                          : Colors.white,
                      onTap: () => ref.read(callControllerProvider).toggleSpeaker(),
                    ),
                    _CallControlButton(
                      icon: Icons.flip_camera_android_rounded,
                      label: 'Cámara',
                      color: Colors.purple,
                      onTap: () => ref.read(callControllerProvider).switchCamera(),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Botón colgar
                GestureDetector(
                  onTap: () => ref.read(callControllerProvider).endCall(),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Colors.red, Colors.redAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.call_end_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _ConnectionQualityIndicator extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Implementar calidad de red real
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi, color: Colors.green, size: 14),
          const SizedBox(width: 4),
          const Text(
            'Excelente',
            style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _BatteryIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.battery_unknown, color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          const Text(
            '—%',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}