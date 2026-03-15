// ═══════════════════════════════════════════════════════════════
// Velvet Sync · Herramienta de Capturas de Pantalla
// Muestra todas las pantallas en una cuadrícula para capturas fáciles
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lvs_control/theme.dart';
import 'package:lvs_control/screens/splash_screen.dart';
import 'package:lvs_control/screens/home_screen.dart';
import 'package:lvs_control/screens/main_navigation.dart';
import 'package:lvs_control/screens/catalog_screen.dart';
import 'package:lvs_control/screens/companion_screen.dart';
import 'package:lvs_control/screens/debug_screen.dart';
import 'package:lvs_control/screens/dice_screen.dart';
import 'package:lvs_control/screens/game_screen.dart';
import 'package:lvs_control/screens/reader_screen.dart';
import 'package:lvs_control/screens/remote_session_screen.dart';
import 'package:lvs_control/screens/roulette_screen.dart';
import 'package:lvs_control/screens/tabs/control_tab.dart';
import 'package:lvs_control/screens/tabs/modes_tab.dart';
import 'package:lvs_control/screens/tabs/network_tab.dart';
import 'package:lvs_control/screens/tabs/settings_tab.dart';

/// Widget que muestra una cuadrícula con todas las pantallas de la app
/// Para usar: Reemplaza temporalmente el home en main.dart con ScreenshotGallery()
class ScreenshotGallery extends StatelessWidget {
  const ScreenshotGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LvsColors.bg,
      appBar: AppBar(
        title: const Text('GALERÍA DE CAPTURAS'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => SystemNavigator.pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.6,
                ),
                delegate: SliverChildListDelegate([
                  _ScreenTile(
                    name: 'Splash',
                    icon: Icons.auto_awesome,
                    color: LvsColors.pink,
                    onTap: () => _navigateTo(context, 'Splash', const SplashScreen()),
                  ),
                  _ScreenTile(
                    name: 'Home',
                    icon: Icons.home,
                    color: LvsColors.teal,
                    onTap: () => _navigateTo(context, 'Home', const HomeScreen()),
                  ),
                  _ScreenTile(
                    name: 'Control Tab',
                    icon: Icons.dashboard,
                    color: LvsColors.violet,
                    onTap: () => _navigateTo(context, 'Control', const ControlTab()),
                  ),
                  _ScreenTile(
                    name: 'Modes Tab',
                    icon: Icons.play_circle,
                    color: LvsColors.amber,
                    onTap: () => _navigateTo(context, 'Modes', const ModesTab()),
                  ),
                  _ScreenTile(
                    name: 'Network Tab',
                    icon: Icons.public,
                    color: Colors.blue,
                    onTap: () => _navigateTo(context, 'Network', const NetworkTab()),
                  ),
                  _ScreenTile(
                    name: 'Settings',
                    icon: Icons.settings,
                    color: LvsColors.text1,
                    onTap: () => _navigateTo(context, 'Settings', const SettingsTab()),
                  ),
                  _ScreenTile(
                    name: 'Dice',
                    icon: Icons.casino,
                    color: LvsColors.amber,
                    onTap: () => _navigateTo(context, 'Dice', const DiceScreen()),
                  ),
                  _ScreenTile(
                    name: 'Roulette',
                    icon: Icons.timer,
                    color: LvsColors.red,
                    onTap: () => _navigateTo(context, 'Roulette', const RouletteScreen()),
                  ),
                  _ScreenTile(
                    name: 'Reader',
                    icon: Icons.book,
                    color: LvsColors.teal,
                    onTap: () => _navigateTo(context, 'Reader', const ReaderScreen()),
                  ),
                  _ScreenTile(
                    name: 'Companion',
                    icon: Icons.smart_toy,
                    color: LvsColors.pink,
                    onTap: () => _navigateTo(context, 'Companion', const CompanionScreen()),
                  ),
                  _ScreenTile(
                    name: 'Catalog',
                    icon: Icons.inventory,
                    color: LvsColors.violet,
                    onTap: () => _navigateTo(context, 'Catalog', const CatalogScreen()),
                  ),
                  _ScreenTile(
                    name: 'Remote',
                    icon: Icons.public,
                    color: Colors.blue,
                    onTap: () => _navigateTo(context, 'Remote', const RemoteSessionScreen()),
                  ),
                  _ScreenTile(
                    name: 'Debug',
                    icon: Icons.bug_report,
                    color: LvsColors.amber,
                    onTap: () => _navigateTo(context, 'Debug', const DebugScreen()),
                  ),
                  _ScreenTile(
                    name: 'Game',
                    icon: Icons.sports_esports,
                    color: LvsColors.green,
                    onTap: () => _navigateTo(context, 'Game', const LocalGameScreen()),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, String name, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: LvsColors.bg,
          appBar: AppBar(
            title: Text(name.toUpperCase()),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.screenshot),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Captura $name con Ctrl+S / Cmd+S'),
                      backgroundColor: LvsColors.teal,
                    ),
                  );
                },
              ),
            ],
          ),
          body: screen,
        ),
      ),
    );
  }
}

class _ScreenTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ScreenTile({
    required this.name,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CardGlass(
        borderColor: color.withOpacity(0.3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                color: LvsColors.text1,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
