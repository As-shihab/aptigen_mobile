import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';

/// Frosted-glass header matching Header.tsx exactly.
/// Wrap in a [Padding] with top = MediaQuery.padding.top + 8.
class AptigenAppBar extends StatelessWidget {
  final bool isDark;
  final VoidCallback? onSearch;
  final bool showSignIn;
  final Widget? trailing;

  const AptigenAppBar({
    super.key,
    required this.isDark,
    this.onSearch,
    this.showSignIn = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.slate900.withValues(alpha: 0.8)
                : AppColors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? AppColors.slate800.withValues(alpha: 0.5)
                  : AppColors.white.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.10),
                blurRadius: 25,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Logo
              Image.asset('assets/images/logo.png', width: 32, height: 32),
              const SizedBox(width: 8),
              Text(
                'Aptigen',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: -0.5,
                  color:
                      isDark ? AppColors.darkFg : AppColors.lightFg,
                ),
              ),
              const Spacer(),
              if (onSearch != null)
                _IconBtn(
                    icon: Icons.search_rounded,
                    isDark: isDark,
                    onTap: onSearch!),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                trailing!,
              ],
              if (showSignIn)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.blue600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Sign in',
                    style: GoogleFonts.poppins(
                      color: AppColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _IconBtn(
      {required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : AppColors.slate100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDark ? AppColors.slate300 : AppColors.slate600,
        ),
      ),
    );
  }
}

/// Gradient background orbs — matches page.tsx background blobs.
class BackgroundOrbs extends StatelessWidget {
  const BackgroundOrbs({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Stack(
          children: [
            // top-right: blue/indigo orb
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.blueOrb,
                ),
                child: const SizedBox.shrink(),
              ),
            ),
            // bottom-left: emerald/teal orb
            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.emeraldOrb,
                ),
                child: const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
