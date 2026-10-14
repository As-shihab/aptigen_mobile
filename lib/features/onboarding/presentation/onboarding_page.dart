import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/storage/app_storage.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  int _step = 0;
  int _dir = 1;

  late AnimationController _floatCtrl;
  late AnimationController _orbCtrl;

  static const _steps = [
    _Step(
      heading: 'The whole market,\nin your pocket.',
      subtitle: 'Shop products from verified sellers\nacross the Aptigen network.',
      gradient: [Color(0xFF0A6ED1), Color(0xFF0854A0)],
    ),
    _Step(
      heading: 'Deals worth\nthe scroll.',
      subtitle: 'On-sale picks, featured listings\nand top vendors, updated daily.',
      gradient: [Color(0xFFE11D48), Color(0xFFBE123C)],
    ),
    _Step(
      heading: 'Checkout\nin seconds.',
      subtitle: 'Cash on delivery, a cart that follows you\nacross devices, and order tracking.',
      gradient: [Color(0xFF059669), Color(0xFF047857)],
    ),
    _Step(
      heading: "Let's shop.",
      subtitle: 'Save favorites, follow stores\nand start exploring today.',
      gradient: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _orbCtrl.dispose();
    super.dispose();
  }

  void _go(int next) {
    if (next >= _steps.length) { _done(); return; }
    if (next < 0) return;
    setState(() {
      _dir = next > _step ? 1 : -1;
      _step = next;
    });
  }

  Future<void> _done() async {
    await AppStorage.setOnboardingSeen();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    final s = _steps[_step];
    final isLast = _step == _steps.length - 1;
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: s.gradient,
          ),
        ),
        child: Stack(
          children: [
            // Animated orbs
            AnimatedBuilder(
              animation: _orbCtrl,
              builder: (_, __) {
                final t = _orbCtrl.value;
                return Stack(children: [
                  Positioned(
                    top: -100 + t * 20,
                    left: size.width / 2 - 300,
                    child: Container(
                      width: 600, height: 600,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          Colors.white.withValues(alpha: 0.10 + t * 0.04),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: size.height * 0.05 - t * 20,
                    right: -100,
                    child: Container(
                      width: 400, height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          Colors.white.withValues(alpha: 0.06 + t * 0.02),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                ]);
              },
            ),

            // Concentric rings
            Positioned.fill(
              child: CustomPaint(painter: _RingsPainter()),
            ),

            Column(
              children: [
                // Top bar
                Padding(
                  padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _GlassPill(
                        child: Text('aptigen',
                          style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w800,
                          )),
                      ),
                      AnimatedOpacity(
                        opacity: isLast ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: GestureDetector(
                          onTap: isLast ? null : _done,
                          child: _GlassPill(
                            child: Text('Skip',
                              style: GoogleFonts.poppins(
                                color: Colors.white, fontSize: 13,
                                fontWeight: FontWeight.w600,
                              )),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Floating logo
                Expanded(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _floatCtrl,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, (_floatCtrl.value - 0.5) * 16),
                        child: child,
                      ),
                      child: Container(
                        width: 96, height: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Colors.white.withValues(alpha: 0.15),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset('assets/icon/icon.png',
                              fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                ),

                // Step content
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(_dir * 0.15, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Padding(
                    key: ValueKey(_step),
                    padding: EdgeInsets.fromLTRB(28, 0, 28, bottom + 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.heading,
                          style: GoogleFonts.poppins(
                            fontSize: 36, fontWeight: FontWeight.w900,
                            color: Colors.white, height: 1.1,
                          )),
                        const SizedBox(height: 12),
                        Text(s.subtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 14, height: 1.55,
                            color: Colors.white.withValues(alpha: 0.75),
                            fontStyle: _step < 2
                                ? FontStyle.italic
                                : FontStyle.normal,
                          )),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Dots
                            Row(
                              children: List.generate(_steps.length, (i) {
                                final active = i == _step;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                  margin: const EdgeInsets.only(right: 6),
                                  width: active ? 22 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),
                            // Next button
                            GestureDetector(
                              onTap: () => _go(_step + 1),
                              child: Container(
                                height: 48,
                                padding: EdgeInsets.symmetric(
                                    horizontal: isLast ? 28 : 20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.18),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ShaderMask(
                                      shaderCallback: (b) => LinearGradient(
                                        colors: s.gradient,
                                      ).createShader(b),
                                      child: Text(
                                        isLast ? 'Get started' : 'Next',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (!isLast) ...[
                                      const SizedBox(width: 6),
                                      ShaderMask(
                                        shaderCallback: (b) => LinearGradient(
                                          colors: s.gradient,
                                        ).createShader(b),
                                        child: const Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white, size: 18,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _GlassPill extends StatelessWidget {
  final Widget child;
  const _GlassPill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: child,
    );
  }
}

class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width / 2, size.height * 0.38);
    for (var r = 48.0; r < 500; r += 48) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _Step {
  final String heading;
  final String subtitle;
  final List<Color> gradient;
  const _Step({
    required this.heading,
    required this.subtitle,
    required this.gradient,
  });
}
