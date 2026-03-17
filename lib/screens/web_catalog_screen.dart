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
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isExternal = false;

  static const String catalogUrl = 'https://velvetsynccatalog.vercel.app/';

  @override
  void initState() {
    super.initState();
    _checkPlatform();
  }

  Future<void> _checkPlatform() async {
    // WebView solo funciona en Android/iOS
    final isMobile = Theme.of(context).platform == TargetPlatform.android ||
                     Theme.of(context).platform == TargetPlatform.iOS;

    if (isMobile) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(LvsColors.bg)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) => setState(() => _isLoading = true),
            onPageFinished: (String url) => setState(() => _isLoading = false),
            onWebResourceError: (WebResourceError error) {
              debugPrint('Error: ${error.description}');
              _showErrorSnackbar();
            },
          ),
        )
        ..loadRequest(Uri.parse(catalogUrl));
    } else {
      _isExternal = true;
      _launchExternal();
    }
  }

  Future<void> _launchExternal() async {
    final uri = Uri.parse(catalogUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (mounted) Navigator.pop(context);
  }

  void _showErrorSnackbar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Error al cargar el catálogo'),
        backgroundColor: LvsColors.red,
        action: SnackBarAction(
          label: 'Abrir fuera',
          textColor: Colors.white,
          onPressed: _launchExternal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isExternal) {
      return Scaffold(
        backgroundColor: LvsColors.bg,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: LvsColors.pink),
              SizedBox(height: 16),
              Text(
                'Abriendo catálogo en el navegador...',
                style: TextStyle(color: LvsColors.text2, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: LvsColors.bg,
      appBar: AppBar(
        title: const Text('CATÁLOGO WEB'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: LvsColors.teal),
            tooltip: 'Recargar',
            onPressed: _controller != null ? () => _controller!.reload() : null,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser, color: LvsColors.pink),
            tooltip: 'Abrir en navegador',
            onPressed: _launchExternal,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_isLoading)
            Container(
              color: LvsColors.bg,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: LvsColors.pink),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando catálogo...',
                    style: TextStyle(color: LvsColors.text2, fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
