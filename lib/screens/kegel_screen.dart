import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/theme.dart';

enum KegelPhase { ready, contract, relax, finished }

class KegelLevel {
  final String name;
  final int contractSeconds;
  final int relaxSeconds;
  final int repetitions;
  final Color color;

  const KegelLevel({
    required this.name,
    required this.contractSeconds,
    required this.relaxSeconds,
    required this.repetitions,
    required this.color,
  });
}

const List<KegelLevel> kegelLevels = [
  KegelLevel(name: 'PRINCIPIANTE', contractSeconds: 3, relaxSeconds: 3, repetitions: 10, color: LvsColors.teal),
  KegelLevel(name: 'INTERMEDIO', contractSeconds: 5, relaxSeconds: 5, repetitions: 15, color: LvsColors.amber),
  KegelLevel(name: 'AVANZADO', contractSeconds: 10, relaxSeconds: 5, repetitions: 20, color: LvsColors.pink),
];

class KegelScreen extends ConsumerStatefulWidget {
  const KegelScreen({super.key});

  @override
  ConsumerState<KegelScreen> createState() => _KegelScreenState();
}

class _KegelScreenState extends ConsumerState<KegelScreen> with SingleTickerProviderStateMixin {
  Timer? _timer;

  KegelLevel? _selectedLevel;
  KegelPhase _currentPhase = KegelPhase.ready;

  int _currentRep = 0;
  int _secondsRemaining = 0;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    // Inicializar con el primer nivel si existe
    if (kegelLevels.isNotEmpty) {
      _selectedLevel = kegelLevels.first;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopDevice();
    super.dispose();
  }

  void _startExercise() {
    if (_selectedLevel == null) return;
    setState(() {
      _currentPhase = KegelPhase.contract;
      _currentRep = 1;
      _secondsRemaining = _selectedLevel!.contractSeconds;
      _isRunning = true;
    });
    _runPhase();
  }

  void _runPhase() {
    _timer?.cancel();
    
    // Sincronización con el dispositivo
    if (_currentPhase == KegelPhase.contract) {
      _vibrateDevice();
    } else {
      _stopDevice();
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
        } else {
          _nextPhase();
        }
      });
    });
  }

  void _nextPhase() {
    if (_selectedLevel == null) return;
    if (_currentPhase == KegelPhase.contract) {
      _currentPhase = KegelPhase.relax;
      _secondsRemaining = _selectedLevel!.relaxSeconds;
    } else if (_currentPhase == KegelPhase.relax) {
      if (_currentRep < _selectedLevel!.repetitions) {
        _currentRep++;
        _currentPhase = KegelPhase.contract;
        _secondsRemaining = _selectedLevel!.contractSeconds;
      } else {
        _finishExercise();
        return;
      }
    }
    _runPhase();
  }

  void _finishExercise() {
    _timer?.cancel();
    _stopDevice();
    setState(() {
      _currentPhase = KegelPhase.finished;
      _isRunning = false;
    });
  }

  void _vibrateDevice() {
    final ble = ref.read(bleProvider);
    if (ble.isConnected) {
      ble.setProportionalChannel1(50); // Vibración moderada para guiar
    }
  }

  void _stopDevice() {
    final ble = ref.read(bleProvider);
    if (ble.isConnected) {
      ble.setProportionalChannel1(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LvsColors.bg,
      appBar: AppBar(
        title: Text('ENTRENAMIENTO KEGEL', style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 4)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildLevelSelector(),
              const Spacer(),
              _buildMainDisplay(),
              const Spacer(),
              _buildControls(),
              const SizedBox(height: 120), // Support for floating dock
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: LvsColors.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: kegelLevels.map((level) {
          final isSelected = _selectedLevel == level;
          return Expanded(
            child: GestureDetector(
              onTap: _isRunning ? null : () => setState(() => _selectedLevel = level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? level.color.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? level.color : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Text(
                  level.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : LvsColors.text3,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMainDisplay() {
    var text = 'LISTO';
    var color = LvsColors.teal;
    var progress = 1.0;

    if (_isRunning && _selectedLevel != null) {
      if (_currentPhase == KegelPhase.contract) {
        text = 'CONTRAE';
        color = LvsColors.pink;
        progress = _secondsRemaining / _selectedLevel!.contractSeconds;
      } else {
        text = 'RELAJA';
        color = LvsColors.teal;
        progress = _secondsRemaining / _selectedLevel!.relaxSeconds;
      }
    } else if (_currentPhase == KegelPhase.finished) {
      text = '¡HECHO!';
      color = LvsColors.teal;
      progress = 0.0;
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Brillo de fondo
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 240, height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.15), blurRadius: 60, spreadRadius: 10),
                ],
              ),
            ),
            // Anillo de progreso
            SizedBox(
              width: 220, height: 220,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                color: color,
                backgroundColor: Colors.white.withOpacity(0.05),
                strokeCap: StrokeCap.round,
              ),
            ),
            // Círculo interno glass
            CardGlass(
              width: 180, height: 180,
              borderRadius: 180,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isRunning && _selectedLevel != null)
                      Text(
                        'ROUND $_currentRep',
                        style: GoogleFonts.plusJakartaSans(color: LvsColors.text3, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      _isRunning ? '0:${_secondsRemaining.toString().padLeft(2,'0')}' : text,
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: _isRunning ? 54 : 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    if (_isRunning)
                      Text(
                        text,
                        style: GoogleFonts.plusJakartaSans(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        if (!_isRunning && _currentPhase == KegelPhase.ready)
          const Text(
            'El entrenamiento Kegel ayuda a fortalecer\nlos músculos del suelo pélvico.',
            textAlign: TextAlign.center,
            style: TextStyle(color: LvsColors.text3, fontSize: 13, height: 1.5),
          ),
      ],
    );
  }

  Widget _buildControls() {
    if (_isRunning) {
      return SizedBox(
        width: 200,
        height: 60,
        child: ElevatedButton(
          onPressed: () {
            _timer?.cancel();
            _stopDevice();
            setState(() {
              _isRunning = false;
              _currentPhase = KegelPhase.ready;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.05),
            foregroundColor: LvsColors.red,
            side: const BorderSide(color: LvsColors.red, width: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text('DETENER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        ),
      );
    }

    return SizedBox(
      width: 260,
      height: 64,
      child: ElevatedButton(
        onPressed: _startExercise,
        style: ElevatedButton.styleFrom(
          backgroundColor: LvsColors.teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          elevation: 20,
          shadowColor: LvsColors.teal.withOpacity(0.4),
        ),
        child: const Text(
          'INICIAR RUTINA',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
      ),
    );
  }
}
