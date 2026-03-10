// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/main.dart · v2.1.0
// Punto de entrada — inicializa el Splash Screen y la navegación
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'services/supabase_service.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';
import 'utils/logger.dart';

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

  final supabase = SupabaseService();
  await supabase.initialize();

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
      home: const SplashScreen(),
    );
  }
}
