import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/models/user_model.dart';
import '../../../core/network/http_client.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = AuthService(ApiClient());
  UserModel? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _auth.getStoredUser();
    if (mounted) setState(() { _user = user; _loading = false; });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Sign out',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to sign out?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign out',
                style: GoogleFonts.poppins(color: AppColors.rose500)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _auth.logout();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final top = MediaQuery.of(context).padding.top;

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.slate900 : AppColors.slate50,
        body: const Center(child: CircularProgressIndicator(color: AppColors.blue600)),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate900 : AppColors.slate50,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _ProfileHeader(user: _user, isDark: isDark, top: top),
            const SizedBox(height: 24),
            if (_user != null) _StatsRow(isDark: isDark),
            if (_user != null) const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _SettingsSection(
                    title: 'Account',
                    isDark: isDark,
                    items: [
                      _SettingItem(Icons.person_outline_rounded, 'Edit Profile', () {}),
                      _SettingItem(Icons.notifications_none_rounded, 'Notifications', () {}),
                      _SettingItem(Icons.favorite_border_rounded, 'Wishlist', () {}),
                      _SettingItem(Icons.history_rounded, 'Booking History', () {}),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    title: 'Preferences',
                    isDark: isDark,
                    items: [
                      _SettingItem(Icons.dark_mode_outlined, 'Appearance', () => _showThemePicker(context)),
                      _SettingItem(Icons.language_outlined, 'Language', () {}),
                      _SettingItem(Icons.help_outline_rounded, 'Help & Support', () {}),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_user != null)
                    _LogoutButton(onLogout: _logout)
                  else
                    _buildSignInPrompt(context),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.slate800 : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ThemePicker(isDark: isDark),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel? user;
  final bool isDark;
  final double top;

  const _ProfileHeader({
    required this.user,
    required this.isDark,
    required this.top,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, top + 20, 24, 28),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.settings_outlined,
                    color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.blue600, AppColors.indigo600],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 3),
            ),
            child: Center(
              child: Text(
                user?.initials ?? 'G',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user?.name ?? 'Guest',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (user?.email != null) ...[
            const SizedBox(height: 4),
            Text(
              user!.email!,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final bool isDark;
  const _StatsRow({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _StatCard('0', 'Bookings', isDark),
          const SizedBox(width: 12),
          _StatCard('0', 'Wishlist', isDark),
          const SizedBox(width: 12),
          _StatCard('0', 'Reviews', isDark),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final bool isDark;

  const _StatCard(this.value, this.label, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate100),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.blue600,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppColors.slate500),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final bool isDark;
  final List<_SettingItem> items;

  const _SettingsSection({
    required this.title,
    required this.isDark,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 4),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.slate500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate800 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark ? AppColors.slate700 : AppColors.slate100),
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return Column(
                children: [
                  _SettingRow(item: e.value, isDark: isDark),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 54,
                      color: isDark ? AppColors.slate700 : AppColors.slate100,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SettingItem(this.icon, this.label, this.onTap);
}

class _SettingRow extends StatelessWidget {
  final _SettingItem item;
  final bool isDark;
  const _SettingRow({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.blue600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon,
                    color: AppColors.blue600, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? AppColors.slate600 : AppColors.slate400),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onLogout;
  const _LogoutButton({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onLogout,
        icon: const Icon(Icons.logout_rounded, color: AppColors.rose500),
        label: Text(
          'Sign Out',
          style: GoogleFonts.poppins(
            color: AppColors.rose500,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.rose500, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

Widget _buildSignInPrompt(BuildContext context) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.blue600, AppColors.indigo600],
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Text(
          'Sign in to access your profile',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.blue600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text('Sign In',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    ),
  );
}

class _ThemePicker extends StatelessWidget {
  final bool isDark;
  const _ThemePicker({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appearance',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.slate900,
            ),
          ),
          const SizedBox(height: 16),
          ...ThemeMode.values.map((mode) {
            final icons = {
              ThemeMode.light: Icons.light_mode_outlined,
              ThemeMode.dark: Icons.dark_mode_outlined,
              ThemeMode.system: Icons.brightness_auto_outlined,
            };
            final labels = {
              ThemeMode.light: 'Light',
              ThemeMode.dark: 'Dark',
              ThemeMode.system: 'System default',
            };
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icons[mode],
                  color: isDark ? Colors.white : AppColors.slate900),
              title: Text(labels[mode]!,
                  style: GoogleFonts.poppins(
                      color: isDark ? Colors.white : AppColors.slate900)),
              onTap: () async {
                await AppStorage.setThemeMode(mode.name);
                if (context.mounted) Navigator.pop(context);
              },
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
