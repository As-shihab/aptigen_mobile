import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/http_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_service.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _auth = AuthService(ApiClient());
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _openSignup() async {
    final identifier = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const SignupPage()),
    );
    if (!mounted || identifier == null || identifier.isEmpty) return;
    setState(() {
      _emailCtrl.text = identifier;
      _passCtrl.clear();
      _error = null;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Account created — sign in to continue'),
      ));
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.login(email, pass);
      if (!mounted) return;
      // Opened from inside the market (checkout, wishlist…) → go back there.
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on ApiException catch (e) {
      setState(() {
        _error = e.statusCode == 401
            ? 'Invalid email, phone or password'
            : 'Login failed. Try again.';
      });
    } catch (_) {
      setState(() => _error = 'Connection error. Check your internet.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.gray100;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Animated blobs
          _Blob(
            top: -100,
            right: -80,
            color: AppColors.purple500.withValues(alpha: 0.15),
            size: 340,
          ),
          _Blob(
            bottom: 80,
            left: -100,
            color: AppColors.cyan500.withValues(alpha: 0.15),
            size: 280,
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Brand(isDark: isDark),
                    const SizedBox(height: 32),
                    _Card(
                      isDark: isDark,
                      emailCtrl: _emailCtrl,
                      passCtrl: _passCtrl,
                      loading: _loading,
                      obscure: _obscure,
                      error: _error,
                      onToggle: () =>
                          setState(() => _obscure = !_obscure),
                      onLogin: _login,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.slate500
                                : AppColors.slate400,
                          ),
                        ),
                        GestureDetector(
                          onTap: _loading ? null : _openSignup,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              'Create an account',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                tooltip: Navigator.canPop(context) ? 'Close' : 'Continue as guest',
                onPressed: () => Navigator.canPop(context)
                    ? Navigator.pop(context, false)
                    : Navigator.pushReplacementNamed(context, '/home'),
                icon: Icon(
                  Icons.close_rounded,
                  color: isDark ? AppColors.slate300 : AppColors.slate500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double? top, bottom, left, right;
  final Color color;
  final double size;

  const _Blob({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  final bool isDark;
  const _Brand({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset('assets/images/logo.png', width: 56, height: 56),
        const SizedBox(height: 12),
        Text(
          'Aptigen',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: isDark ? AppColors.white : AppColors.gray900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sign in to shop the market',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isDark ? AppColors.slate400 : AppColors.slate500,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final bool isDark;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool loading;
  final bool obscure;
  final String? error;
  final VoidCallback onToggle;
  final VoidCallback onLogin;

  const _Card({
    required this.isDark,
    required this.emailCtrl,
    required this.passCtrl,
    required this.loading,
    required this.obscure,
    required this.error,
    required this.onToggle,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.white.withValues(alpha: 0.05)
                : AppColors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? AppColors.white.withValues(alpha: 0.1)
                  : AppColors.gray200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.rose500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            AppColors.rose500.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.rose500, size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error!,
                          style: GoogleFonts.poppins(
                              color: AppColors.rose500, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _InputField(
                controller: emailCtrl,
                label: 'Email or phone',
                hint: 'you@example.com',
                icon: Icons.email_outlined,
                isDark: isDark,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _InputField(
                controller: passCtrl,
                label: 'Password',
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                isDark: isDark,
                obscure: obscure,
                onSubmit: onLogin,
                suffix: GestureDetector(
                  onTap: onToggle,
                  child: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: isDark
                        ? AppColors.slate500
                        : AppColors.slate400,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _LoginButton(loading: loading, onLogin: onLogin),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isDark;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final VoidCallback? onSubmit;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.slate300 : AppColors.gray900,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          onSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color:
                isDark ? AppColors.darkFg : AppColors.lightFg,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon,
                size: 18,
                color: isDark
                    ? AppColors.slate500
                    : AppColors.slate400),
            suffixIcon: suffix != null
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: suffix,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _LoginButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onLogin;
  const _LoginButton({required this.loading, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient:
            loading ? null : AppGradients.primaryBtn,
        color: loading
            ? AppColors.slate300
            : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: loading
            ? null
            : [
                BoxShadow(
                  color: AppColors.blue600.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onLogin,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: AppColors.white, strokeWidth: 2),
                  )
                : Text(
                    'Sign in',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
