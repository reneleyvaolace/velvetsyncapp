// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/main.dart
// Entrypoint unificado de la plataforma (Refactored)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/ble/ble_service.dart';
import 'services/backend/sync_service.dart';
import 'services/ai/ai_hardware_bridge_service.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Inicializar Logger
  final logger = Logger();
  await logger.initFileLogging();
  
  lvsLog('Iniciando Velvet Sync App...', tag: 'APP');

  // 2. Cargar variables de entorno
  try {
    await dotenv.load(fileName: ".env");
    lvsLog('Variables de entorno cargadas', tag: 'APP');
  } catch (e) {
    lvsError('Error cargando .env: $e', tag: 'APP');
  }

  // 3. Iniciar el ProviderScope
  runApp(
    const ProviderScope(
      child: VelvetSyncApp(),
    )
  );
}

class VelvetSyncApp extends ConsumerWidget {
  const VelvetSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Inicializar servicios necesarios al arranque
    // ignore: unused_local_variable
    final ble = ref.watch(bleProvider);

    return MaterialApp(
      title: 'Velvet Sync',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.dark),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final baseTheme = ThemeData(brightness: brightness);
    return baseTheme.copyWith(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE91E63), // Velvet Pink
        brightness: brightness,
      ),
      textTheme: GoogleFonts.outfitTextTheme(baseTheme.textTheme),
    );
  }
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    lvsLog('Inicializando core services...', tag: 'APP');
    
    // 1. Inicializar BleService
    final bleService = ref.read(bleProvider);
    // await bleService.init(); // Si tuviera un init async
    
    // 2. Inicializar SyncService
    final syncService = ref.read(syncServiceProvider);
    await syncService.init();
    
    // 3. Inicializar AI Hardware Bridge
    final aiBridge = ref.read(aiHardwareBridgeProvider);
    await aiBridge.init(
      bleService: bleService,
      syncService: syncService,
    );

    lvsLog('App inicializada correctamente', tag: 'APP');
    
    // Simular tiempo de splash
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      // Navegar a la pantalla principal (Dashboard) cuando esté lista
      // Por ahora, una pantalla temporal de "AI Lab Ready"
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DebugDashboard())
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sync, size: 80, color: Color(0xFFE91E63)),
            const SizedBox(height: 24),
            Text(
              'VELVET SYNC',
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class DebugDashboard extends ConsumerWidget {
  const DebugDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleState = ref.watch(bleProvider).state;
    final bridgeState = ref.watch(aiBridgeStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Velvet Sync Debug')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard('BLE Status', bleState.name, Icons.bluetooth),
          _buildStatusCard('AI Bridge', bridgeState.name, Icons.psychology),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              // Navegar al catálogo web o local
            },
            icon: const Icon(Icons.explore),
            label: const Text('Open Device Catalog'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(aiHardwareBridgeProvider).executeAICommand(intensity: 128);
            },
            icon: const Icon(Icons.bolt),
            label: const Text('Test AI Bridge (128)'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, String status, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(
          status.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
      ),
    );
  }
}
