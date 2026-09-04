import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../jobs/presentation/jobs_page.dart';
import '../market/presentation/market_page.dart';
import '../profile/presentation/profile_page.dart';
import '../stays/presentation/stays_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with TickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _navAnimCtrl;
  late final Animation<double> _navAnim;

  static const _pages = [
    StaysPage(),
    MarketPage(),
    JobsPage(),
    ProfilePage(),
  ];

  static const _navItems = [
    (icon: Icons.hotel_rounded, activeIcon: Icons.hotel_rounded, label: 'Stays'),
    (icon: Icons.storefront_outlined, activeIcon: Icons.storefront_rounded, label: 'Market'),
    (icon: Icons.work_outline_rounded, activeIcon: Icons.work_rounded, label: 'Jobs'),
    (icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _navAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _navAnim = CurvedAnimation(parent: _navAnimCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _navAnimCtrl.dispose();
    super.dispose();
  }

  void _switchTab(int i) {
    if (i == _index) return;
    _navAnimCtrl.forward(from: 0);
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.white,
      body: Stack(
        children: List.generate(
          _pages.length,
          (i) => AnimatedOpacity(
            opacity: i == _index ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: IgnorePointer(
              ignoring: i != _index,
              child: _pages[i],
            ),
          ),
        ),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            padding: EdgeInsets.only(
                left: 8, right: 8, top: 6, bottom: bottom + 6),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.slate900.withValues(alpha: 0.88)
                  : AppColors.white.withValues(alpha: 0.85),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? AppColors.slate800.withValues(alpha: 0.5)
                      : AppColors.slate200.withValues(alpha: 0.6),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                _navItems.length,
                (i) => _NavTab(
                  icon: _navItems[i].icon,
                  activeIcon: _navItems[i].activeIcon,
                  label: _navItems[i].label,
                  selected: i == _index,
                  isDark: isDark,
                  onTap: () => _switchTab(i),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.blue600.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedScale(
                scale: selected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Icon(
                  selected ? activeIcon : icon,
                  size: 22,
                  color: selected
                      ? AppColors.blue600
                      : (isDark ? AppColors.slate500 : AppColors.slate400),
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? AppColors.blue600
                    : (isDark ? AppColors.slate500 : AppColors.slate400),
              ),
              child: Text(label),
            ),
            const SizedBox(height: 2),
            // Active indicator dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: selected ? 16 : 0,
              height: 3,
              decoration: BoxDecoration(
                gradient: selected ? AppGradients.primaryBtn : null,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
