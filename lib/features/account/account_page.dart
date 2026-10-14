import 'package:flutter/material.dart';
import '../../core/network/http_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utils/media_url.dart';
import '../auth/data/auth_service.dart';
import '../auth/models/user_model.dart';
import '../market/data/cart_store.dart';
import '../market/presentation/orders_page.dart';
import '../market/presentation/widgets/common.dart';
import 'addresses_page.dart';

/// Buyer account — profile, orders, wishlist shortcut, appearance, sign out.
class AccountPage extends StatelessWidget {
  final VoidCallback onOpenWishlist;
  final VoidCallback onOpenCart;
  const AccountPage({super.key, required this.onOpenWishlist, required this.onOpenCart});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(backgroundColor: p.bg, title: const Text('Account')),
      body: ValueListenableBuilder<UserModel?>(
        valueListenable: Session.user,
        builder: (context, user, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            if (user == null) const _SignInCard() else _ProfileCard(user: user),
            const SizedBox(height: 20),
            _Group(children: [
              _Row(
                icon: Icons.receipt_long_outlined,
                tone: p.tone(0),
                label: 'My orders',
                onTap: () async {
                  if (!await ensureSignedIn(context, reason: 'Sign in to see your orders')) return;
                  if (context.mounted) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrdersPage()));
                  }
                },
              ),
              _Row(
                icon: Icons.location_on_outlined,
                tone: p.tone(2),
                label: 'Saved addresses',
                onTap: () async {
                  if (!await ensureSignedIn(context, reason: 'Sign in to manage your addresses')) return;
                  if (context.mounted) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddressesPage()));
                  }
                },
              ),
              _Row(icon: Icons.favorite_border_rounded, tone: p.tone(1), label: 'Wishlist', onTap: onOpenWishlist),
              ValueListenableBuilder<List<CartItem>>(
                valueListenable: CartStore.instance,
                builder: (_, __, ___) => _Row(
                  icon: Icons.shopping_bag_outlined,
                  tone: p.tone(3),
                  label: 'Cart',
                  trailing: CartStore.instance.count > 0 ? '${CartStore.instance.count} items' : null,
                  onTap: onOpenCart,
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _Group(children: [
              ValueListenableBuilder<ThemeMode>(
                valueListenable: AppController.themeMode,
                builder: (_, mode, __) => _Row(
                  icon: Icons.palette_outlined,
                  tone: p.tone(4),
                  label: 'Appearance',
                  trailing: switch (mode) {
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                    ThemeMode.system => 'System',
                  },
                  onTap: () => _pickTheme(context, mode),
                ),
              ),
              _Row(
                icon: Icons.help_outline_rounded,
                tone: p.tone(5),
                label: 'About Aptigen market',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Aptigen market',
                  applicationVersion: '1.0.0',
                  applicationIcon: Image.asset('assets/images/logo.png', width: 40, height: 40),
                  children: const [Text('Shop products from verified sellers across the Aptigen network.')],
                ),
              ),
            ]),
            if (user != null) ...[
              const SizedBox(height: 16),
              _Group(children: [
                _Row(
                  icon: Icons.logout_rounded,
                  tone: const Tone(Color(0x1FDC2626), AppColors.danger),
                  label: 'Sign out',
                  danger: true,
                  onTap: () => _signOut(context),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text("Your cart stays saved to your account. You'll need to sign in again to check out."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) await AuthService(ApiClient()).logout();
  }

  void _pickTheme(BuildContext context, ThemeMode current) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: RadioGroup<ThemeMode>(
          groupValue: current,
          onChanged: (m) {
            if (m != null) AppController.setMode(m);
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              RadioListTile(value: ThemeMode.system, title: Text('System')),
              RadioListTile(value: ThemeMode.light, title: Text('Light')),
              RadioListTile(value: ThemeMode.dark, title: Text('Dark')),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentDark]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Welcome to Aptigen market',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 6),
          const Text(
            'Sign in to check out, track orders and keep your wishlist and cart on every device.',
            style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFFDBEAFE)),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pushNamed('/login'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: p.isDark ? AppColors.accentDark : AppColors.accent,
              minimumSize: const Size(120, 44),
            ),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserModel user;
  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final avatar = MediaUrl.resolve(user.avatar, view: 'small');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.border)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: p.accentSoft,
            foregroundImage: avatar == null ? null : NetworkImage(avatar),
            child: Text(user.initials, style: TextStyle(color: p.accent, fontWeight: FontWeight.w700, fontSize: 18)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name ?? 'Aptigen buyer',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text)),
                if (user.email != null) Text(user.email!, style: TextStyle(fontSize: 13, color: p.textSecondary)),
                if (user.phone != null && user.phone!.isNotEmpty)
                  Text(user.phone!, style: TextStyle(fontSize: 13, color: p.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 64, color: p.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final String label;
  final String? trailing;
  final bool danger;
  final VoidCallback onTap;

  const _Row({
    required this.icon,
    required this.tone,
    required this.label,
    required this.onTap,
    this.trailing,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 19, color: tone.fg),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: danger ? AppColors.danger : p.text)),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(trailing!, style: TextStyle(fontSize: 13, color: p.textSecondary)),
              ),
            if (!danger) Icon(Icons.chevron_right_rounded, color: p.textTertiary),
          ],
        ),
      ),
    );
  }
}
