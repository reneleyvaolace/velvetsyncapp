// ═══════════════════════════════════════════════════════════════
// Velvet Sync · Catálogo Web - Multiplataforma
// Android/iOS: WebView | Windows/Web: Navegador externo
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

class WebCatalogScreen extends ConsumerStatefulWidget {
  const WebCatalogScreen({super.key});

  @override
  ConsumerState<WebCatalogScreen> createState() => _WebCatalogScreenState();
}

class _WebCatalogScreenState extends ConsumerState<WebCatalogScreen> {
  static const String catalogUrl = 'https://velvetsynccatalog.vercel.app/';
  bool _attemptedLaunch = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _launchInBrowser() async {
    if (_attemptedLaunch) return;
    setState(() => _attemptedLaunch = true);
    
    final uri = Uri.parse(catalogUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error al abrir navegador: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el navegador. Ábrelo manualmente.'),
            backgroundColor: LvsColors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
    setState(() => _attemptedLaunch = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LvsColors.bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.language_rounded,
                color: LvsColors.pink,
                size: 80,
              ),
              const SizedBox(height: 32),
              const Text(
                'CATÁLOGO WEB',
                style: TextStyle(
                  color: LvsColors.text1,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'velvetsynccatalog.vercel.app',
                style: TextStyle(color: LvsColors.text3, fontSize: 12),
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: _attemptedLaunch ? null : _launchInBrowser,
                icon: _attemptedLaunch
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.open_in_browser, size: 18),
                label: Text(_attemptedLaunch ? 'ABRIENDO...' : 'ABRIR CATÁLOGO'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LvsColors.pink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'El catálogo se abrirá en tu navegador',
                style: TextStyle(color: LvsColors.text3, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
