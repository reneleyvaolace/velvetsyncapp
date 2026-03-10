// ═══════════════════════════════════════════════════════════════
// LVS Control · lib/main.dart · v1.3.0
// Punto de entrada — inicializa el Foreground Task y los providers
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'services/supabase_service.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

// ── Handler del Foreground Task (se ejecuta en segundo plano) ──
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(BleScanTaskHandler());
}

class BleScanTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // El servicio BLE sigue activo en background
    debugPrint('[BG] Foreground task iniciado');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Puede enviar datos de keepalive periódicos
    FlutterForegroundTask.updateService(
      notificationText: 'LVS Control activo • Fastcon/8154',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('[BG] Foreground task destruido');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NUEVO: Inicializar Supabase
  final supabase = SupabaseService();
  await supabase.initialize();

  // Orientación vertical forzada (app de control)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Estilo de la status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0D0D1A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Inicializar Foreground Task (Android)
  FlutterForegroundTask.initCommunicationPort();

  runApp(
    const ProviderScope(
      child: LvsControlApp(),
    ),
  );
}

class LvsControlApp extends StatelessWidget {
  const LvsControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LVS Control',
      debugShowCheckedModeBanner: false,
      theme: LvsTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
