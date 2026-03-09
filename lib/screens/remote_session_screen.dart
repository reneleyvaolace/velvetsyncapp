// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/screens/remote_session_screen.dart
// Interfaz para Invitados: Control Remoto vía Supabase
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../services/catalog_service.dart';
import '../models/toy_model.dart';
import '../theme.dart';

class RemoteSessionScreen extends ConsumerStatefulWidget {
  const RemoteSessionScreen({super.key});

  @override
  ConsumerState<RemoteSessionScreen> createState() => _RemoteSessionScreenState();
}

class _RemoteSessionScreenState extends ConsumerState<RemoteSessionScreen> {
  final TextEditingController _tokenController = TextEditingController();
  bool _isConnected = false;
  bool _isLoading = false;
  
  Map<String, dynamic>? _sessionData;
  ToyModel? _toyModel;
  
  double _valCh1 = 0;
  double _valCh2 = 0;
  
  Timer? _updateTimer;

  @override
  void dispose() {
    _tokenController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _connect() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    setState(() => _isLoading = true);

    final supabase = ref.read(supabaseServiceProvider);
    final session = await supabase.fetchSessionByToken(token);

    if (session == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token inválido o sesión expirada.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    final modelName = session['model_name'] ?? '';
    final catalog = ref.read(catalogProvider.notifier);
    final toy = catalog.findModelByName(modelName);

    setState(() {
      _sessionData = session;
      _toyModel = toy;
      _isConnected = true;
      _isLoading = false;
      _valCh1 = (session['intensity_ch1'] ?? 0).toDouble();
      _valCh2 = (session['intensity_ch2'] ?? 0).toDouble();
    });
  }

  Future<void> _updateIntensity(int channel, double value) async {
    if (_sessionData == null) return;
    
    final supabase = ref.read(supabaseServiceProvider);
    final id = _sessionData!['id']; // ID de la sesión (no el token)
    
    final key = channel == 1 ? 'intensity_ch1' : 'intensity_ch2';
    
    try {
      // Actualizar en el servidor
      await supabase.client
          .from('shared_sessions') // Asumimos que la tabla base es shared_sessions
          .update({key: value.toInt()})
          .eq('id', id);
    } catch (e) {
      debugPrint('❌ Error actualizando intensidad: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LvsColors.bg,
      appBar: AppBar(
        title: const Text('SESIÓN REMOTA'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (!_isConnected) _buildLoginView() else _buildControlView(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Icon(Icons.vibration, size: 80, color: LvsColors.violet.withOpacity(0.5)),
        const SizedBox(height: 20),
        const Text(
          'ACCESO INVITADO',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        const SizedBox(height: 10),
        const Text(
          'Ingresa el código compartido por tu pareja para tomar el control.',
          textAlign: TextAlign.center,
          style: TextStyle(color: LvsColors.text3, fontSize: 14),
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _tokenController,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'CÓDIGO DE ACCESO',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
            filled: true,
            fillColor: LvsColors.bgCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.key, color: LvsColors.violet),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _connect,
            style: ElevatedButton.styleFrom(
              backgroundColor: LvsColors.violet,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 8,
              shadowColor: LvsColors.violet.withOpacity(0.5),
            ),
            child: _isLoading 
              ? const CircularProgressIndicator(color: Colors.white) 
              : const Text('CONECTAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildControlView() {
    final anatomy = _toyModel?.targetAnatomy ?? 'Placer';
    final label = 'Estimulación $anatomy';
    final bool isDual = _toyModel?.hasDualChannel ?? false;

    return Expanded(
      child: Column(
        children: [
          _buildSessionHeader(),
          const SizedBox(height: 40),
          
          // Slider Canal 1 (0xD)
          _buildSlider(
            label: label,
            value: _valCh1,
            color: LvsColors.pink,
            onChanged: (v) {
              setState(() => _valCh1 = v);
            },
            onChangeEnd: (v) => _updateIntensity(1, v),
          ),

          if (isDual) ...[
            const SizedBox(height: 30),
            // Slider Canal 2 (0xA)
            _buildSlider(
              label: 'Vibración Secundaria',
              value: _valCh2,
              color: LvsColors.violet,
              onChanged: (v) {
                setState(() => _valCh2 = v);
              },
              onChangeEnd: (v) => _updateIntensity(2, v),
            ),
          ],
          
          const Spacer(),
          TextButton.icon(
            onPressed: () => setState(() => _isConnected = false),
            icon: const Icon(Icons.exit_to_app, color: LvsColors.red),
            label: const Text('SALIR DE LA SESIÓN', style: TextStyle(color: LvsColors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LvsColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: LvsColors.violet.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.cloud_done, color: LvsColors.teal, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (_toyModel?.name ?? 'Dispositivo Remoto').toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Conexión Segura Activa',
                  style: TextStyle(color: LvsColors.teal, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(), style: const TextStyle(color: LvsColors.text3, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              Text('${value.toInt()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.1),
            thumbColor: Colors.white,
            overlayColor: color.withOpacity(0.2),
            trackHeight: 12,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14, elevation: 6),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 255, // Basado en el requerimiento de canales 0xD y 0xA (0-255)
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}
