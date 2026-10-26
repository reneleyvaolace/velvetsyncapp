// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/config/env.dart
// Configuración de compilación (--dart-define / env.json)
// ═══════════════════════════════════════════════════════════════

/// Valores inyectados en tiempo de compilación.
///
/// Nunca incluir aquí secretos de servidores: el valor de una
/// `String.fromEnvironment` viaja dentro del binario. Solo se admiten
/// la URL del proyecto y la clave anon (pública por diseño) de Supabase.
class AppEnv {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String aiProxyFunction =
      String.fromEnvironment('AI_PROXY_FUNCTION', defaultValue: 'ai-proxy');

  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
