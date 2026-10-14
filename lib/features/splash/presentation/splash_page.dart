import 'package:flutter/material.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/theme/app_theme.dart';

/// Initial loader — centered logo, a progress indicator underneath, nothing
/// else. Replaces the old multi-effect splash (blur orbs, animated nav pin,
/// shimmer text) with just enough motion to feel alive: a soft fade/scale-in
/// for the logo and a looping gradient sweep on the bar.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _introCtrl;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;

  late final AnimationController _barCtrl;
  late final Animation<double> _barSweep;

  @override
  void initState() {
    super.initState();

    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _logoOpacity = CurvedAnimation(parent: _introCtrl, curve: Curves.easeOut);
    _logoScale = Tween(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _introCtrl, curve: Curves.easeOutCubic),
    );

    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _barSweep = Tween(begin: -1.0, end: 1.0).animate(_barCtrl);

    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    final seen = await AppStorage.hasSeenOnboarding();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, seen ? '/home' : '/onboarding');
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _barCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.slate950 : AppColors.white;
    final trackColor = isDark ? AppColors.slate800 : AppColors.slate100;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _logoOpacity,
              child: ScaleTransition(
                scale: _logoScale,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 56,
                  height: 56,
                ),
              ),
            ),
            const SizedBox(height: 28),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                width: 120,
                height: 4,
                child: AnimatedBuilder(
                  animation: _barCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _SweepPainter(
                      progress: _barSweep.value,
                      trackColor: trackColor,
                      sweepColor: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A soft gradient sweep looping across a rounded track bar.
class _SweepPainter extends CustomPainter {
  final double progress; // -1.0 to 1.0
  final Color trackColor;
  final Color sweepColor;
  _SweepPainter({
    required this.progress,
    required this.trackColor,
    required this.sweepColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = trackColor,
    );

    final sweepW = size.width * 0.6;
    final centerX = (progress + 1) / 2 * (size.width + sweepW) - sweepW / 2;
    final shader = LinearGradient(
      colors: [Colors.transparent, sweepColor, Colors.transparent],
    ).createShader(Rect.fromLTWH(centerX - sweepW / 2, 0, sweepW, size.height));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_SweepPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.sweepColor != sweepColor;
}
