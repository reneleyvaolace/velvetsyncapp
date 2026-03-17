// WebView Catalog Screen

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme.dart';

class WebCatalogScreen extends StatefulWidget {
  const WebCatalogScreen({super.key});

  @override
  State<WebCatalogScreen> createState() => _WebCatalogScreenState();
}

class _WebCatalogScreenState extends State<WebCatalogScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  static const String catalogUrl = 'https://velvetsynccatalog.vercel.app/';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(LvsColors.bg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) => setState(() => _isLoading = true),
          onPageFinished: (String url) => setState(() => _isLoading = false),
          onWebResourceError: (WebResourceError error) => debugPrint('Error: ${error.description}'),
        ),
      )
      ..loadRequest(Uri.parse(catalogUrl));
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
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
