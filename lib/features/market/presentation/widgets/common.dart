import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../auth/data/auth_service.dart';
import '../../../../shared/skeleton.dart';

/// Network image with a quiet placeholder — resolves relative media paths
/// and the `?view=small|large` size hint like `withImageView` on web.
class NetImage extends StatelessWidget {
  final String? url;
  final String? view;
  final BoxFit fit;
  final IconData fallbackIcon;
  final double iconSize;

  const NetImage(
    this.url, {
    super.key,
    this.view = 'small',
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.shopping_bag_outlined,
    this.iconSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final resolved = MediaUrl.resolve(url, view: view);
    final fallback = Container(
      color: p.fill,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, size: iconSize, color: p.textTertiary),
    );
    if (resolved == null) return fallback;
    return CachedNetworkImage(
      imageUrl: resolved,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Container(color: p.fill),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const SectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 8, 12),
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: p.accentSoft, shape: BoxShape.circle),
            child: Icon(icon, color: p.accent, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.45, color: p.textSecondary),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24)),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;
  const ErrorState({super.key, required this.onRetry, this.message = 'Check your connection and try again.'});

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.wifi_off_rounded,
        title: "Couldn't load this",
        message: message,
        actionLabel: 'Try again',
        onAction: onRetry,
      );
}

/// − qty + stepper with a minimum (listing min order) and maximum.
class QtyStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final bool compact;

  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 1 << 30,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final size = compact ? 32.0 : 46.0;
    Widget btn(IconData icon, bool enabled, VoidCallback onTap) => SizedBox(
          width: size,
          height: size,
          child: IconButton(
            onPressed: enabled ? onTap : null,
            padding: EdgeInsets.zero,
            iconSize: compact ? 16 : 18,
            color: p.text,
            disabledColor: p.textTertiary.withValues(alpha: 0.5),
            icon: Icon(icon),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: compact ? p.fill : null,
        border: compact ? null : Border.all(color: p.border),
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.remove_rounded, value > min, () => onChanged(value - 1)),
          SizedBox(
            width: compact ? 28 : 34,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: compact ? 13.5 : 15, fontWeight: FontWeight.w600, color: p.text),
            ),
          ),
          btn(Icons.add_rounded, value < max, () => onChanged(value + 1)),
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const Pill(this.label, {super.key, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.w700)),
      );
}

/// Pushes the sign-in screen when needed. Resolves true once signed in.
Future<bool> ensureSignedIn(BuildContext context, {String? reason}) async {
  if (Session.isSignedIn) return true;
  if (reason != null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(reason), duration: const Duration(seconds: 2)));
  }
  await Navigator.of(context).pushNamed('/login');
  return Session.isSignedIn;
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 1600)));
}

class ProductGridSkeleton extends StatelessWidget {
  final int count;
  const ProductGridSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: productGridDelegate(context),
        delegate: SliverChildBuilderDelegate(
          (_, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AspectRatio(aspectRatio: 1, child: Skeleton()),
              const SizedBox(height: 10),
              Skeleton(height: 12, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 6),
              Skeleton(width: 80, height: 12, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 12),
              Skeleton(width: 60, height: 16, borderRadius: BorderRadius.circular(4)),
            ],
          ),
          childCount: count,
        ),
      ),
    );
  }
}

/// Text area under the square photo on a [ProductTile].
const double kTileInfoHeight = 132;

/// Two-column product grid sized so a tile is always a square photo plus a
/// fixed info block — no overflow at any phone width.
SliverGridDelegate productGridDelegate(BuildContext context, {double horizontalPadding = 32}) {
  final width = MediaQuery.sizeOf(context).width;
  final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
  const spacing = 12.0;
  final tileWidth = (width - horizontalPadding - spacing * (columns - 1)) / columns;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    crossAxisSpacing: spacing,
    mainAxisSpacing: 16,
    mainAxisExtent: tileWidth + kTileInfoHeight,
  );
}
