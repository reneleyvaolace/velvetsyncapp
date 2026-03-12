// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/screens/home_screen.dart · v2.1.0
// Pantalla Principal: Control Dashboard con Neumorfismo y Glassmorphism
// ═══════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../providers/media_sync_provider.dart';
import '../ble/ble_service.dart';
import '../ble/lvs_commands.dart';
import '../main.dart'; 
import '../theme.dart';
import '../widgets/preregister_widget.dart';
import 'debug_screen.dart';
import 'game_screen.dart';
import 'companion_screen.dart';
import 'dice_screen.dart';
import 'roulette_screen.dart';
import 'reader_screen.dart';
import 'catalog_screen.dart';
import 'remote_session_screen.dart';
import '../services/catalog_service.dart';
import '../services/supabase_service.dart';
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  // ── Shake mode ────────────────────────────────────────────
  bool _shakeMode  = false;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  DateTime _lastShake = DateTime.now();

  // ── Animaciones ──────────────────────────────────────────
  late AnimationController _burstAnim;
  late AnimationController _stopPulseAnim;

  // ── Auto-Connect ─────────────────────────────────────────
  Timer? _autoConnectTimer;
  bool _autoConnectEnabled = true; // El usuario puede desactivarlo

  @override
  void initState() {
    super.initState();
    _burstAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
    _stopPulseAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

    // Esperar 600ms para que SharedPreferences cargue el catálogo
    // y luego arrancar auto-connect si hay pre-registrados
    Future.delayed(const Duration(milliseconds: 600), _tryAutoConnect);
  }

  /// Intenta conectar automáticamente si hay dispositivos pre-registrados
  void _tryAutoConnect() {
    if (!mounted || !_autoConnectEnabled) return;
    final ble = ref.read(bleProvider);
    if (ble.isConnected || ble.isScanning) return;

    final preregistered = ref.read(preregisteredProvider);
    if (preregistered.isEmpty) return;

    final catalog = ref.read(catalogProvider).asData?.value;
    ble.connectToDevice(catalog: catalog);

    // Si no conectó en 25s, reintentar automáticamente cada 8s
    _autoConnectTimer?.cancel();
    _autoConnectTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || !_autoConnectEnabled) {
        _autoConnectTimer?.cancel();
        return;
      }
      final bleNow = ref.read(bleProvider);
      if (bleNow.isConnected) {
        _autoConnectTimer?.cancel();
        return;
      }
      if (!bleNow.isScanning) {
        final cat = ref.read(catalogProvider).asData?.value;
        bleNow.connectToDevice(catalog: cat);
      }
    });
  }

  void _cancelAutoConnect() {
    _autoConnectTimer?.cancel();
    setState(() => _autoConnectEnabled = false);
    final ble = ref.read(bleProvider);
    if (ble.isScanning) ble.disconnect(); // detiene el scan
  }

  @override
  void dispose() {
    _autoConnectTimer?.cancel();
    _accelSub?.cancel();
    _burstAnim.dispose();
    _stopPulseAnim.dispose();
    super.dispose();
  }

  void _toggleShake(BleService ble) {
    setState(() => _shakeMode = !_shakeMode);
    if (_shakeMode) {
      _accelSub = accelerometerEventStream().listen((event) {
        final g = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        if (g > 15) { // Umbral de agitación
          final now = DateTime.now();
          if (now.difference(_lastShake).inMilliseconds > 400) {
            _lastShake = now;
            HapticFeedback.lightImpact();
            // Enviar pulso de alta intensidad aleatorio o fijo
            ble.writeCommand(LvsCommands.cmdHigh, label: 'SHAKE', silent: true);
          }
        }
      });
    } else {
      _accelSub?.cancel();
    }
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // Rendimiento: Solo reconstruir el scaffold si cambia el ESTADO GLOBAL de conexión
    final bleState = ref.watch(bleProvider.select((p) => p.state));
    final ble = ref.read(bleProvider); // Acceso directo para callbacks sin disparar rebuilds

    return Scaffold(
      backgroundColor: LvsColors.bg,
      body: Stack(
        children: [
          // Fondo con gradiente sutil
          Positioned(
            top: -100, right: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LvsColors.pink.withOpacity(0.05),
              ),
            ),
          ),
          
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(ref),
                
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildConnectCard(ble),
                      const SizedBox(height: 20),
                      _buildControlCard(ref),
                      const SizedBox(height: 20),
                      _buildCanvasCard(ble),
                      const SizedBox(height: 20),
                      _buildMediaSyncCard(ble),
                      const SizedBox(height: 20),
                      _buildGameModeCard(context, ble),
                      const SizedBox(height: 20),
                      _buildCompanionCard(context, ble),
                      const SizedBox(height: 20),
                      _buildRemoteSessionCard(context),
                      const SizedBox(height: 20),
                      _buildDiceCard(context, ble),
                      const SizedBox(height: 20),
                      _buildRouletteCard(context, ble),
                      const SizedBox(height: 20),
                      _buildReaderCard(context, ble),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          'LVS CONTROL V1.6.1-DEBUG',
                          style: TextStyle(color: LvsColors.text3.withOpacity(0.3), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildCatalogCard(context),
                      const SizedBox(height: 20),
                      _buildPatternsCard(ble),
                      const SizedBox(height: 20),
                      _buildShakeCard(ble),
                      const SizedBox(height: 20),
                      _buildSettingsCard(ble),
                      const SizedBox(height: 20),
                      _buildDebugButton(context),
                      const SizedBox(height: 20),
                      _buildLogCard(ble),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────
  Widget _buildAppBar(WidgetRef ref) {
    final ble = ref.read(bleProvider);
    final bleState = ref.watch(bleProvider.select((p) => p.state));
    final deviceName = ref.watch(bleProvider.select((p) => p.toyProfile?.name ?? p.connectedDeviceName));

    return SliverAppBar(
      pinned: true,
      floating: true,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          // Logo from Image 2 (Glass Square + Waveform)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(color: LvsColors.pink.withValues(alpha: 0.1), blurRadius: 10),
                BoxShadow(color: LvsColors.violet.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(5, 5)),
              ]
            ),
            child: ShaderMask(
              shaderCallback: (r) => const LinearGradient(colors: [LvsColors.pink, LvsColors.violet]).createShader(r),
              child: const Icon(Icons.show_chart, color: Colors.white, size: 42),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Velvet Sync', style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w400, fontFamily: 'serif', letterSpacing: 0.5, color: LvsColors.text1)),
                if (bleState == BleState.connected)
                  Text(
                    'VINCULADO: $deviceName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1, color: LvsColors.teal)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        _BleStateBox(state: bleState),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.exit_to_app, color: LvsColors.text3, size: 20),
          tooltip: 'Cerrar Aplicación',
          onPressed: () {
            if (ble.state == BleState.connected) {
              ble.disconnect();
            }
            SystemNavigator.pop();
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ── Tarjeta de conexión ────────────────────────────────────
  Widget _buildConnectCard(BleService ble) {
    final isConnected = ble.state == BleState.connected;
    final isScanning  = ble.state == BleState.scanning || ble.state == BleState.connecting;
    final preregistered = ref.watch(preregisteredProvider);
    final hasPreregistered = preregistered.isNotEmpty;

    // ── Estado: CONECTADO ────────────────────────────────────
    if (isConnected) {
      final devicesCount = ble.connectedDevices.length;
      final mainName = ble.toyProfile?.name ?? ble.connectedDeviceName;

      return CardGlass(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        borderColor: LvsColors.teal.withOpacity(0.3),
        child: Row(
          children: [
            Container(
              width: 10, height: 10,
              decoration: const BoxDecoration(
                color: LvsColors.teal, 
                shape: BoxShape.circle, 
                boxShadow: [BoxShadow(color: LvsColors.teal, blurRadius: 8, spreadRadius: 1)]
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    devicesCount > 1 ? '$mainName (+${devicesCount - 1})' : mainName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: LvsColors.teal, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                  Text(
                    devicesCount > 1 ? '$devicesCount LINKS ACTIVOS' : 'LINK ACTIVO',
                    style: TextStyle(fontSize: 9, color: LvsColors.text3, letterSpacing: 1.5),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_link, color: LvsColors.teal, size: 20),
              tooltip: 'Vincular otro dispositivo',
              onPressed: () {
                final catalog = ref.read(catalogProvider).asData?.value;
                ble.connectToDevice(catalog: catalog);
              },
            ),
            IconButton(
              icon: const Icon(Icons.link_off, color: Colors.redAccent, size: 20),
              tooltip: 'Desvincular todo',
              onPressed: ble.disconnect,
            ),
          ],
        ),
      );
    }

    // ── Estado: AUTO-BUSCANDO (con pre-registrados) ──────────
    if (hasPreregistered && _autoConnectEnabled) {
      return CardGlass(
        padding: const EdgeInsets.all(22),
        borderColor: LvsColors.pink.withOpacity(0.15),
        child: Column(
          children: [
            // Icono animado (pulso continuo mientras escanea)
            AnimatedBuilder(
              animation: _burstAnim,
              builder: (_, child) => Transform.scale(
                scale: isScanning ? (0.92 + _burstAnim.value * 0.08) : 1.0,
                child: child,
              ),
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LvsColors.bgCardH,
                  border: Border.all(
                    color: isScanning
                        ? LvsColors.pink.withOpacity(0.6)
                        : LvsColors.teal.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: isScanning ? [
                    BoxShadow(
                      color: LvsColors.pink.withOpacity(0.15 + _burstAnim.value * 0.15),
                      blurRadius: 20,
                      spreadRadius: 4,
                    )
                  ] : [],
                ),
                child: Icon(
                  isScanning ? Icons.bluetooth_searching : Icons.bluetooth_connected,
                  size: 28,
                  color: isScanning ? LvsColors.pink : LvsColors.teal.withOpacity(0.5),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Nombre(s) del dispositivo buscado
            Text(
              preregistered.map((t) => t.name).join(' · '),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3),
            ),
            const SizedBox(height: 4),
            Text(
              isScanning ? 'Buscando automáticamente...' : 'Reintentando en un momento...',
              style: TextStyle(
                  fontSize: 10,
                  color: isScanning ? LvsColors.pink : LvsColors.text3,
                  letterSpacing: 0.8),
            ),
            const SizedBox(height: 16),

            // Barra de progreso
            if (isScanning)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  backgroundColor: Colors.white10,
                  color: LvsColors.pink,
                  minHeight: 2,
                ),
              ),
            const SizedBox(height: 16),

            // Botones: Buscar ahora + Cancelar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isScanning ? null : () {
                      final catalog = ref.read(catalogProvider).asData?.value;
                      ble.connectToDevice(catalog: catalog);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('BUSCAR AHORA',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LvsColors.pink,
                      side: BorderSide(color: LvsColors.pink.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _cancelAutoConnect,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LvsColors.text3,
                    side: BorderSide(color: Colors.white12),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('CANCELAR',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Pre-registro (chips de dispositivos + agregar más)
            PreregisterPanel(onAdded: _tryAutoConnect),
          ],
        ),
      );
    }

    // ── Estado: MODO MANUAL (sin pre-registrados o cancelado) ─
    return CardGlass(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LvsColors.bgCardH,
              border: Border.all(color: LvsColors.pink.withOpacity(0.2)),
              boxShadow: isScanning ? [
                BoxShadow(color: LvsColors.pink.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)
              ] : [],
            ),
            child: Icon(
              isScanning ? Icons.bluetooth_searching : Icons.bluetooth, 
              size: 32, 
              color: isScanning ? LvsColors.pink : LvsColors.text3
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _autoConnectEnabled ? 'VINCULAR AHORA' : 'MODO MANUAL',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            _autoConnectEnabled
                ? 'Activa el modo emparejamiento y pulsa el botón.'
                : 'Auto-connect desactivado. Actívalo pre-registrando un dispositivo.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: LvsColors.text3, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Pre-registro
          PreregisterPanel(onAdded: _tryAutoConnect),
          const SizedBox(height: 16),

          // Botón de escaneo manual
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isScanning ? null : () {
                setState(() => _autoConnectEnabled = true);
                final catalog = ref.read(catalogProvider).asData?.value;
                ble.connectToDevice(catalog: catalog);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: LvsColors.pink.withOpacity(0.1),
                foregroundColor: LvsColors.pink,
                shadowColor: Colors.transparent,
                side: BorderSide(color: LvsColors.pink.withOpacity(0.4), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: isScanning
                ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: LvsColors.pink)),
                    SizedBox(width: 16), 
                    Text('BUSCANDO...', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2))
                  ])
                : const Text('INICIAR ESCANEO', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
            ),
          )
        ],
      ),
    );
  }

  // ── Dashboard Central (Intensidad / Círculo) ───────────────
  Widget _buildControlCard(WidgetRef ref) {
    final bleState = ref.watch(bleProvider.select((p) => p.state));
    if (bleState != BleState.connected) return const SizedBox.shrink();

    final ble = ref.read(bleProvider);
    final int maxIntensity = ref.watch(bleProvider.select((p) => p.displayIntensity));
    final activeSpeed = ref.watch(bleProvider.select((p) => p.activeSpeed));
    final intensityCh1 = ref.watch(bleProvider.select((p) => p.activeIntensityCh1));
    final intensityCh2 = ref.watch(bleProvider.select((p) => p.activeIntensityCh2));

    return Column(
      children: [
        const SizedBox(height: 10),
        
        // --- 1. RING INDICATOR NEÓN (IMAGE 1) ---
            RepaintBoundary(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glows (Pink left, Violet right)
                  Container(
                    width: 260, height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: LvsColors.red.withValues(alpha: 0.15),   blurRadius: 60, spreadRadius: 5, offset: const Offset(-20, 0)),
                        BoxShadow(color: LvsColors.pink.withValues(alpha: 0.15), blurRadius: 60, spreadRadius: 5, offset: const Offset(-10, 0)),
                        BoxShadow(color: LvsColors.violet.withValues(alpha: 0.15), blurRadius: 60, spreadRadius: 5, offset: const Offset(20, 0)),
                      ]
                    ),
                  ),
                  // Inner Static Background Ring
                  Container(
                    width: 230, height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 12),
                    ),
                  ),
                  // Gradient Active Ring
                  SizedBox(
                    width: 230, height: 230,
                    child: ShaderMask(
                      shaderCallback: (r) => const SweepGradient(
                        colors: [LvsColors.pink, LvsColors.red, LvsColors.pink, LvsColors.violet, LvsColors.pink],
                        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                        transform: GradientRotation(-pi/4),
                      ).createShader(r),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: maxIntensity.toDouble()),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, _) => CircularProgressIndicator(
                          value: val / 100, // En la variable local de UI es 0-100
                          strokeWidth: 10,
                          strokeCap: StrokeCap.round,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 5),
                const Text('INTENSITY', style: TextStyle(color: LvsColors.text2, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 2)),
                Text(
                  '$maxIntensity', 
                  style: const TextStyle(fontSize: 78, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)
                ),
                const Text('LEVEL', style: TextStyle(color: LvsColors.text1, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 6),
                const Text('Inter, Regular, 18px', style: TextStyle(color: LvsColors.text3, fontSize: 9)),
                const Text('subtle glow', style: TextStyle(color: LvsColors.text3, fontSize: 9)),
              ],
            ),
          const SizedBox(height: 48),

        // --- 2. NEON PRESETS BARS (LOW MED HIGH) GLASS PANEL ---
        CardGlass(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _NeonPresetBtn(
                  label: 'LOW',
                  color: LvsColors.teal,
                  icon: Icons.wifi_tethering,
                  active: activeSpeed == SpeedLevel.low,
                  onTap: () => ble.selectSpeed(SpeedLevel.low),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _NeonPresetBtn(
                  label: 'MED',
                  color: LvsColors.pink,
                  icon: Icons.radio_button_checked,
                  active: activeSpeed == SpeedLevel.medium,
                  onTap: () => ble.selectSpeed(SpeedLevel.medium),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _NeonPresetBtn(
                  label: 'HIGH',
                  color: LvsColors.violet,
                  icon: Icons.signal_cellular_alt,
                  active: activeSpeed == SpeedLevel.high,
                  onTap: () => ble.selectSpeed(SpeedLevel.high),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // --- 3. SESSION BOX INFO ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text('SESSION:', style: TextStyle(color: LvsColors.text3, fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    Text('ACTIVE', style: TextStyle(color: LvsColors.text1, fontSize: 11, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Text('DURATION:', style: TextStyle(color: LvsColors.text3, fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    Text('45:32', style: TextStyle(color: LvsColors.text1, fontSize: 11, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Text('STATUS:', style: TextStyle(color: LvsColors.text3, fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    Text('SYNCED', style: TextStyle(color: LvsColors.text1, fontSize: 11, fontWeight: FontWeight.w800)),
                  ]),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),

        // --- 4. ADVANCED MANUAL CONTROLS & PATTERNS ---
        CardGlass(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              const Text('GENERAL (AMBOS)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: LvsColors.text3, letterSpacing: 1.5)),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  activeTrackColor: LvsColors.amber, inactiveTrackColor: LvsColors.borderH,
                  thumbColor: Colors.white, overlayColor: LvsColors.amber.withValues(alpha: 0.2),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                ),
                child: Slider(
                  value: (ble.activeIntensity ?? 0).toDouble(), min: 0, max: 100, divisions: 100,
                  onChanged: (v) { HapticFeedback.selectionClick(); ble.setProportionalIntensity(v.round()); },
                ),
              ),
              const SizedBox(height: 16),
              const Text('EMPUJE (CH1)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: LvsColors.text3, letterSpacing: 1.5)),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  activeTrackColor: LvsColors.pink, inactiveTrackColor: LvsColors.borderH,
                  thumbColor: Colors.white, overlayColor: LvsColors.pink.withValues(alpha: 0.2),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                ),
                child: Slider(
                  value: (ble.activePatternCh1 != null ? 0 : (intensityCh1 ?? 0)).toDouble(), min: 0, max: 100, divisions: 100,
                  onChanged: (v) { HapticFeedback.selectionClick(); ble.setProportionalChannel1(v.round()); },
                ),
              ),
              const SizedBox(height: 12),
              _PatternSelectorRow(
                activePattern: ble.activePatternCh1,
                color: LvsColors.pink,
                onSelect: (p) => ble.setPatternChannel1(p),
              ),
              const SizedBox(height: 24),
              const Text('VIBRACIÓN (CH2)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: LvsColors.text3, letterSpacing: 1.5)),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  activeTrackColor: LvsColors.teal, inactiveTrackColor: LvsColors.borderH,
                  thumbColor: Colors.white, overlayColor: LvsColors.teal.withValues(alpha: 0.2),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                ),
                child: Slider(
                  value: (ble.activePatternCh2 != null ? 0 : (intensityCh2 ?? 0)).toDouble(), min: 0, max: 100, divisions: 100,
                  onChanged: (v) { HapticFeedback.selectionClick(); ble.setProportionalChannel2(v.round()); },
                ),
              ),
              const SizedBox(height: 12),
              _PatternSelectorRow(
                activePattern: ble.activePatternCh2,
                color: LvsColors.teal,
                onSelect: (p) => ble.setPatternChannel2(p),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // --- 5. BOTÓN PARADA TOTAL ---
        GestureDetector(
          onTap: () {
            HapticFeedback.heavyImpact();
            _stopPulseAnim.forward(from: 0);
            ble.emergencyStop();
          },
          child: AnimatedBuilder(
            animation: _stopPulseAnim,
            builder: (_, child) => Transform.scale(scale: 1.0 - _stopPulseAnim.value * 0.05, child: child),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 0),
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: LvsColors.bgCardH,
                border: Border.all(color: LvsColors.red.withValues(alpha: 0.2)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.power_settings_new, color: LvsColors.red, size: 20),
                  SizedBox(width: 12),
                  Text('EMERGENCY STOP', style: TextStyle(color: LvsColors.red, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── MODO MULTIMEDIA (Nuevo) ──────────────────────────────────
  Widget _buildMediaSyncCard(BleService ble) {
    if (ble.state != BleState.connected) return const SizedBox.shrink();

    final media = ref.watch(mediaSyncProvider);

    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LvsColors.pink.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Image.asset('assets/icons/icon_sync_music.png', width: 42, height: 42),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MODO MULTIMEDIA', style: TextStyle(color: LvsColors.text1, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
                    Text(
                      media.fileName ?? 'Selecciona un audio local',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => media.pickFile(),
                icon: const Icon(Icons.cloud_upload_outlined, color: LvsColors.pink),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Barra de progreso
          Column(
            children: [
              LinearProgressIndicator(
                value: media.duration.inMilliseconds > 0 
                    ? media.position.inMilliseconds / media.duration.inMilliseconds 
                    : 0,
                backgroundColor: Colors.white12,
                color: LvsColors.pink,
                minHeight: 4,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(media.position), style: const TextStyle(color: Colors.white24, fontSize: 10)),
                  Text(_formatDuration(media.duration), style: const TextStyle(color: Colors.white24, fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Controles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(
                  media.isPlaying ? Icons.pause_circle : Icons.play_circle,
                  size: 54,
                  color: Colors.white,
                ),
                onPressed: media.fileName != null ? (media.isPlaying ? media.pause : media.play) : null,
              ),
              
              Flexible(
                child: ElevatedButton.icon(
                  onPressed: media.fileName != null ? media.toggleSync : null,
                  icon: Icon(media.isSyncing ? Icons.sync : Icons.sync_disabled, size: 18),
                  label: Text(media.isSyncing ? 'SINCRONIZADO' : 'SINCRONIZAR', overflow: TextOverflow.ellipsis),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: media.isSyncing ? LvsColors.pink : Colors.white12,
                    foregroundColor: media.isSyncing ? Colors.black : Colors.white38,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  // ── MODO JUEGO LOCAL (Nuevo) ──────────────────────────────────
  Widget _buildGameModeCard(BuildContext context, BleService ble) {
    if (ble.state != BleState.connected) return const SizedBox.shrink();

    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LvsColors.violet.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Image.asset('assets/icons/icon_game_roulette.png', width: 42, height: 42),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MODO JUEGO LOCAL', style: TextStyle(color: LvsColors.text1, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
                    Text(
                      'Match & Merge Frutas',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalGameScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: LvsColors.violet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('JUGAR', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Colisiones y fusiones (level-up) generan respuestas hápticas variables en tiempo real.', style: TextStyle(color: LvsColors.text3, fontSize: 10, height: 1.4)),
        ],
      ),
    );
  }

  // ── ACOMPAÑANTE DIGITAL (Nuevo) ──────────────────────────────────
  Widget _buildCompanionCard(BuildContext context, BleService ble) {
    if (ble.state != BleState.connected) return const SizedBox.shrink();

    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LvsColors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Image.asset('assets/icons/icon_ai_assistant.png', width: 42, height: 42),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ACOMPAÑANTE DIGITAL', style: TextStyle(color: LvsColors.text1, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
                    const Text(
                      'IA Generativa (Gemini 2.0)',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanionScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: LvsColors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('HABLAR', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Avatar háptico dinámico: las emociones de la IA se traducen en ráfagas físicas directas.', style: TextStyle(color: LvsColors.text3, fontSize: 10, height: 1.4)),
        ],
      ),
    );
  }

  // ── DADOS HÁPTICOS (Nuevo) ──────────────────────────────────
  Widget _buildDiceCard(BuildContext context, BleService ble) {
    if (ble.state != BleState.connected) return const SizedBox.shrink();

    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LvsColors.violet.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Image.asset('assets/icons/icon_tab_games.png', width: 42, height: 42),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DADOS HÁPTICOS', style: TextStyle(color: LvsColors.text1, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
                    const Text(
                      'Combinaciones Aleatorias Dual-Motor',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DiceScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: LvsColors.violet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('PROBAR', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Lanza los dados para explorar patrones híbridos de empuje (CH1) y vibración (CH2).', style: TextStyle(color: LvsColors.text3, fontSize: 10, height: 1.4)),
        ],
      ),
    );
  }

  // ── RULETA RUSA (Nuevo) ─────────────────────────────────────
  Widget _buildRouletteCard(BuildContext context, BleService ble) {
    if (ble.state != BleState.connected) return const SizedBox.shrink();

    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: LvsColors.red.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.timer_outlined, color: LvsColors.red, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RULETA RUSA', style: TextStyle(color: LvsColors.text1, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
                    const Text(
                      'Evento Aleatorio de Alta Intensidad',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RouletteScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: LvsColors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('JUGAR', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Un temporizador oculto detonará una ráfaga máxima al azar. Pon a prueba tus límites.', style: TextStyle(color: LvsColors.text3, fontSize: 10, height: 1.4)),
        ],
      ),
    );
  }

  // ── LECTOR HÁPTICO (Nuevo) ──────────────────────────────────
  Widget _buildReaderCard(BuildContext context, BleService ble) {
    if (ble.state != BleState.connected) return const SizedBox.shrink();

    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: LvsColors.teal.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.menu_book_outlined, color: LvsColors.teal, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LECTOR DINÁMICO', style: TextStyle(color: LvsColors.text1, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
                    const Text(
                      'Historias que cobran vida física',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReaderScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: LvsColors.teal,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('LEER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Convierte cualquier texto en una experiencia. Las palabras clave activan ráfagas específicas.', style: TextStyle(color: LvsColors.text3, fontSize: 10, height: 1.4)),
        ],
      ),
    );
  }




  // ── Tarjeta de Patrones Ecualizador ─────────────────────────
  Widget _buildPatternsCard(BleService ble) {
    if (ble.state != BleState.connected) return const SizedBox.shrink();

    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('RITMOS PREDISEÑADOS'),
          const SizedBox(height: 24),
          _PatternGrid(
            items: [
              _PatternItem('PULSO', LvsPattern.pat1, LvsColors.pink),
              _PatternItem('OLA',   LvsPattern.pat2, LvsColors.violet),
              _PatternItem('RAMPA', LvsPattern.pat3, LvsColors.teal),
              _PatternItem('FLIP',  LvsPattern.pat4, LvsColors.amber),
              _PatternItem('STORM', LvsPattern.pat5, LvsColors.green),
              _PatternItem('CHAOS', LvsPattern.pat6, LvsColors.red),
            ],
            active: ble.activePattern,
            enabled: ble.state == BleState.connected && !_shakeMode,
            onTap: (p) => ble.selectPattern(p),
          ),
        ],
      ),
    );
  }

  // ── Canvas de Dibujo Dinámico ─────────────────────────────
  Widget _buildCanvasCard(BleService ble) {
    if (ble.state != BleState.connected) return const SizedBox.shrink();

    return CardGlass(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('CANVAS DE DIBUJO (CH1)'),
          const SizedBox(height: 4),
          const Text('Dibuja para controlar el empuje en tiempo real', 
            style: TextStyle(fontSize: 10, color: LvsColors.text3)),
          const SizedBox(height: 20),
          _LvsCanvas(ble: ble),
        ],
      ),
    );
  }

  // ── Modo Agitar ───────────────────────────────────────────
  Widget _buildShakeCard(BleService ble) {
    if (ble.state != BleState.connected) return const SizedBox.shrink();

    return CardGlass(
      borderColor: _shakeMode ? LvsColors.pink.withOpacity(0.3) : null,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _shakeMode ? LvsColors.pink.withOpacity(0.1) : LvsColors.bgCardH,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.vibration, color: _shakeMode ? LvsColors.pink : LvsColors.text3),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MODO AGITAR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(_shakeMode ? 'Sincronizado con movimiento' : 'Control por acelerómetro', 
                  style: const TextStyle(fontSize: 11, color: LvsColors.text3)),
              ],
            ),
          ),
          Switch(
            value: _shakeMode,
            onChanged: (v) => _toggleShake(ble),
            activeColor: LvsColors.pink,
            activeTrackColor: LvsColors.pink.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  // ── Configuración Técnica ─────────────────────────────────
  Widget _buildSettingsCard(BleService ble) {
    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('CONFIGURACIÓN AVANZADA'),
          const SizedBox(height: 20),
          
          // Burst Interval
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Intervalo de Ráfaga', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: LvsColors.text2)),
              Text('${ble.burstIntervalMs}ms', style: const TextStyle(fontSize: 12, color: LvsColors.pink, fontWeight: FontWeight.w800)),
            ],
          ),
          Slider(
            value: ble.burstIntervalMs.toDouble(),
            min: 100, max: 1000, divisions: 18,
            activeColor: LvsColors.pink,
            onChanged: (v) => ble.setBurstInterval(v.round()),
          ),
          
          const SizedBox(height: 12),
          
          // Deep Scan
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DEEP SCAN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('Ignorar filtros rMesh estándar', style: TextStyle(fontSize: 10, color: LvsColors.text3)),
                  ],
                ),
              ),
              Switch(
                value: ble.isDeepScan, 
                onChanged: (v) => ble.toggleDeepScan(),
                activeColor: LvsColors.pink,
              ),
            ],
          ),
          
          const Divider(height: 32, color: LvsColors.border),
          
          // Packet Mode
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Protocolo Packet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: LvsColors.text3)),
              _ModeSwitcher(
                mode: ble.packetMode,
                onChanged: ble.setPacketMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebugButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebugScreen())),
      child: CardGlass(
        borderColor: LvsColors.amber.withOpacity(0.2),
        padding: const EdgeInsets.all(16),
        child: const Row(
          children: [
            Icon(Icons.bug_report_outlined, color: LvsColors.amber, size: 20),
            SizedBox(width: 14),
            Expanded(child: Text('TOOLS: DEPURACIÓN DE BYTES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: LvsColors.amber))),
            Icon(Icons.arrow_forward_ios, color: LvsColors.amber, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(BleService ble) {
    if (ble.logs.isEmpty) return const SizedBox.shrink();
    return CardGlass(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Flexible(child: SectionLabel('LOGS DE SISTEMA')),
              const SizedBox(width: 10),
              IconButton(icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: LvsColors.text3), onPressed: ble.clearLogs),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 120,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: ble.logs.length,
              itemBuilder: (_, i) {
                final log = ble.logs[ble.logs.length - 1 - i];
                return _LogRow(entry: log);
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCatalogCard(BuildContext context) {
    return CardGlass(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogScreen())),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                LvsColors.bgCard,
                LvsColors.violet.withOpacity(0.15),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: LvsColors.violet.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shopping_bag_outlined, color: LvsColors.violet, size: 28),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CATÁLOGO LVS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('Explora dispositivos verificados y compatibles.', style: TextStyle(color: LvsColors.text3, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemoteSessionCard(BuildContext context) {
    return CardGlass(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RemoteSessionScreen()),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                LvsColors.bgCard,
                LvsColors.pink.withOpacity(0.1),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 65, height: 65,
                decoration: BoxDecoration(
                  color: LvsColors.pink.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: LvsColors.pink.withValues(alpha: 0.2)),
                ),
                child: Image.asset(
                  'assets/icons/icon_remote_session.png', 
                  width: 44, height: 44,
                  errorBuilder: (_, __, ___) => const Icon(Icons.settings_remote, color: LvsColors.pink, size: 32),
                ),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SESIÓN REMOTA', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('Conecta con el link de tu pareja y controlen juntos.', maxLines: 1, overflow: TextOverflow.ellipsis, 
                      style: TextStyle(color: LvsColors.text3, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// WIDGETS AUXILIARES REDISEÑADOS
// ══════════════════════════════════════════════════════════

class _BleStateBox extends StatelessWidget {
  final BleState state;
  const _BleStateBox({required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch(state) {
      BleState.connected  => ('Online',   LvsColors.teal),
      BleState.scanning   => ('Scanning', LvsColors.amber),
      BleState.connecting => ('Joining',  LvsColors.amber),
      BleState.error      => ('Error',    LvsColors.red),
      BleState.idle       => ('Offline',  LvsColors.text3),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: color, pulse: state == BleState.scanning || state == BleState.connecting),
          const SizedBox(width: 8),
          Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: color)),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final Color color;
  final bool pulse;
  const _Dot({required this.color, required this.pulse});
  @override
  State<_Dot> createState() => _DotState();
}
class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return widget.pulse
      ? AnimatedBuilder(animation: _c, builder: (_, __) => _dot(_c.value))
      : _dot(1.0);
  }
  Widget _dot(double opacity) => Container(
    width: 6, height: 6, decoration: BoxDecoration(color: widget.color.withOpacity(opacity), shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: widget.color.withOpacity(opacity * 0.5), blurRadius: 4)]),
  );
}

// ── Neon Preset Button (Basado en la imagen 1) ─────────────────
class _NeonPresetBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData icon;
  final Color color;

  const _NeonPresetBtn({
    required this.label, 
    required this.active, 
    required this.onTap,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? color : color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 12)] : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? color : color.withValues(alpha: 0.6), size: 16),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1,
              color: active ? Colors.white : LvsColors.text1
            )),
            const SizedBox(height: 2),
            Text('Inter\n16px', textAlign: TextAlign.center, style: TextStyle(
              fontSize: 9, color: color.withValues(alpha: active ? 0.7 : 0.4)
            )),
          ],
        ),
      ),
    );
  }
}

class _PatternGrid extends StatelessWidget {
  final List<_PatternItem> items;
  final LvsPattern? active;
  final bool enabled;
  final ValueChanged<LvsPattern> onTap;

  const _PatternGrid({required this.items, required this.active, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final isActive = item.pattern == active;
        return GestureDetector(
          onTap: enabled ? () { HapticFeedback.selectionClick(); onTap(item.pattern); } : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isActive ? item.color.withOpacity(0.15) : LvsColors.bgCardH,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isActive ? item.color : LvsColors.borderH, width: isActive ? 2 : 1),
              boxShadow: isActive ? [BoxShadow(color: item.color.withOpacity(0.3), blurRadius: 16)] : [],
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isActive ? Icons.graphic_eq : Icons.noise_control_off,
                  color: isActive ? item.color : LvsColors.text3,
                  size: 26,
                ),
                const SizedBox(height: 8),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9, 
                    fontWeight: FontWeight.w900, 
                    letterSpacing: 1, 
                    color: isActive ? item.color : LvsColors.text2
                  )
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PatternItem {
  final String label;
  final LvsPattern pattern;
  final Color color;
  _PatternItem(this.label, this.pattern, this.color);
}

class _LogRow extends StatelessWidget {
  final LogEntry entry;
  const _LogRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = switch(entry.type) {
      'success' => LvsColors.teal,
      'error'   => LvsColors.red,
      'warn'    => LvsColors.amber,
      'cmd'     => LvsColors.pink,
      _         => LvsColors.text3,
    };
    final t = entry.time;
    final ts = '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}:${t.second.toString().padLeft(2,'0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ts, style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: LvsColors.text3)),
          const SizedBox(width: 8),
          Expanded(child: Text(entry.msg, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _ModeSwitcher extends StatelessWidget {
  final PacketMode mode;
  final ValueChanged<PacketMode> onChanged;
  const _ModeSwitcher({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LvsColors.bgCardH,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LvsColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChip('11B', PacketMode.b11, mode, onChanged),
          _buildChip('18B', PacketMode.b18, mode, onChanged),
        ],
      ),
    );
  }

  Widget _buildChip(String label, PacketMode m, PacketMode current, ValueChanged<PacketMode> cb) {
    final isActive = m == current;
    return GestureDetector(
      onTap: () => cb(m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? LvsColors.pink.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'monospace',
          color: isActive ? LvsColors.pink : LvsColors.text3)),
      ),
    );
  }
}

class _BurstIndicator extends StatelessWidget {
  final AnimationController anim;
  final int ms;
  const _BurstIndicator({required this.anim, required this.ms});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: LvsColors.green.withOpacity(0.08 + anim.value * 0.06),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: LvsColors.green.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(
              color: LvsColors.green.withOpacity(0.4 + anim.value * 0.6),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: LvsColors.green.withOpacity(anim.value * 0.5), blurRadius: 6)],
            )),
            const SizedBox(width: 8),
            Text('STREAMING ${ms}ms', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1, color: LvsColors.green)),
          ],
        ),
      ),
    );
  }
}

class _PatternSelectorRow extends StatelessWidget {
  final int? activePattern;
  final Color color;
  final Function(int) onSelect;

  const _PatternSelectorRow({this.activePattern, required this.color, required this.onSelect});

  static const Map<int, Map<String, dynamic>> _meta = {
    0: {'icon': Icons.tune, 'label': 'MANUAL'},
    1: {'icon': Icons.keyboard_double_arrow_up, 'label': 'SUAVE'},
    2: {'icon': Icons.bolt, 'label': 'MEDIO'},
    3: {'icon': Icons.rocket_launch, 'label': 'FUERTE'},
    4: {'icon': Icons.waves, 'label': 'OLA'},
    5: {'icon': Icons.graphic_eq, 'label': 'PULSO'},
    6: {'icon': Icons.trending_up, 'label': 'RAMPA'},
    7: {'icon': Icons.favorite, 'label': 'LATIDO'},
    8: {'icon': Icons.flash_on, 'label': 'CAOS'},
    9: {'icon': Icons.cyclone, 'label': 'TORNADO'},
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          for (int i = 0; i <= 9; i++)
            _PatternBtnV2(
              icon: _meta[i]!['icon'],
              label: _meta[i]!['label'],
              active: (i == 0) ? (activePattern == null) : (activePattern == i),
              color: color,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class _PatternBtnV2 extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _PatternBtnV2({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 68,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: active ? color.withOpacity(0.15) : LvsColors.bgCardH.withOpacity(0.5),
          border: Border.all(
            color: active ? color : LvsColors.borderH,
            width: active ? 1.5 : 1,
          ),
          boxShadow: active ? [
            BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, spreadRadius: 1)
          ] : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? color : LvsColors.text3, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                color: active ? color : LvsColors.text3,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallPatternBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _SmallPatternBtn({required this.label, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: active ? color.withOpacity(0.15) : Colors.transparent,
          border: Border.all(color: active ? color : LvsColors.borderH, width: 1),
        ),
        child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: active ? color : LvsColors.text3)),
      ),
    );
  }
}
class _LvsCanvas extends StatefulWidget {
  final BleService ble;
  const _LvsCanvas({required this.ble});

  @override
  State<_LvsCanvas> createState() => _LvsCanvasState();
}

class _LvsCanvasState extends State<_LvsCanvas> {
  Timer? _throttle;
  double _intensity = 0;
  bool _active = false;

  void _update(Offset pos, Size size) {
    final val = ((size.height - pos.dy) / size.height * 100).clamp(0.0, 100.0);
    
    setState(() {
      _intensity = val;
      _active = true;
    });
    
    // Throttling dinámico: 60ms para mayor fluidez (aprox 16 envíos/seg)
    if (_throttle == null || !_throttle!.isActive) {
      widget.ble.setProportionalChannel1(_intensity.round());
      _throttle = Timer(const Duration(milliseconds: 60), () {
        // Enviar el último valor capturado al final del ciclo de throttle
        if (_active) widget.ble.setProportionalChannel1(_intensity.round());
      });
    }
  }

  void _stop() {
    setState(() {
      _active = false;
      _intensity = 0;
    });
    _throttle?.cancel();
    widget.ble.setProportionalChannel1(0);
  }

  @override
  void dispose() {
    _throttle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 200);
        return GestureDetector(
          onPanStart: (details) => _update(details.localPosition, size),
          onPanUpdate: (details) => _update(details.localPosition, size),
          onPanEnd: (_) => _stop(),
          onPanCancel: () => _stop(),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: LvsColors.pink.withOpacity(0.2), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(
                painter: _CanvasPainter(_active ? _intensity : 0, LvsColors.pink),
              ),
            ),
          ),
        );
      }
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final double intensity;
  final Color color;
  _CanvasPainter(this.intensity, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // Dibujamos el área activa
    if (intensity > 0) {
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [color.withOpacity(0.1), color.withOpacity(0.5)],
        ).createShader(Rect.fromLTRB(0, 0, size.width, size.height));

      final h = (intensity / 100) * size.height;
      canvas.drawRect(Rect.fromLTRB(0, size.height - h, size.width, size.height), paint);
      
      // Línea de horizonte
      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawLine(Offset(0, size.height - h), Offset(size.width, size.height - h), linePaint);

      // Texto de nivel
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${intensity.round()}%',
          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(size.width / 2 - textPainter.width / 2, size.height - h - 25));
    }
  }

  @override
  bool shouldRepaint(_CanvasPainter old) => old.intensity != intensity;
}
