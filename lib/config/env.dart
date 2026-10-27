// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/config/env.dart
// Configuración de entorno (env.json via flutter_dotenv)
// ═══════════════════════════════════════════════════════════════
/// Valores cargados desde env.json via flutter_dotenv en runtime.
///
/// Requiere llamar `await dotenv.load(fileName: "env.json")` antes de usar.
/// Usar `dotenv.env['KEY']` directamente o los getters de esta clase.
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get aiProxyFunction => dotenv.env['AI_PROXY_FUNCTION'] ?? 'ai-proxy';

  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}