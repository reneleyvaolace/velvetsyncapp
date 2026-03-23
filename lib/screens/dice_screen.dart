// ═══════════════════════════════════════════════════════════════
// LVS Control · lib/screens/dice_screen.dart
// Selector aleatorio de combinaciones (Knight No. 3)
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ble/ble_service.dart';
import '../theme.dart';

class DiceScreen extends ConsumerStatefulWidget {
  const DiceScreen({super.key});

  @override
  ConsumerState<DiceScreen> createState() => _DiceScreenState();
}

class _DiceScreenState extends ConsumerState<DiceScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  int _dice1Value = 1;
  int _dice2Value = 1;
  bool _isRolling = false;
  bool _isActive  = false;  // ← true cuando el hardware está activado
  Timer? _autoStopTimer;
  int _secondsLeft = 0;
  static const _defaultDuration = 15; // Segundos que dura la sensación

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _rollDice() async {
    if (_isRolling) return;
    setState(() => _isRolling = true);
    HapticFeedback.lightImpact();

    // Simular el giro por 1.5 segundos
    int ticks = 0;
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _dice1Value = math.Random().nextInt(9) + 1;
        _dice2Value = math.Random().nextInt(9) + 1;
      });
      _animationController.forward(from: 0);
      HapticFeedback.selectionClick();
      
      ticks++;
      if (ticks > 15) {
        timer.cancel();
        _stopRolling();
      }
    });
  }

  void _stopRolling() {
    setState(() => _isRolling = false);
    HapticFeedback.heavyImpact();

    final ble = ref.read(bleProvider);
    if (!ble.isConnected) return;

    // Aplicar combinación rMesh/Fastcon
    ble.setPatternChannel1(_dice1Value);
    Future.delayed(const Duration(milliseconds: 150), () {
      ble.setPatternChannel2(_dice2Value);
    });

    // ── AUTO-STOP programado ──────────────────────────────────
    _autoStopTimer?.cancel();
    setState(() {
      _isActive    = true;
      _secondsLeft = _defaultDuration;
    });

    // Countdown cada segundo
    _autoStopTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _hardwareStop();
      }
    });
  }

  void _hardwareStop() {
    _autoStopTimer?.cancel();
    final ble = ref.read(bleProvider);
    // emergencyStop bypassa el mutex para garantizar la parada
    ble.emergencyStop();
    if (mounted) setState(() { _isActive = false; _secondsLeft = 0; });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('DADOS HÁPTICOS'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                LvsColors.bg,
                LvsColors.bg.withOpacity(0.8),
                LvsColors.violet.withOpacity(0.1),
              ],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SectionLabel('MODO COMBINACIÓN'),
              const SizedBox(height: 10),
              const Text('LANZA LOS DADOS PARA NUEVAS SENSACIONES', 
                style: TextStyle(color: LvsColors.text3, fontSize: 10, letterSpacing: 2)),
              
              const SizedBox(height: 50),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDice(_dice1Value, LvsColors.pink, 'EMPUJE'),
                  _buildDice(_dice2Value, LvsColors.teal, 'VIBRACIÓN'),
                ],
              ),
              
              const SizedBox(height: 40),

              // ── Botón de stop / contador ──────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isActive
                  ? Column(
                      key: const ValueKey('active'),
                      children: [
                        Text(
                          'ACTIVO · $_secondsLeft s restantes',
                          style: const TextStyle(color: LvsColors.teal, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _hardwareStop,
                            icon: const Icon(Icons.power_settings_new_rounded),
                            label: const Text('DETENER AHORA'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: LvsColors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                      ],
                    )
                  : ElevatedButton(
                      key: const ValueKey('idle'),
                      onPressed: _rollDice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRolling ? Colors.grey[800] : LvsColors.pink,
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text(_isRolling ? 'GIRANDO...' : 'LANZAR DADOS',
                        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
                    ),
              ),

              CardGlass(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: LvsColors.text3, size: 16),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cada dado aplica un patrón experimental a los motores del Knight No. 3. Los resultados son instantáneos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: LvsColors.text3.withOpacity(0.8), fontSize: 11, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ), // This closes the Scaffold
    ); // This closes the SafeArea
  }

  Widget _buildDice(int value, Color color, String label) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            // Efecto de rotación y salto si está rodando
            final double angle = _isRolling ? math.sin(_animationController.value * math.pi * 2) * 0.2 : 0;
            final double scale = _isRolling ? 1.0 + math.sin(_animationController.value * math.pi) * 0.1 : 1.0;
            
            return Transform.scale(
              scale: scale,
              child: Transform.rotate(
                angle: angle,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: color.withOpacity(0.8), width: 3),
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.35), blurRadius: 25, spreadRadius: 1),
                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(5, 5)),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$value',
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: 54, 
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: color, blurRadius: 15),
                          const Shadow(color: Colors.black, blurRadius: 2, offset: Offset(2, 2)),
                        ]
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(label, style: TextStyle(
          color: color.withOpacity(0.8), 
          fontSize: 10,
          fontWeight: FontWeight.w900, 
          letterSpacing: 1.5
        )),
      ],
    );
  }
}
