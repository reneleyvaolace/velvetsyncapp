// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/main.dart · v2.1.0
// Punto de entrada — inicializa el Splash Screen y la navegación
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/supabase_service.dart';
import 'services/link_service.dart';
import 'services/sync_service.dart';
import 'services/ai_hardware_bridge_service.dart';
import 'screens/splash_screen.dart';
import 'screens/screenshot_gallery.dart';
import 'theme.dart';
import 'utils/logger.dart';

// ═══════════════════════════════════════════════════════════════
// MODO CAPTURA DE PANTALLA
// Para generar capturas, cambia esto a true temporalmente
// ═══════════════════════════════════════════════════════════════
const bool kScreenshotMode = false;

// ── Handler del Foreground Task (se ejecuta en segundo plano) ──
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(BleScanTaskHandler());
}

class BleScanTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    lvsLog('Foreground task iniciado', tag: 'BG');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.updateService(
      notificationText: 'Velvet Sync activo • High Performance',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    lvsLog('Foreground task destruido', tag: 'BG');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ═══════════════════════════════════════════════════════════════
  // INICIALIZACIÓN CON MANEJO DE ERRORES
  // Para debugging en emuladores y dispositivos reales
  // ═══════════════════════════════════════════════════════════════
  try {
    // Cargar variables de entorno (Secretos)
    await dotenv.load(fileName: ".env");
    lvsLog('.env cargado', tag: 'INIT');
  } catch (e) {
    lvsLog('⚠️ Error cargando .env: $e', tag: 'INIT');
    // Continuamos con defaults si falla
  }

  try {
    final supabase = SupabaseService();
    await supabase.initialize();
    lvsLog('Supabase listo', tag: 'INIT');
  } catch (e) {
    lvsLog('❌ Error inicializando Supabase: $e', tag: 'INIT');
    // No bloqueamos la app si Supabase falla
  }

  try {
    final linkService = LinkService();
    await linkService.init();
    lvsLog('Deep Linking listo', tag: 'INIT');
  } catch (e) {
    lvsLog('⚠️ Error en Deep Linking: $e', tag: 'INIT');
  }

  try {
    final syncService = SyncService();
    await syncService.init();
    lvsLog('Sync Service listo', tag: 'INIT');
  } catch (e) {
    lvsLog('⚠️ Error en Sync Service: $e', tag: 'INIT');
  }

  try {
    final aiBridge = AIHardwareBridge();
    await aiBridge.init();
    lvsLog('AI Bridge listo', tag: 'INIT');
  } catch (e) {
    lvsLog('⚠️ Error en AI Bridge: $e', tag: 'INIT');
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF05050A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  FlutterForegroundTask.initCommunicationPort();

  runApp(
    const ProviderScope(
      child: VelvetSyncApp(),
    ),
  );
}

class VelvetSyncApp extends StatelessWidget {
  const VelvetSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Velvet Sync',
      debugShowCheckedModeBanner: false,
      theme: LvsTheme.darkTheme,
      home: kScreenshotMode ? const ScreenshotGallery() : const SplashScreen(),
    );
  }
}
