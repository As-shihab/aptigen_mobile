import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/shell/home_shell.dart';
import '../features/splash/presentation/splash_page.dart';

/// Smooth fade + slight upward slide transition used app-wide.
class _FadeSlideRoute extends PageRouteBuilder {
  final Widget page;
  _FadeSlideRoute({required this.page})
      : super(
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, animation, __, child) {
            final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
            return FadeTransition(
              opacity: fade,
              child: SlideTransition(position: slide, child: child),
            );
          },
        );
}

class AptigenApp extends StatelessWidget {
  const AptigenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppController.themeMode,
      builder: (_, mode, __) => MaterialApp(
        title: 'Aptigen market',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        // Large accessibility font sizes are honoured up to 1.15x — beyond
        // that fixed-size tiles and bars overflow (the yellow/black stripes).
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        initialRoute: '/splash',
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/splash':
              return _FadeSlideRoute(page: const SplashPage());
            case '/login':
              return _FadeSlideRoute(page: const LoginPage());
            case '/onboarding':
              return _FadeSlideRoute(page: const OnboardingPage());
            case '/home':
              return _FadeSlideRoute(page: const HomeShell());
            default:
              return _FadeSlideRoute(page: const HomeShell());
          }
        },
      ),
    );
  }
}
