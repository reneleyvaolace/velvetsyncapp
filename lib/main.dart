// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/main.dart
// Entrypoint unificado de la plataforma (Refactored)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:velvet_sync/config/env.dart';
import 'package:velvet_sync/services/ble/ble_service_platform.dart';
import 'package:velvet_sync/services/backend/sync_service.dart';
import 'package:velvet_sync/services/backend/link_service.dart';
import 'package:velvet_sync/services/backend/profile_service.dart';
import 'package:velvet_sync/services/backend/auth_service.dart';
import 'package:velvet_sync/services/ai/ai_hardware_bridge_service.dart';
import 'package:velvet_sync/utils/logger.dart';
import 'package:velvet_sync/screens/main_navigation.dart';
import 'package:velvet_sync/screens/contacts/my_profile_screen.dart';
import 'package:velvet_sync/screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Cargar variables de entorno desde env.json
  await dotenv.load(fileName: "env.json");
  
  // 2. Inicializar Logger
  final logger = Logger();
  await logger.initFileLogging();
  
  lvsLog('Iniciando Velvet Sync App...', tag: 'APP');

  // 3. Inicializar Supabase Temprano
  // Usar valores de dotenv (cargados desde env.json)
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 10),
      );
      lvsLog('Supabase inicializado en main()', tag: 'APP');
    } catch (e) {
      if (e.toString().contains('already been initialized')) {
        lvsLog('Supabase ya estaba inicializado', tag: 'APP');
      } else {
        lvsError('Fallo inicialización Supabase en main: $e', tag: 'APP');
      }
    }
  } else {
    lvsLog('Supabase sin configurar (falta env.json); modo offline', tag: 'APP');
  }

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
    return MaterialApp(
      title: 'Velvet Sync',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.dark),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final baseTheme = ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: const Color(0xFF0D0D12),
      fontFamily: 'Outfit', // Fuente local en assets/fonts/
    );
    return baseTheme.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE91E63),
        brightness: brightness,
      ),
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
    
    try {
      // 1. Inicializar LinkService (con timeout)
      await LinkService().init().timeout(const Duration(seconds: 3), onTimeout: () {
        lvsLog('LinkService timeout', tag: 'APP');
      });
      
      if (!mounted) return;

      // 2. Cargar BleService (síncrono)
      final bleService = ref.read(bleProvider);
      
      // 3. Inicializar SyncService (con timeout)
      await ref.read(syncServiceProvider).init().timeout(const Duration(seconds: 4), onTimeout: () {
        lvsLog('SyncService timeout', tag: 'APP');
      });
      
      // 4. Inicializar AI Hardware Bridge
      final aiBridge = ref.read(aiHardwareBridgeProvider);
      await aiBridge.init(
        bleService: bleService,
        syncService: ref.read(syncServiceProvider),
      ).timeout(const Duration(seconds: 3), onTimeout: () {
        lvsLog('AI Bridge timeout', tag: 'APP');
      });

    } catch (e) {
      lvsError('Error silencioso en inicialización: $e', tag: 'APP');
    }
    
    lvsLog('App inicializada correctamente o por timeout', tag: 'APP');
      
    if (mounted) {
      // Tiempo mínimo de Splash para ver el logo
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final auth = ref.read(authServiceProvider);
      final prefs = await SharedPreferences.getInstance();
      final hasEmail = auth.email != null;
      final skipAuth = prefs.getBool('skip_auth') ?? false;

      if (!hasEmail && !skipAuth) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => AuthScreen(
              onSkip: () async {
                (await SharedPreferences.getInstance()).setBool('skip_auth', true);
                if (!mounted) return;
                Navigator.of(context).pushReplacement(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => _getPostAuthScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    transitionDuration: const Duration(milliseconds: 800),
                  ),
                );
              },
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => _getPostAuthScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    }
  }

  Widget _getPostAuthScreen() {
    final profileService = ref.read(profileServiceProvider);
    final needsProfile = profileService.myProfile == null;
    return needsProfile ? const MyProfileScreen() : const MainNavigation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Logo Central ──────────────────────────────────────────
            Image.asset(
              'assets/images/logo_neon.png',
              height: 180,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.sync,
                size: 80,
                color: Color(0xFFE91E63),
              ),
            ),
            const SizedBox(height: 32),
            // ── Nombre de la App ──────────────────────────────────────
            const Text(
              'VELVET SYNC',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 40),
            // ── Indicador de Carga ────────────────────────────────────
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFFE91E63),
              ),
            ),
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