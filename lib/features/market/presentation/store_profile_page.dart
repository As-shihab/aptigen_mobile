import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/http_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/market_service.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';
import '../presentation/widgets/product_card.dart';
import 'product_detail_page.dart';

class StoreProfilePage extends StatefulWidget {
  final StoreModel store;
  const StoreProfilePage({super.key, required this.store});

  @override
  State<StoreProfilePage> createState() => _StoreProfilePageState();
}

class _StoreProfilePageState extends State<StoreProfilePage>
    with TickerProviderStateMixin {
  final _service = MarketService(ApiClient());
  List<ProductModel> _products = [];
  bool _loading = true;
  bool _following = false;
  int _followerCount = 0;

  late final AnimationController _followCtrl;
  late final Animation<double> _followScale;

  @override
  void initState() {
    super.initState();
    _followerCount = widget.store.followerCount;
    _followCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _followScale = Tween<double>(begin: 1, end: 0.92).animate(
      CurvedAnimation(parent: _followCtrl, curve: Curves.easeInOut),
    );
    _loadProducts();
  }

  @override
  void dispose() {
    _followCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _service.getProductsBySeller(widget.store.id);
      if (mounted) setState(() { _products = products; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleFollow() async {
    await _followCtrl.forward();
    await _followCtrl.reverse();
    setState(() {
      _following = !_following;
      _followerCount += _following ? 1 : -1;
    });
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final store = widget.store;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.slate50,
      body: CustomScrollView(
        slivers: [
          // ── Header ─────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: isDark ? AppColors.slate900 : Colors.white,
            surfaceTintColor: Colors.transparent,
            leading: _CircleBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              isDark: isDark,
              onTap: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _StoreHeader(
                store: store,
                followerCount: _followerCount,
                following: _following,
                onFollow: _toggleFollow,
                followScale: _followScale,
                isDark: isDark,
              ),
            ),
          ),

          // ── Stats bar ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: isDark ? AppColors.slate900 : Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  _StatItem(
                    value: '${_products.isEmpty ? store.productCount : _products.length}',
                    label: 'Products',
                    isDark: isDark,
                  ),
                  _Divider(isDark: isDark),
                  _StatItem(
                    value: store.rating.toStringAsFixed(1),
                    label: 'Rating',
                    isDark: isDark,
                    icon: Icons.star_rounded,
                    iconColor: AppColors.amber400,
                  ),
                  _Divider(isDark: isDark),
                  _StatItem(
                    value: _formatCount(_followerCount),
                    label: 'Followers',
                    isDark: isDark,
                  ),
                  _Divider(isDark: isDark),
                  _StatItem(
                    value: 'Since ${store.joinedYear}',
                    label: 'Member',
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ── Section title ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Text(
                    'Products',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.slate900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.blue600.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_products.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blue600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Products grid ──────────────────────────────────────────────
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                    color: AppColors.blue600, strokeWidth: 2),
              ),
            )
          else if (_products.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        color: AppColors.slate300, size: 52),
                    const SizedBox(height: 12),
                    Text(
                      'No products yet',
                      style: GoogleFonts.poppins(
                          color: AppColors.slate500, fontSize: 15),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => ProductCard(
                    product: _products[i],
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProductDetailPage(product: _products[i]),
                      ),
                    ),
                  ),
                  childCount: _products.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Store Header ────────────────────────────────────────────────────────────

class _StoreHeader extends StatelessWidget {
  final StoreModel store;
  final int followerCount;
  final bool following;
  final VoidCallback onFollow;
  final Animation<double> followScale;
  final bool isDark;

  const _StoreHeader({
    required this.store,
    required this.followerCount,
    required this.following,
    required this.onFollow,
    required this.followScale,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            store.gradient.first,
            store.gradient.last,
            store.gradient.last.withValues(alpha: 0.85),
          ],
          stops: const [0, 0.6, 1],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Avatar
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 2.5),
                    ),
                    child: Center(
                      child: Text(
                        store.initials,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              store.name,
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified_rounded,
                                      color: Colors.white, size: 11),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Verified',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (store.description != null)
                          Text(
                            store.description!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Follow button
                  ScaleTransition(
                    scale: followScale,
                    child: GestureDetector(
                      onTap: onFollow,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: following
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          following ? 'Following' : 'Follow',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: following
                                ? Colors.white
                                : store.gradient.first,
                          ),
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
    );
  }
}

// ─── Stat Item ───────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final bool isDark;
  final IconData? icon;
  final Color? iconColor;

  const _StatItem({
    required this.value,
    required this.label,
    required this.isDark,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 3),
              ],
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.slate900,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: isDark ? AppColors.slate700 : AppColors.slate200,
    );
  }
}

// ─── Circle Button ───────────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _CircleBtn(
      {required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.slate800.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon,
            size: 16,
            color: isDark ? AppColors.slate300 : AppColors.slate700),
      ),
    );
  }
}
