import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/http_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_service.dart';

enum _Method { email, phone }

/// Account creation — mirrors the web signup (frontend/app/(auth)/signup).
/// Pops with the identifier used (email or phone) once the account is
/// created, so the login page can prefill it.
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _auth = AuthService(ApiClient());

  _Method _method = _Method.email;
  bool _loading = false;
  bool _obscure = true;
  bool _success = false;
  String _createdIdentifier = '';
  String? _error;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _clearError(String field) {
    if (_fieldErrors.containsKey(field) || _error != null) {
      setState(() {
        _fieldErrors = Map.of(_fieldErrors)..remove(field);
        _error = null;
      });
    }
  }

  Map<String, String> _validate() {
    final e = <String, String>{};
    if (_nameCtrl.text.trim().isEmpty) e['name'] = 'Enter your name.';
    if (_method == _Method.email) {
      final email = _emailCtrl.text.trim();
      if (email.isEmpty) {
        e['email'] = 'Enter your email.';
      } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
        e['email'] = 'Enter a valid email address.';
      }
    } else if (_phoneCtrl.text.trim().isEmpty) {
      e['phone'] = 'Enter your phone number.';
    }
    if (_passCtrl.text.length < 6) e['password'] = 'Use at least 6 characters.';
    return e;
  }

  Future<void> _signup() async {
    FocusScope.of(context).unfocus();
    final local = _validate();
    if (local.isNotEmpty) {
      setState(() {
        _fieldErrors = local;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _fieldErrors = {};
    });
    final isEmail = _method == _Method.email;
    final identifier = (isEmail ? _emailCtrl : _phoneCtrl).text.trim();
    try {
      // Only the chosen identifier is sent.
      await _auth.signup(
        name: _nameCtrl.text,
        password: _passCtrl.text,
        email: isEmail ? identifier : null,
        phone: isEmail ? null : identifier,
      );
      if (!mounted) return;
      setState(() {
        _success = true;
        _createdIdentifier = identifier;
      });
    } on ApiException catch (e) {
      final msg = e.message.trim();
      setState(() {
        _error = msg.isEmpty || msg.startsWith('Request failed')
            ? 'Something went wrong. Please try again.'
            : msg;
      });
    } catch (_) {
      setState(() => _error = 'Connection error. Check your internet.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _backToLogin() => Navigator.pop(
      context, _success && _createdIdentifier.isNotEmpty ? _createdIdentifier : null);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.gray100;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToLogin();
      },
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(
          children: [
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
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Brand(
                          isDark: isDark,
                          title: _success
                              ? 'Account created'
                              : 'Create your account',
                          subtitle: _success
                              ? "You're all set."
                              : 'Save your cart, track orders and follow your favourite stores.',
                        ),
                        const SizedBox(height: 32),
                        _GlassCard(
                          isDark: isDark,
                          child: _success
                              ? _SuccessBody(
                                  isDark: isDark,
                                  usedEmail: _createdIdentifier.contains('@'),
                                  onSignIn: _backToLogin,
                                )
                              : _formBody(isDark),
                        ),
                        const SizedBox(height: 20),
                        if (!_success)
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Already have an account? ',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.slate500
                                      : AppColors.slate400,
                                ),
                              ),
                              GestureDetector(
                                onTap: _loading ? null : _backToLogin,
                                child: Text(
                                  'Sign in',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent,
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
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: _backToLogin,
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: isDark ? AppColors.slate300 : AppColors.slate500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formBody(bool isDark) {
    final isEmail = _method == _Method.email;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MethodSwitch(
          isDark: isDark,
          value: _method,
          onChanged: (m) {
            if (_loading || m == _method) return;
            setState(() {
              _method = m;
              _fieldErrors = {};
              _error = null;
            });
          },
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          _ErrorBanner(message: _error!),
          const SizedBox(height: 16),
        ],
        _InputField(
          controller: _nameCtrl,
          label: 'Full name',
          hint: 'Your name',
          icon: Icons.person_outline_rounded,
          isDark: isDark,
          error: _fieldErrors['name'],
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          textInputAction: TextInputAction.next,
          onChanged: (_) => _clearError('name'),
        ),
        const SizedBox(height: 12),
        if (isEmail)
          _InputField(
            key: const ValueKey('email'),
            controller: _emailCtrl,
            label: 'Email',
            hint: 'you@example.com',
            icon: Icons.email_outlined,
            isDark: isDark,
            error: _fieldErrors['email'],
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearError('email'),
          )
        else
          _InputField(
            key: const ValueKey('phone'),
            controller: _phoneCtrl,
            label: 'Phone number',
            hint: '01XXXXXXXXX',
            icon: Icons.phone_outlined,
            isDark: isDark,
            error: _fieldErrors['phone'],
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
            ],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearError('phone'),
          ),
        const SizedBox(height: 12),
        _InputField(
          controller: _passCtrl,
          label: 'Password',
          hint: 'At least 6 characters',
          icon: Icons.lock_outline_rounded,
          isDark: isDark,
          error: _fieldErrors['password'],
          obscure: _obscure,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onChanged: (_) => _clearError('password'),
          onSubmit: _signup,
          suffix: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 18,
              color: isDark ? AppColors.slate500 : AppColors.slate400,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'Create account',
          loading: _loading,
          onTap: _signup,
        ),
      ],
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
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
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
  final String title;
  final String subtitle;
  const _Brand({
    required this.isDark,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset('assets/images/logo.png', width: 56, height: 56),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: isDark ? AppColors.white : AppColors.gray900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isDark ? AppColors.slate400 : AppColors.slate500,
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _GlassCard({required this.isDark, required this.child});

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
          child: child,
        ),
      ),
    );
  }
}

class _MethodSwitch extends StatelessWidget {
  final bool isDark;
  final _Method value;
  final ValueChanged<_Method> onChanged;
  const _MethodSwitch({
    required this.isDark,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget option(_Method m, String label) {
      final selected = m == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(m),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? (isDark ? AppColors.slate700 : AppColors.white)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: selected && !isDark
                  ? [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? (isDark ? AppColors.white : AppColors.gray900)
                    : (isDark ? AppColors.slate400 : AppColors.slate500),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.white.withValues(alpha: 0.06)
            : AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          option(_Method.email, 'Email'),
          const SizedBox(width: 4),
          option(_Method.phone, 'Phone'),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.rose500.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.rose500.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.error_outline, color: AppColors.rose500, size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(color: AppColors.rose500, fontSize: 13),
            ),
          ),
        ],
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
  final String? error;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmit;

  const _InputField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.error,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.textInputAction,
    this.onChanged,
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
          enableSuggestions: !obscure,
          autocorrect: !obscure && keyboardType != TextInputType.emailAddress,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isDark ? AppColors.darkFg : AppColors.lightFg,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon,
                size: 18,
                color: isDark ? AppColors.slate500 : AppColors.slate400),
            suffixIcon: suffix != null
                ? Padding(padding: const EdgeInsets.all(10), child: suffix)
                : null,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.rose500),
          ),
        ],
      ],
    );
  }
}

class _SuccessBody extends StatelessWidget {
  final bool isDark;
  final bool usedEmail;
  final VoidCallback onSignIn;
  const _SuccessBody({
    required this.isDark,
    required this.usedEmail,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: AppColors.success, size: 52),
              const SizedBox(height: 12),
              Text(
                'Account created — sign in to continue',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.white : AppColors.gray900,
                ),
              ),
              if (usedEmail) ...[
                const SizedBox(height: 6),
                Text(
                  'Check your inbox for a verification message.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: isDark ? AppColors.slate300 : AppColors.slate600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(label: 'Go to sign in', loading: false, onTap: onSignIn),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: loading ? null : AppGradients.primaryBtn,
        color: loading ? AppColors.slate300 : null,
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
          onTap: loading ? null : onTap,
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
                    label,
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
