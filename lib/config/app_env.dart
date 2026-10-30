// ════════════════════════════════════════════════════════════════
// Velvet Sync · lib/config/app_env.dart
// Variables de entorno cargadas desde env.json (assets de Flutter)
// ════════════════════════════════════════════════════════════════

class AppEnv {
  static String supabaseUrl = '';
  static String supabaseAnonKey = '';
  static String resendApiKey = '';
  static bool loaded = false;

  // ── URLs centralizadas (evitar hardcodeo en servicios) ──
  static const String webCatalogUrl = 'https://velvetsynccatalog.vercel.app/';
  static const String resetPasswordRedirect = 'https://velvetsynccatalog.vercel.app/reset-password.html';
  static const String loveSpouseApiBase = 'https://lovespouse.zlmicro.com/index.php';
}
