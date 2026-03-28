import 'package:flutter/material.dart';
import 'package:velvet_sync/theme.dart';

class RouletteScreen extends StatelessWidget {
  const RouletteScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RULETA')),
      body: const Center(child: Text('Próximamente: Ruleta de Juego')),
    );
  }
}

class ReaderScreen extends StatelessWidget {
  const ReaderScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LECTOR')),
      body: const Center(child: Text('Próximamente: Lector de Historias')),
    );
  }
}

class CompanionScreen extends StatelessWidget {
  const CompanionScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI COMPANION')),
      body: const Center(child: Text('Próximamente: Asistente AI')),
    );
  }
}

class RemoteSessionScreen extends StatelessWidget {
  const RemoteSessionScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SESIÓN REMOTA')),
      body: const Center(child: Text('Próximamente: Control a Distancia')),
    );
  }
}

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CATÁLOGO')),
      body: const Center(child: Text('Próximamente: Catálogo Completo')),
    );
  }
}
