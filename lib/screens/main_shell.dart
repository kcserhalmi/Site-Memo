import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart';
import 'camera_screen.dart';
import 'search_screen.dart';
import 'account_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  // Tracks which tabs have been opened at least once.
  // Unvisited tabs render as SizedBox.shrink() so they don't
  // allocate resources (camera, microphone, etc.) until needed.
  final List<bool> _initialized = [true, false, false, false];

  void _switchTab(int i) {
    setState(() {
      _initialized[i] = true;
      _index = i;
    });
  }

  Widget _screen(int i) {
    if (!_initialized[i]) return const SizedBox.shrink();
    switch (i) {
      case 0: return DashboardScreen(onOpenAccount: () => _switchTab(3));
      case 1: return const CameraScreen();
      case 2: return const SearchScreen();
      case 3: return const AccountScreen();
      default: return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _index,
        children: List.generate(4, _screen),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _index,
        onTap: _switchTab,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(icon: Icons.assignment_outlined, filledIcon: Icons.assignment, label: 'Jobs', selected: currentIndex == 0, onTap: () => onTap(0)),
          _NavItem(icon: Icons.photo_camera_outlined, filledIcon: Icons.photo_camera, label: 'Camera', selected: currentIndex == 1, onTap: () => onTap(1)),
          _NavItem(icon: Icons.search, filledIcon: Icons.search, label: 'Search', selected: currentIndex == 2, onTap: () => onTap(2)),
          _NavItem(icon: Icons.account_circle_outlined, filledIcon: Icons.account_circle, label: 'Account', selected: currentIndex == 3, onTap: () => onTap(3)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData filledIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.filledIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.outline;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? filledIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}
