import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/models/user_model.dart';
import '../data/market_service.dart';
import '../data/wishlist_store.dart';
import '../models/product_model.dart';
import 'widgets/common.dart';
import 'widgets/product_tile.dart';

/// Saved items (GET /api/market/wishlist). Unsaving from any heart removes
/// the item here live.
class WishlistPage extends StatefulWidget {
  final VoidCallback? onShop;
  const WishlistPage({super.key, this.onShop});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final _api = MarketService();
  List<ProductModel>? _items;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    Session.user.addListener(_load);
    WishlistStore.instance.addListener(_onIdsChanged);
    _load();
  }

  @override
  void dispose() {
    Session.user.removeListener(_load);
    WishlistStore.instance.removeListener(_onIdsChanged);
    super.dispose();
  }

  void _onIdsChanged() {
    final ids = WishlistStore.instance.value;
    final items = _items;
    if (items == null) return;
    // A newly saved item isn't in the local list yet — refetch to pick it up.
    if (ids.any((id) => !items.any((i) => i.id == id))) {
      _load();
    } else {
      setState(() => _items = items.where((i) => ids.contains(i.id)).toList());
    }
  }

  Future<void> _load() async {
    if (!Session.isSignedIn) {
      if (mounted) setState(() => _items = []);
      return;
    }
    setState(() => _error = false);
    try {
      final items = await _api.getWishlist();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(backgroundColor: p.bg, title: const Text('Wishlist')),
      body: ValueListenableBuilder<UserModel?>(
        valueListenable: Session.user,
        builder: (context, user, _) {
          if (user == null) {
            return Center(
              child: EmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'Save what you love',
                message: 'Sign in to keep a wishlist that follows you everywhere.',
                actionLabel: 'Sign in',
                onAction: () => Navigator.of(context).pushNamed('/login'),
              ),
            );
          }
          if (_items == null && _error) return ErrorState(onRetry: _load);
          if (_items == null) return const CustomScrollView(slivers: [ProductGridSkeleton()]);
          if (_items!.isEmpty) {
            return Center(
              child: EmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'Nothing saved yet',
                message: 'Tap the heart on any product to save it here.',
                actionLabel: 'Browse the market',
                onAction: widget.onShop,
              ),
            );
          }
          return RefreshIndicator(
            color: p.accent,
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Text(
                      '${_items!.length} saved item${_items!.length == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 13, color: p.textSecondary),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: productGridDelegate(context),
                    delegate: SliverChildBuilderDelegate((_, i) => ProductTile(_items![i]), childCount: _items!.length),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
