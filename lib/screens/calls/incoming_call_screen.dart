// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/screens/calls/incoming_call_screen.dart
// Pantalla de llamada entrante
// ════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/calls/call_models.dart';
import 'package:velvet_sync/services/calls/call_controller.dart';
import 'package:velvet_sync/theme.dart';
import 'package:velvet_sync/utils/logger.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  final CallModel call;
  const IncomingCallScreen({super.key, required this.call});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-rechazar después de 60 segundos
    _timeoutTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) _rejectCall();
    });

    // Mantener pantalla encendida
    _keepScreenOn();
  }

  Future<void> _keepScreenOn() async {
    // Wakelock se maneja en main.dart
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _acceptCall() async {
    _timeoutTimer?.cancel();
    try {
      await ref.read(callControllerProvider).acceptCall(widget.call);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      lvsError('Error aceptando llamada: $e', tag: 'INCOMING_CALL');
    }
  }

  void _rejectCall() async {
    _timeoutTimer?.cancel();
    try {
      await ref.read(callControllerProvider).rejectCall(widget.call);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      lvsError('Error rechazando llamada: $e', tag: 'INCOMING_CALL');
    }
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    
    return Scaffold(
      backgroundColor: LvsColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Tipo de llamada
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: LvsColors.pink.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      call.type == CallType.video 
                          ? Icons.videocam_rounded 
                          : Icons.call_rounded,
                      color: LvsColors.pink,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      call.type == CallType.video 
                          ? 'LLAMADA DE VIDEO' 
                          : 'LLAMADA DE VOZ',
                      style: const TextStyle(
                        color: LvsColors.pink,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Avatar del caller
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
                      color: LvsColors.pink.withValues(alpha: 0.5),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: LvsColors.pink.withValues(alpha: 0.3),
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

              // Nombre del caller
              Text(
                call.callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'Llamada entrante',
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
                  // Rechazar
                  _buildActionButton(
                    icon: Icons.call_end_rounded,
                    label: 'Rechazar',
                    color: LvsColors.red,
                    onTap: _rejectCall,
                    size: 72,
                  ),

                  const SizedBox(width: 40),

                  // Aceptar
                  _buildActionButton(
                    icon: call.type == CallType.video 
                        ? Icons.videocam_rounded 
                        : Icons.call_rounded,
                    label: 'Aceptar',
                    color: LvsColors.teal,
                    onTap: _acceptCall,
                    size: 72,
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Timer visual
              _IncomingCallTimer(),
            ],
          ),
        ),
      ),
    );
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

/// Timer visual para llamada entrante
class _IncomingCallTimer extends ConsumerStatefulWidget {
  @override
  ConsumerState<_IncomingCallTimer> createState() => _IncomingCallTimerState();
}

class _IncomingCallTimerState extends ConsumerState<_IncomingCallTimer> {
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mins = _seconds ~/ 60;
    final secs = _seconds % 60;
    return Text(
      '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
      style: TextStyle(
        color: LvsColors.text3,
        fontSize: 16,
        fontFamily: 'monospace',
        fontWeight: FontWeight.w500,
      ),
    );
  }
}