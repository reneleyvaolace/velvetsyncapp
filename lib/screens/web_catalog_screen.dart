import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:velvet_sync/theme.dart';
import 'package:velvet_sync/services/catalog/catalog_service.dart';

class WebCatalogScreen extends StatefulWidget {
  const WebCatalogScreen({super.key});

  @override
  State<WebCatalogScreen> createState() => _WebCatalogScreenState();
}

class _WebCatalogScreenState extends State<WebCatalogScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (_) => setState(() => _isLoading = false),
        onWebResourceError: (_) => setState(() => _isLoading = false),
      ))
      ..loadRequest(Uri.parse(kWebCatalogUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LvsColors.bg,
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: LvsColors.pink),
                  SizedBox(height: 16),
                  Text('Cargando catálogo...', style: TextStyle(color: LvsColors.text3, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
