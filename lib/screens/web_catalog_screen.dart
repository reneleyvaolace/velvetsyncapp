// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/screens/web_catalog_screen.dart
// Catálogo Web - Placeholder
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:velvet_sync/theme.dart';

class WebCatalogScreen extends StatelessWidget {
  const WebCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo Web'),
        backgroundColor: LvsColors.bg,
      ),
      backgroundColor: LvsColors.bg,
      body: const Center(
        child: Text(
          'Catálogo Web en construcción',
          style: TextStyle(color: LvsColors.text3, fontSize: 16),
        ),
      ),
    );
  }
} 
