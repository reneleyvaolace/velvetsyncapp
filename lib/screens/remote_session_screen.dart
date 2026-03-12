// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/screens/remote_session_screen.dart
// Interfaz para Invitados: Control Remoto vía Supabase
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../services/catalog_service.dart';
import '../ble/ble_service.dart';
import '../models/toy_model.dart';
import '../theme.dart';
import '../utils/logger.dart';

class RemoteSessionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialSessionData;
  const RemoteSessionScreen({super.key, this.initialSessionData});

  @override
  ConsumerState<RemoteSessionScreen> createState() => _RemoteSessionScreenState();
}

class _RemoteSessionScreenState extends ConsumerState<RemoteSessionScreen> {
  final TextEditingController _tokenController = TextEditingController();
  bool _isConnected = false;
  bool _isLoading = false;
  bool _partnerActive = false;
  Timer? _partnerTimer;
  
  Map<String, dynamic>? _sessionData;
  ToyModel? _toyModel;
  
  double _valCh1 = 0;
  double _valCh2 = 0;

  // Estados de navegación interna
  bool _showGuestLogin = false;
  String? _hostError;
  
  @override
  void initState() {
    super.initState();
    if (widget.initialSessionData != null) {
      _sessionData = widget.initialSessionData;
      _isConnected = true;
      _loadToyModel();
      _startListening();
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _partnerTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadToyModel() async {
    if (_sessionData == null) return;
    
    final modelName = _sessionData!['model_name'] ?? '';
    final deviceId = _sessionData!['device_id'] ?? '';
    
    final catalog = ref.read(catalogProvider.notifier);
    
    // 1. Intentar por nombre
    _toyModel = catalog.findModelByName(modelName);
    
    // 2. Si falló, intentar por ID (robusto para dispositivos genéricos)
    if (_toyModel == null && deviceId.isNotEmpty) {
      lvsLog('Buscando modelo por ID: $deviceId', tag: 'REMOTE');
      _toyModel = await ref.read(supabaseServiceProvider).fetchDeviceById(deviceId);
    }
    
    // 3. FALLBACK: Si sigue siendo nulo, crear perfil genérico para no romper la UI
    if (_toyModel == null && deviceId.isNotEmpty) {
      _toyModel = ToyModel(
        id: deviceId,
        name: 'LVS Genérico $deviceId',
        usageType: 'Universal',
        targetAnatomy: 'Universal',
        stimulationType: 'Vibración',
        motorLogic: 'Single Channel',
        imageUrl: '',
        qrCodeUrl: '',
        supportedFuncs: 'speed,vibration,pattern',
        isPrecise: false,
        broadcastPrefix: '77 62 4d 53 45',
      );
    }
    
    if (mounted) {
      setState(() {
        _valCh1 = (_sessionData!['intensity_ch1'] ?? 0).toDouble();
        _valCh2 = (_sessionData!['intensity_ch2'] ?? 0).toDouble();
      });
    }
  }

  void _startListening() {
    if (_sessionData == null) return;
    final sessionId = _sessionData!['id'].toString();
    final supabase = ref.read(supabaseServiceProvider);
    
    supabase.joinControlRoom(sessionId, (payload, isSelf) {
      if (!mounted || isSelf) return;
      
      final ble = ref.read(bleProvider);

      // Feedback visual de actividad del socio
      setState(() => _partnerActive = true);
      _partnerTimer?.cancel();
      _partnerTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _partnerActive = false);
      });
      
      setState(() {
        if (payload.containsKey('intensity_ch1')) {
          final val = (payload['intensity_ch1'] as num).toDouble();
          _valCh1 = val;
          if (ble.isConnected) {
            // Aplicar al juguete local (Bidireccional)
            ble.sendMultimediaSync(val.toInt(), _valCh2.toInt());
          }
        }
        if (payload.containsKey('intensity_ch2')) {
          final val = (payload['intensity_ch2'] as num).toDouble();
          _valCh2 = val;
          if (ble.isConnected) {
            // Aplicar al juguete local (Bidireccional)
            ble.sendMultimediaSync(_valCh1.toInt(), val.toInt());
          }
        }
      });
    });
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

    setState(() {
      _sessionData = session;
      _isConnected = true;
      _isLoading = false;
    });
    
    _loadToyModel();
    _startListening();
  }

  Future<void> _updateIntensity(int channel, double value) async {
    if (_sessionData == null) return;
    
    final supabase = ref.read(supabaseServiceProvider);
    final sessionId = _sessionData!['id'].toString();
    final key = channel == 1 ? 'intensity_ch1' : 'intensity_ch2';
    
    await supabase.sendBroadcastCommand(sessionId, key, value.toInt());
    
    // Si somos el HOST, también debemos actualizar el juguete localmente
    final ble = ref.read(bleProvider);
    if (ble.isConnected) {
       if (channel == 1) {
         ble.setProportionalChannel1(value.toInt());
       } else {
         ble.setProportionalChannel2(value.toInt());
       }
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
        actions: [
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.share, color: LvsColors.teal),
              onPressed: _showTokenDialog,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Column(
              children: [
                if (!_isConnected) 
                   (_showGuestLogin ? _buildGuestLoginView() : _buildSelectionView())
                else 
                   _buildControlView(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionView() {
    final ble = ref.watch(bleProvider);
    
    return Column(
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.hub_outlined, size: 80, color: LvsColors.pink),
        const SizedBox(height: 24),
        const Text(
          'SESIÓN REMOTA',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        const SizedBox(height: 8),
        const Text(
          'Elige cómo quieres conectar hoy',
          style: TextStyle(color: LvsColors.text3, fontSize: 14),
        ),
        const SizedBox(height: 48),

        // OPCIÓN 1: SER ANFITRIÓN
        GestureDetector(
          onTap: () => _startHostSession(ble),
          child: CardGlass(
            borderColor: LvsColors.teal.withOpacity(0.3),
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: LvsColors.teal.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.share_rounded, color: LvsColors.teal, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SER EL ANFITRIÓN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(
                        ble.isConnected 
                          ? 'Genera un código para que tu pareja controle tu ${ble.activeToy?.name ?? "dispositivo"}.'
                          : 'Conecta un dispositivo primero para ser controlado.',
                        style: const TextStyle(color: LvsColors.text3, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_hostError != null)
           Padding(
             padding: const EdgeInsets.only(top: 8),
             child: Text(_hostError!, style: const TextStyle(color: LvsColors.red, fontSize: 10, fontWeight: FontWeight.bold)),
           ),

        const SizedBox(height: 20),

        // OPCIÓN 2: ACCESO INVITADO
        GestureDetector(
          onTap: () => setState(() => _showGuestLogin = true),
          child: CardGlass(
            borderColor: LvsColors.pink.withOpacity(0.3),
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: LvsColors.pink.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.vpn_key_rounded, color: LvsColors.pink, size: 28),
                ),
                const SizedBox(width: 20),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ACCESO INVITADO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text('Usa el código que te compartieron para controlar el dispositivo de tu pareja.',
                        style: TextStyle(color: LvsColors.text3, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _startHostSession(BleService ble) async {
    if (!ble.isConnected) {
      setState(() => _hostError = '❌ ERROR: Debes tener un dispositivo vinculado para ser anfitrión.');
      Timer(const Duration(seconds: 4), () { if(mounted) setState(() => _hostError = null); });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final session = await supabase.createSharedSession(ble.activeToy?.id ?? ble.toyProfile?.identifier ?? 'generic_lvs');
      
      if (session != null) {
        setState(() {
          _sessionData = session;
          _isConnected = true;
          _isLoading = false;
        });
        _loadToyModel();
        _startListening();
        
        // Mostrar el diálogo del token automáticamente al crear
        if (mounted) _showTokenDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hostError = '❌ Error de red: $e';
        });
      }
    }
  }

  Widget _buildGuestLoginView() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
              onPressed: () => setState(() => _showGuestLogin = false),
            ),
            const Text('VOLVER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 30),
        Image.asset('assets/icons/icon_remote_session.png', width: 80, height: 80),
        const SizedBox(height: 24),
        const Text(
          'CONFIGURAR ACCESO',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        const Text(
          'Ingresa el token de 6 dígitos generado por tu pareja.',
          textAlign: TextAlign.center,
          style: TextStyle(color: LvsColors.text3, fontSize: 13),
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _tokenController,
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 10),
          textAlign: TextAlign.center,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            counterText: "",
            hintText: '------',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.1)),
            filled: true,
            fillColor: LvsColors.bgCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: LvsColors.pink.withOpacity(0.5))),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _connect,
            style: ElevatedButton.styleFrom(
              backgroundColor: LvsColors.pink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isLoading 
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('CONECTAR AHORA', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  void _showTokenDialog() {
    final token = _sessionData?['access_token'] ?? '---';
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85), // Fondo mucho más oscuro
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A), // Fondo de tarjeta más sólido
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: LvsColors.teal.withOpacity(0.2), width: 1),
        ),
        title: const Text(
          'COMPARTIR ACCESO',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Comparte este código con tu pareja para que pueda controlar tu dispositivo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: LvsColors.text3, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: LvsColors.teal.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(color: LvsColors.teal.withOpacity(0.1), blurRadius: 20, spreadRadius: 2),
                ],
              ),
              child: Text(
                token,
                style: const TextStyle(
                  color: LvsColors.teal,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: token));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Código copiado al portapapeles'),
                    backgroundColor: LvsColors.teal,
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [LvsColors.pink, Color(0xFFFF4081)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: LvsColors.pink.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'COPIAR CÓDIGO',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildControlView() {
    final anatomy = _toyModel?.targetAnatomy ?? 'Placer';
    final label = 'Estimulación $anatomy';
    final bool isDual = _toyModel?.hasDualChannel ?? false;

    return Column(
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
          
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TextButton.icon(
              onPressed: () {
                 ref.read(supabaseServiceProvider).leaveControlRoom();
                 setState(() => _isConnected = false);
              },
              icon: const Icon(Icons.exit_to_app, color: LvsColors.red),
              label: const Text('SALIR DE LA SESIÓN', style: TextStyle(color: LvsColors.red, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
  }

  Widget _buildSessionHeader() {
    final deviceName = _toyModel?.name ?? 'Dispositivo Remoto';
    final isHost = ref.read(bleProvider).isConnected;

    return Column(
      children: [
        Text(
          isHost ? 'ESTÁS COMPARTIENDO EL CONTROL' : 'CONECTADO AL DISPOSITIVO DE TU PAREJA',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.5),
        ),
        const SizedBox(height: 16),
        
        // Pill Status
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: LvsColors.teal.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   if (_toyModel != null) ...[
                    Image.asset(_toyModel!.iconAsset, width: 22, height: 22),
                    const SizedBox(width: 10),
                  ],
                  Container(
                    width: 20, height: 20,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [LvsColors.teal, Color(0xFF00ACC1)],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.bluetooth, color: Colors.white, size: 14),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      deviceName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),
             // Indicador de Socio
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _partnerActive ? LvsColors.pink.withOpacity(0.1) : Colors.black45,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _partnerActive ? LvsColors.pink : Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/icons/icon_remote_partner.png', width: 32, height: 32,
                    errorBuilder: (_, __, ___) => const Icon(Icons.person_outline, color: LvsColors.pink, size: 24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _partnerActive ? 'SOCIO ACTIVO' : 'SOCIO EN ESPERA',
                    style: TextStyle(
                      color: _partnerActive ? LvsColors.pink : Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        if (isHost) ...[
          const SizedBox(height: 24),
          const SectionLabel('CÓDIGO DE ACCESO'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showTokenDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: LvsColors.bgCardH,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LvsColors.pink.withOpacity(0.3)),
              ),
              child: Text(
                _sessionData?['access_token'] ?? '---',
                style: const TextStyle(color: LvsColors.pink, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 4),
              ),
            ),
          ),
        ],
      ],
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
              Text(label.toUpperCase(), style: const TextStyle(color: LvsColors.text3, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              Text('${((value / 255) * 100).round()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.1),
            thumbColor: Colors.white,
            overlayColor: color.withOpacity(0.2),
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 255,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}
