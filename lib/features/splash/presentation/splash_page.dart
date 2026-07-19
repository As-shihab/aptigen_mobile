import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/theme/app_theme.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  // Navigation icon: oscillates -40 → +40 → -40 (2s)
  late final AnimationController _navCtrl;
  late final Animation<double> _navX;
  late final Animation<double> _navRot;

  // Path draw: 0 → 1 → 0 (2s)
  late final Animation<double> _pathLen;

  // Pulsing orb: scale 1 → 1.5 → 1 (2s)
  late final AnimationController _orbCtrl;
  late final Animation<double> _orbScale;
  late final Animation<double> _orbOpacity;

  // Shimmer bar: -1 → 1 (1.5s linear)
  late final AnimationController _shimCtrl;
  late final Animation<double> _shimX;

  // Text bob: opacity + y (1.5s)
  late final AnimationController _textCtrl;
  late final Animation<double> _textOpacity;
  late final Animation<double> _textY;

  // Background blur orbs (3s, easeInOut)
  late final AnimationController _bgCtrl1;
  late final Animation<double> _bgAnim;

  @override
  void initState() {
    super.initState();

    _navCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
    _navX = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: -40.0, end: 40.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 50),
      TweenSequenceItem(
          tween: Tween(begin: 40.0, end: -40.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 50),
    ]).animate(_navCtrl);
    _navRot = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 0.0), weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: math.pi)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 10),
      TweenSequenceItem(
          tween: Tween(begin: math.pi, end: math.pi), weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: math.pi, end: 0.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 10),
    ]).animate(_navCtrl);
    _pathLen = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 50),
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 50),
    ]).animate(_navCtrl);

    _orbCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
    _orbScale = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.5)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 50),
      TweenSequenceItem(
          tween: Tween(begin: 1.5, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 50),
    ]).animate(_orbCtrl);
    _orbOpacity = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 0.1, end: 0.3)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 50),
      TweenSequenceItem(
          tween: Tween(begin: 0.3, end: 0.1)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 50),
    ]).animate(_orbCtrl);

    _shimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
    _shimX = Tween(begin: -1.0, end: 1.0).animate(_shimCtrl);

    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _textOpacity =
        Tween(begin: 0.5, end: 1.0).animate(
            CurvedAnimation(parent: _textCtrl, curve: Curves.easeInOut));
    _textY = Tween(begin: 0.0, end: -5.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeInOut));

    _bgCtrl1 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
    _bgAnim =
        CurvedAnimation(parent: _bgCtrl1, curve: Curves.easeInOut);

    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    final seen = await AppStorage.hasSeenOnboarding();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, seen ? '/home' : '/onboarding');
  }

  @override
  void dispose() {
    _navCtrl.dispose();
    _orbCtrl.dispose();
    _shimCtrl.dispose();
    _textCtrl.dispose();
    _bgCtrl1.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.slate950 : AppColors.white;
    final textPrimary = isDark ? AppColors.white : AppColors.gray900;
    final dashColor = isDark ? AppColors.slate800 : AppColors.slate200;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background blur orbs (matches loading.tsx) ─────────────────
          AnimatedBuilder(
            animation: _bgAnim,
            builder: (_, __) => Stack(
              fit: StackFit.expand,
              children: [
                // Blue orb — center
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 320 + _bgAnim.value * 60,
                    height: 320 + _bgAnim.value * 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.blue500.withValues(
                              alpha: 0.55 + _bgAnim.value * 0.15),
                          AppColors.blue500.withValues(alpha: 0.18),
                          AppColors.blue500.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                // Indigo orb — upper right
                Align(
                  alignment: const Alignment(0.75, -0.65),
                  child: Container(
                    width: 220 - _bgAnim.value * 20,
                    height: 220 - _bgAnim.value * 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF6366F1).withValues(
                              alpha: 0.40 + _bgAnim.value * 0.20),
                          const Color(0xFF6366F1).withValues(alpha: 0.10),
                          const Color(0xFF6366F1).withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                // Cyan orb — lower left
                Align(
                  alignment: const Alignment(-0.65, 0.55),
                  child: Container(
                    width: 250 + _bgAnim.value * 30,
                    height: 250 + _bgAnim.value * 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF06B6D4).withValues(
                              alpha: 0.35 + _bgAnim.value * 0.15),
                          const Color(0xFF06B6D4).withValues(alpha: 0.08),
                          const Color(0xFF06B6D4).withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Semi-transparent overlay — muted enough to keep orbs visible
          Container(color: bg.withValues(alpha: 0.52)),
          // ── Existing content ────────────────────────────────────────────
          Center(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo
            Image.asset(
              'assets/images/logo.png',
              width: 64,
              height: 64,
            ),
            const SizedBox(height: 40),

            // ── Animated route widget ──
            SizedBox(
              width: 128,
              height: 128,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing orb
                  AnimatedBuilder(
                    animation: _orbCtrl,
                    builder: (_, __) => Transform.scale(
                      scale: _orbScale.value,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.blue500
                              .withValues(alpha: _orbOpacity.value),
                        ),
                        child: const SizedBox.shrink(),
                      ),
                    ),
                  ),

                  // Dashed path background
                  _DashedLine(color: dashColor),

                  // Animated blue path
                  AnimatedBuilder(
                    animation: _navCtrl,
                    builder: (_, __) => _AnimatedPath(
                        progress: _pathLen.value,
                        color: AppColors.blue500),
                  ),

                  // Start pin (left, gray)
                  Positioned(
                    left: 0,
                    child: Icon(Icons.location_on_rounded,
                        size: 16,
                        color: isDark
                            ? AppColors.slate700
                            : AppColors.slate300),
                  ),

                  // End pin (right, blue)
                  Positioned(
                    right: 0,
                    child: Icon(Icons.location_on_rounded,
                        size: 16, color: AppColors.blue500),
                  ),

                  // Moving navigation icon
                  AnimatedBuilder(
                    animation: _navCtrl,
                    builder: (_, __) => Transform.translate(
                      offset: Offset(_navX.value, 0),
                      child: Transform.rotate(
                        angle: _navRot.value,
                        child: Icon(
                          Icons.navigation_rounded,
                          size: 32,
                          color: isDark
                              ? AppColors.blue400
                              : AppColors.blue600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // "Powering up Aptigen"
            AnimatedBuilder(
              animation: _textCtrl,
              builder: (_, __) => Transform.translate(
                offset: Offset(0, _textY.value),
                child: Opacity(
                  opacity: _textOpacity.value,
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: textPrimary,
                      ),
                      children: [
                        const TextSpan(text: 'POWERING UP '),
                        TextSpan(
                          text: 'APTIGEN',
                          style: GoogleFonts.poppins(
                            color: AppColors.blue600,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Optimizing your experience... ⚡',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.slate400,
              ),
            ),

            const SizedBox(height: 28),

            // Shimmer progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                width: 240,
                height: 2,
                child: AnimatedBuilder(
                  animation: _shimCtrl,
                  builder: (_, __) {
                    return CustomPaint(
                      painter: _ShimmerPainter(
                        progress: _shimX.value,
                        trackColor: isDark
                            ? AppColors.slate800
                            : AppColors.slate100,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
        ],
      ),
    );
  }
}

/// Static dashed horizontal line through center.
class _DashedLine extends StatelessWidget {
  final Color color;
  const _DashedLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(128, 2),
      painter: _DashedLinePainter(color: color),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dashW = 4.0;
    const gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, size.height / 2),
          Offset(math.min(x + dashW, size.width), size.height / 2),
          paint);
      x += dashW + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}

/// Animated blue path that grows/shrinks from left.
class _AnimatedPath extends StatelessWidget {
  final double progress;
  final Color color;
  const _AnimatedPath({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(128, 2),
      painter: _PathPainter(progress: progress, color: color),
    );
  }
}

class _PathPainter extends CustomPainter {
  final double progress;
  final Color color;
  _PathPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width * progress, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.progress != progress || old.color != color;
}

/// Shimmer sweep over a track bar.
class _ShimmerPainter extends CustomPainter {
  final double progress; // -1.0 to 1.0
  final Color trackColor;
  _ShimmerPainter({required this.progress, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Track
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = trackColor);

    // Shimmer gradient sweep
    final sweepW = size.width * 0.5;
    final centerX = (progress + 1) / 2 * (size.width + sweepW) - sweepW / 2;
    final shader = LinearGradient(
      colors: [
        Colors.transparent,
        AppColors.blue600,
        Colors.transparent,
      ],
    ).createShader(
        Rect.fromLTWH(centerX - sweepW / 2, 0, sweepW, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) =>
      old.progress != progress || old.trackColor != trackColor;
}

