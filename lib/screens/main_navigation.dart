import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'tabs/control_tab.dart';
import 'tabs/settings_tab.dart';
import 'game_screen.dart';

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
    const LocalGameScreen(), // Using Game as a middle tab for now
    const SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LvsColors.background,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        child: CardGlass(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          borderRadius: 32,
          blur: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, 'CONTROL', 'assets/icons/icon_tab_control.png', fallback: Icons.gamepad_outlined),
              _buildNavItem(1, 'VELVET GAME', 'assets/icons/icon_tab_modes.png', fallback: Icons.videogame_asset_outlined),
              _buildNavItem(2, 'SISTEMA', 'assets/icons/icon_tab_settings.png', fallback: Icons.settings_outlined),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, String iconPath, {IconData? fallback}) {
    final isActive = _currentIndex == index;
    final color = isActive ? LvsColors.pink : LvsColors.text3;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? LvsColors.pink.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: isActive ? 1.0 : 0.6,
              child: Image.asset(
                iconPath,
                width: 24, height: 24,
                color: color,
                errorBuilder: (_, __, ___) => Icon(fallback ?? Icons.circle_outlined, size: 24, color: color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
