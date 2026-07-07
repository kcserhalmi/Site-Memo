import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    if (i != _index) HapticFeedback.selectionClick();
    setState(() {
      _initialized[i] = true;
      _index = i;
    });
  }

  Widget _screen(int i) {
    if (!_initialized[i]) return const SizedBox.shrink();
    switch (i) {
      case 0: return DashboardScreen(onOpenAccount: () => _switchTab(3));
      // active flag releases the camera whenever another tab is shown
      case 1: return CameraScreen(active: _index == 1);
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
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.07), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      // SafeArea keeps the nav above the iPhone home indicator
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.assignment_outlined, filledIcon: Icons.assignment, label: 'Jobs', selected: currentIndex == 0, onTap: () => onTap(0)),
              _NavItem(icon: Icons.photo_camera_outlined, filledIcon: Icons.photo_camera, label: 'Camera', selected: currentIndex == 1, onTap: () => onTap(1)),
              _NavItem(icon: Icons.search, filledIcon: Icons.search, label: 'Search', selected: currentIndex == 2, onTap: () => onTap(2)),
              _NavItem(icon: Icons.account_circle_outlined, filledIcon: Icons.account_circle, label: 'Account', selected: currentIndex == 3, onTap: () => onTap(3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
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
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected ? AppColors.primary : AppColors.outline;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: const Cubic(0.23, 1.0, 0.32, 1.0),
        child: SizedBox(
          width: 70,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.selected ? widget.filledIcon : widget.icon, color: color, size: 22),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: widget.selected ? 20 : 4,
                height: 3,
                decoration: BoxDecoration(
                  color: widget.selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(height: 3),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
