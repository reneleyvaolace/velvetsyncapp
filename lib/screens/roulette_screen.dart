// ═══════════════════════════════════════════════════════════════
// LVS Control · lib/screens/roulette_screen.dart
// Eventos aleatorios de alta intensidad (Ruleta Rusa)
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ble/ble_service.dart';
import '../ble/lvs_commands.dart';
import '../theme.dart';

class RouletteScreen extends ConsumerStatefulWidget {
  const RouletteScreen({super.key});

  @override
  ConsumerState<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends ConsumerState<RouletteScreen> with TickerProviderStateMixin {
  bool _isActive = false;
  bool _isExploded = false;
  int _secondsLeft = 0;
  Timer? _timer;
  final math.Random _random = math.Random();
  
  late AnimationController _pulseController;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _spinController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _spinController.dispose();
    _stopHardware();
    super.dispose();
  }

  void _startRoulette() {
    setState(() {
      _isActive = true;
      _isExploded = false;
      // Tiempo aleatorio entre 10 y 45 segundos
      _secondsLeft = _random.nextInt(35) + 10;
    });

    _spinController.repeat();
    HapticFeedback.heavyImpact();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
        HapticFeedback.selectionClick();
      } else {
        timer.cancel();
        _explode();
      }
    });
  }

  void _explode() async {
    setState(() {
      _isExploded = true;
      _spinController.stop();
    });

    final ble = ref.read(bleProvider);
    if (ble.isConnected) {
      // EVENTO DE CLÍMAX: Máxima intensidad en ambos canales
      ble.writeCommand(LvsCommands.preciseChannel1(255), label: 'ROULETTE_BOOM_CH1');
      await Future.delayed(const Duration(milliseconds: 100));
      ble.writeCommand(LvsCommands.preciseChannel2(255), label: 'ROULETTE_BOOM_CH2');

      // Mantener por 5 segundos de "caos"
      await Future.delayed(const Duration(seconds: 5));
      _stopHardware();
    }

    setState(() {
      _isActive = false;
      _isExploded = false;
    });
  }

  void _stopHardware() {
    final ble = ref.read(bleProvider);
    ble.writeCommand(LvsCommands.preciseChannel1(0), label: 'ROULETTE_STOP_CH1');
    ble.writeCommand(LvsCommands.preciseChannel2(0), label: 'ROULETTE_STOP_CH2');
    _timer?.cancel();
    _spinController.stop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('RULETA RUSA'),
          backgroundColor: Colors.transparent,
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _isExploded ? Colors.red.shade900 : LvsColors.bg,
                LvsColors.bg.withOpacity(0.8),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              
              if (!_isActive)
                ElevatedButton(
                  onPressed: _startRoulette,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LvsColors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                  ),
                  child: const Text('INICIAR RITUAL', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                )
              else if (_isExploded)
                const Text('¡SOBRECARGA DETECTADA!', 
                  style: TextStyle(color: LvsColors.red, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 2))
              else
                const Text('NO TE MUEVAS...', 
                  style: TextStyle(color: LvsColors.amber, fontWeight: FontWeight.bold, letterSpacing: 4)),
              
              const SizedBox(height: 100),
              
              const CardGlass(
                child: Text(
                  'La ruleta detonará una ráfaga de intensidad máxima (100%) en un momento impredecible. ¿Podrás resistirlo?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: LvsColors.text3, fontSize: 11, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterVisual() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _spinController]),
      builder: (context, child) {
        final scale = 1.0 + (_isActive ? _pulseController.value * 0.1 : 0);
        final rotation = _spinController.value * 2 * math.pi;
        final color = _isExploded ? LvsColors.red : (_isActive ? LvsColors.amber : LvsColors.text3);
        
        return Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: rotation,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.5), width: 2),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(_isExploded ? 0.8 : 0.2), blurRadius: _isExploded ? 50 : 20, spreadRadius: 5),
                ],
              ),
              child: Center(
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.5),
                  ),
                  child: Center(
                    child: _isExploded 
                      ? const Icon(Icons.flash_on, color: LvsColors.red, size: 80)
                      : Text(
                          _isActive ? '$_secondsLeft' : '?',
                          style: TextStyle(color: color, fontSize: 60, fontWeight: FontWeight.w900),
                        ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
