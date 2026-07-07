// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/main.dart
// Entrypoint unificado de la plataforma (Refactored & Robust)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velvet_sync/services/backend/supabase_service.dart';
import 'package:velvet_sync/services/backend/profile_service.dart';
import 'package:velvet_sync/services/backend/link_service.dart';
import 'package:velvet_sync/services/backend/sync_service.dart';
import 'package:velvet_sync/services/ai/ai_hardware_bridge_service.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/services/backend/auth_service.dart';
import 'package:velvet_sync/utils/logger.dart';
import 'package:velvet_sync/screens/auth_screen.dart';
import 'package:velvet_sync/screens/main_navigation.dart';
import 'package:velvet_sync/screens/contacts/my_profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Inicializar Logger
  final logger = Logger();
  await logger.initFileLogging();
  
  lvsLog('Iniciando Velvet Sync App...', tag: 'APP');

  // 2. Cargar variables de entorno
  try {
    await dotenv.load(fileName: '.env');
    lvsLog('Variables de entorno cargadas', tag: 'APP');
  } catch (e) {
    lvsError('Error crítico cargando .env: $e', tag: 'APP');
    // Continuamos pero los servicios fallarán si dependen de .env
  }

  // 3. Inicializar Supabase (servicio unificado)
  try {
    final supabaseService = SupabaseService();
    await supabaseService.initialize();

    final auth = supabaseService.client.auth;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
      lvsLog('Usuario anónimo autenticado', tag: 'APP');
    }
  } catch (e) {
    lvsError('Fallo inicialización Supabase en main: $e', tag: 'APP');
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
      fontFamily: 'Outfit',
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
  String _statusMessage = 'Inicializando core services...';

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      // 1. Inicializar LinkService
      setState(() => _statusMessage = 'Preparando Deep Links...');
      await ref.read(linkServiceProvider).init().timeout(const Duration(seconds: 3));
      
      if (!mounted) return;

      // 2. Cargar BleService
      setState(() => _statusMessage = 'Configurando Bluetooth...');
      final bleService = ref.read(bleProvider);
      await bleService.initSecurity();
      
      // 3. Inicializar SyncService (Supabase Realtime)
      setState(() => _statusMessage = 'Conectando con la nube...');
      await ref.read(syncServiceProvider).init().timeout(const Duration(seconds: 5));
      
      if (!mounted) return;

      // 4. Inicializar AI Hardware Bridge
      setState(() => _statusMessage = 'Activando Puente de IA...');
      final aiBridge = ref.read(aiHardwareBridgeProvider);
      await aiBridge.init(
        bleService: bleService,
        syncService: ref.read(syncServiceProvider),
      ).timeout(const Duration(seconds: 3));

      // 5. Cargar perfil de usuario
      setState(() => _statusMessage = 'Cargando perfil...');
      final profileService = ref.read(profileServiceProvider);
      await profileService.loadCachedProfile();

    } catch (e) {
      lvsError('Error en inicialización: $e', tag: 'APP');
      setState(() {
        _statusMessage = 'Error en algunos servicios. Continuando...';
      });
      await Future.delayed(const Duration(seconds: 1));
    }
    
    if (mounted) {
      setState(() => _statusMessage = '¡Todo listo!');
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      final auth = ref.read(authServiceProvider);
      final prefs = await SharedPreferences.getInstance();
      final hasEmail = auth.email != null;
      final skipAuth = prefs.getBool('skip_auth') ?? false;

      if (!hasEmail && !skipAuth) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => AuthScreen(
              onSkip: () async {
                final prefs2 = await SharedPreferences.getInstance();
                await prefs2.setBool('skip_auth', true);
                if (!mounted) return;
                if (!context.mounted) return;
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
        if (!mounted) return;
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
    if (!needsProfile) {
      profileService.updateLastSeen();
    }
    return needsProfile ? const MyProfileScreen() : const MainNavigation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
            Text(
              _statusMessage,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2,
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
              // Navegar al catálogo
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
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            color: status.toLowerCase() == 'error' ? Colors.red : Colors.blue
          ),
        ),
      ),
    );
  }
}
