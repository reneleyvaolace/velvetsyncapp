import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lvs_control/theme.dart';
import 'package:lvs_control/screens/home_screen.dart'; // Mantendremos HomeScreen como la base por ahora y la refactorizaremos
import 'package:lvs_control/screens/tabs/control_tab.dart';
import 'package:lvs_control/screens/tabs/modes_tab.dart';
import 'package:lvs_control/screens/tabs/network_tab.dart';
import 'package:lvs_control/screens/tabs/settings_tab.dart';

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const ControlTab(),
    const ModesTab(),
    const NetworkTab(),
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
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
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
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard, color: LvsColors.pink),
              label: 'CONTROL',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.play_circle_outline),
              activeIcon: Icon(Icons.play_circle, color: LvsColors.pink),
              label: 'MODOS',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.public_outlined),
              activeIcon: Icon(Icons.public, color: LvsColors.pink),
              label: 'REMOTO',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings, color: LvsColors.pink),
              label: 'SISTEMA',
            ),
          ],
        ),
      ),
    );
  }
}
