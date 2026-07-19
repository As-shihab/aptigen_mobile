import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/http_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/aptigen_app_bar.dart';
import '../data/cart_store.dart';
import '../data/market_service.dart';
import '../models/product_model.dart';
import 'product_detail_page.dart';
import 'widgets/product_card.dart';

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  final _service = MarketService(ApiClient());
  List<ProductModel> _all = [];
  List<ProductModel> _filtered = [];
  bool _loading = true;
  String? _error;
  String _activeCategory = 'All';
  final _searchCtrl = TextEditingController();

  static const _categories = [
    ('All', '🛍️'),
    ('Tech', '💻'),
    ('Audio', '🎧'),
    ('Wearables', '⌚'),
    ('Lifestyle', '✨'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await _service.getProducts();
      if (!mounted) return;
      setState(() {
        _all = products;
        _filtered = products;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load products. Pull to retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((p) {
        if (_activeCategory != 'All' && p.category != _activeCategory) {
          return false;
        }
        if (q.isEmpty) return true;
        return p.name.toLowerCase().contains(q) ||
            (p.brand?.toLowerCase().contains(q) ?? false) ||
            (p.category?.toLowerCase().contains(q) ?? false);
      }).toList();
    });
  }

  void _setCategory(String cat) {
    setState(() => _activeCategory = cat);
    _applyFilter();
  }

  List<ProductModel> get _featured =>
      _all.where((p) => p.isFeatured).take(6).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.white;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const BackgroundOrbs(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppColors.blue600,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: AptigenAppBar(isDark: isDark),
                          ),
                          const SizedBox(width: 8),
                          _CartBadge(isDark: isDark),
                        ],
                      ),
                    ),
                  ),
                  // Hero headline
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MARKETPLACE',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3.5,
                              color: AppColors.blue600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  'Find your next\nfavorite thing',
                                  style: GoogleFonts.poppins(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    height: 1.15,
                                    color: isDark
                                        ? AppColors.white
                                        : AppColors.gray900,
                                  ),
                                ),
                              ),
                              if (!_loading && _error == null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.blue600
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_filtered.length} items',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.blue600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _SearchBar(
                            ctrl: _searchCtrl,
                            onChanged: (_) => _applyFilter(),
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),
                          _CategoryChips(
                            categories: _categories,
                            active: _activeCategory,
                            onSelect: _setCategory,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  // Promo banner
                  if (!_loading && _error == null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: _PromoBanner(),
                      ),
                    ),
                  // Featured section
                  if (!_loading && _error == null && _featured.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                        child: _SectionHeader(
                            title: 'Featured', isDark: isDark),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 230,
                        child: ListView.separated(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: _featured.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (_, i) => SizedBox(
                            width: 160,
                            child: ProductCard(
                              product: _featured[i],
                              isDark: isDark,
                              onTap: () => _openDetail(_featured[i]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  // All products header
                  if (!_loading && _error == null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                        child: _SectionHeader(
                          title: _activeCategory == 'All'
                              ? 'All Products'
                              : _activeCategory,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  // Content
                  if (_loading)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.blue600,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else if (_error != null)
                    SliverFillRemaining(
                      child: _ErrorState(error: _error!, onRetry: _load),
                    )
                  else if (_filtered.isEmpty)
                    const SliverFillRemaining(child: _EmptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.62,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => ProductCard(
                            product: _filtered[i],
                            isDark: isDark,
                            onTap: () => _openDetail(_filtered[i]),
                          ),
                          childCount: _filtered.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(ProductModel product) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            ProductDetailPage(product: product),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

// ─── Cart Badge ────────────────────────────────────────────────────────────

class _CartBadge extends StatelessWidget {
  final bool isDark;
  const _CartBadge({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: CartStore.instance,
      builder: (context, items, _) {
        final count = CartStore.instance.itemCount;
        return GestureDetector(
          onTap: () => _showCartSheet(context, isDark),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.slate900.withValues(alpha: 0.8)
                      : AppColors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AppColors.slate800.withValues(alpha: 0.5)
                        : AppColors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      color: AppColors.blue600,
                      size: 22,
                    ),
                    if (count > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppColors.rose500,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              count > 9 ? '9+' : '$count',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCartSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CartSheet(isDark: isDark),
    );
  }
}

// ─── Cart Sheet ────────────────────────────────────────────────────────────

class _CartSheet extends StatelessWidget {
  final bool isDark;
  const _CartSheet({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.slate900 : AppColors.white;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.3,
      expand: false,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate700 : AppColors.slate200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Cart',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                    ),
                    TextButton(
                      onPressed: () => CartStore.instance.clear(),
                      child: Text('Clear',
                          style: GoogleFonts.poppins(
                              color: AppColors.rose500,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ValueListenableBuilder<List<CartItem>>(
                  valueListenable: CartStore.instance,
                  builder: (_, items, __) {
                    if (items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shopping_bag_outlined,
                                size: 56, color: AppColors.slate300),
                            const SizedBox(height: 12),
                            Text('Cart is empty',
                                style: GoogleFonts.poppins(
                                    color: AppColors.slate500,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Divider(
                          color: isDark
                              ? AppColors.slate800
                              : AppColors.slate100),
                      itemBuilder: (_, i) =>
                          _CartTile(item: items[i], isDark: isDark),
                    );
                  },
                ),
              ),
              ValueListenableBuilder<List<CartItem>>(
                valueListenable: CartStore.instance,
                builder: (_, items, __) {
                  if (items.isEmpty) return const SizedBox.shrink();
                  final total = CartStore.instance.total;
                  return Container(
                    padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        MediaQuery.of(context).padding.bottom + 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? AppColors.slate800
                              : AppColors.slate100,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppColors.slate500,
                                )),
                            Text(
                              '\$${total.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.slate900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: AppGradients.primaryBtn,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {},
                                child: Center(
                                  child: Text(
                                    'Checkout',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CartTile extends StatelessWidget {
  final CartItem item;
  final bool isDark;
  const _CartTile({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : AppColors.slate100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.inventory_2_rounded,
              color: AppColors.blue600,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '\$${item.product.price.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.blue600),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _QtyBtn(
                icon: Icons.remove_rounded,
                onTap: () => CartStore.instance.decrement(item.product.id),
                isDark: isDark,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '${item.qty}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
              ),
              _QtyBtn(
                icon: Icons.add_rounded,
                onTap: () => CartStore.instance.add(item.product),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  const _QtyBtn(
      {required this.icon, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate700 : AppColors.slate100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14,
            color: isDark ? AppColors.slate300 : AppColors.slate700),
      ),
    );
  }
}

// ─── Search Bar ────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final ValueChanged<String> onChanged;
  final bool isDark;
  const _SearchBar(
      {required this.ctrl, required this.onChanged, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : AppColors.slate100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppColors.slate800 : AppColors.slate200),
      ),
      child: TextField(
        controller: ctrl,
        onChanged: onChanged,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: isDark ? AppColors.darkFg : AppColors.lightFg,
        ),
        decoration: InputDecoration(
          hintText: 'Search products, brands…',
          hintStyle: GoogleFonts.poppins(
              fontSize: 14,
              color: isDark ? AppColors.slate600 : AppColors.slate400),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 18, color: AppColors.slate400),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ─── Category Chips ────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final List<(String, String)> categories;
  final String active;
  final ValueChanged<String> onSelect;
  final bool isDark;
  const _CategoryChips({
    required this.categories,
    required this.active,
    required this.onSelect,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (label, emoji) = categories[i];
          final selected = label == active;
          return GestureDetector(
            onTap: () => onSelect(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: selected ? AppGradients.primaryBtn : null,
                color: selected
                    ? null
                    : (isDark ? AppColors.slate800 : AppColors.slate100),
                borderRadius: BorderRadius.circular(20),
                border: selected
                    ? null
                    : Border.all(
                        color: isDark
                            ? AppColors.slate700
                            : AppColors.slate200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : (isDark
                              ? AppColors.slate400
                              : AppColors.slate600),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Promo Banner ──────────────────────────────────────────────────────────

class _PromoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'LIMITED OFFER',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Up to 30% off\nselected items',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const Text('🎯', style: TextStyle(fontSize: 52)),
        ],
      ),
    );
  }
}

// ─── Section Header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.slate900,
          ),
        ),
        Text(
          'See all',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.blue600,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Error / Empty States ──────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: AppColors.slate500, size: 48),
            const SizedBox(height: 16),
            Text(error,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    color: AppColors.slate600, fontSize: 14)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppGradients.primaryBtn,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Retry',
                    style: GoogleFonts.poppins(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded,
              color: AppColors.slate300, size: 56),
          const SizedBox(height: 12),
          Text('No products found',
              style: GoogleFonts.poppins(
                  color: AppColors.slate500,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Try a different search or category',
              style: GoogleFonts.poppins(
                  color: AppColors.slate400, fontSize: 13)),
        ],
      ),
    );
  }
}
