import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/theme.dart';
import 'package:velvet_sync/screens/tabs/control_tab.dart';
import 'package:velvet_sync/screens/tabs/modes_tab.dart';
import 'package:velvet_sync/screens/tabs/network_tab.dart';
import 'package:velvet_sync/screens/tabs/settings_tab.dart';
import 'package:velvet_sync/screens/web_catalog_screen.dart';

class MainNavigation extends ConsumerStatefulWidget {
  final int initialIndex;
  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  final List<Widget> _tabs = [
    const ControlTab(),
    const ModesTab(),
    const NetworkTab(),
    const WebCatalogScreen(),
    const SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LvsColors.bg,
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: LvsColors.bg,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: LvsColors.pink,
          unselectedItemColor: LvsColors.text3,
          selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          unselectedLabelStyle: const TextStyle(fontSize: 10, letterSpacing: 1),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.gamepad, size: 24),
              activeIcon: Icon(Icons.gamepad, size: 30),
              label: 'CONTROL',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore, size: 24),
              activeIcon: Icon(Icons.explore, size: 30),
              label: 'MODOS',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.public, size: 24),
              activeIcon: Icon(Icons.public, size: 30),
              label: 'REMOTO',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_mosaic, size: 24),
              activeIcon: Icon(Icons.auto_awesome_mosaic, size: 30),
              label: 'CATÁLOGO',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.build_circle, size: 24),
              activeIcon: Icon(Icons.build_circle, size: 30),
              label: 'SISTEMA',
            ),
          ],
        ),
      ),
    );
  }
}
