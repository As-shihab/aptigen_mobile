import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/http_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/media_url.dart';
import '../../../shared/skeleton.dart';
import '../data/market_service.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';
import '../presentation/widgets/product_card.dart';
import 'product_detail_page.dart';

class StoreProfilePage extends StatefulWidget {
  final int storeId;
  const StoreProfilePage({super.key, required this.storeId});

  @override
  State<StoreProfilePage> createState() => _StoreProfilePageState();
}

class _StoreProfilePageState extends State<StoreProfilePage>
    with TickerProviderStateMixin {
  final _service = MarketService(ApiClient());
  StorePageData? _data;
  bool _loading = true;
  bool _following = false;
  int _followerCount = 0;

  late final AnimationController _followCtrl;
  late final Animation<double> _followScale;

  @override
  void initState() {
    super.initState();
    _followCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _followScale = Tween<double>(begin: 1, end: 0.92).animate(
      CurvedAnimation(parent: _followCtrl, curve: Curves.easeInOut),
    );
    _load();
  }

  @override
  void dispose() {
    _followCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getStore(widget.storeId);
      if (!mounted) return;
      setState(() {
        // The store endpoint's listings don't carry an embedded
        // store_profile (unlike /listings and /listing/:id) — we already
        // know the seller here, so stamp it on before it's handed to
        // ProductDetailPage (otherwise "Sold by" would fall back to
        // "Aptigen Marketplace" when opened from this screen).
        _data = data == null
            ? null
            : StorePageData(
                store: data.store,
                followerCount: data.followerCount,
                listings: data.listings
                    .map((p) => ProductModel(
                          id: p.id,
                          name: p.name,
                          description: p.description,
                          price: p.price,
                          originalPrice: p.originalPrice,
                          category: p.category,
                          categoryId: p.categoryId,
                          images: p.images,
                          quantity: p.quantity,
                          minOrder: p.minOrder,
                          maxOrder: p.maxOrder,
                          condition: p.condition,
                          listingType: p.listingType,
                          tags: p.tags,
                          city: p.city,
                          country: p.country,
                          isFeatured: p.isFeatured,
                          currency: p.currency,
                          sellerId: data.store.id,
                          sellerName: data.store.storeName,
                          sellerLogoUrl: data.store.logoUrl,
                          sellerAccentColor: data.store.accentColor,
                          sellerVerified: data.store.isVerified,
                          sellerPhone: data.store.phone,
                        ))
                    .toList(),
              );
        _followerCount = data?.followerCount ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Follow is optimistic/client-only — the public store endpoint has no
  // follow mutation, same as frontend/.../store/store.client.tsx's toggleFollow.
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

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.slate50,
        body: const _StoreSkeleton(),
      );
    }

    final data = _data;
    if (data == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.slate50,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _CircleBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            isDark: isDark,
            onTap: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_outlined,
                  color: AppColors.slate300, size: 56),
              const SizedBox(height: 12),
              Text('Store not found',
                  style: GoogleFonts.poppins(
                      color: AppColors.slate500,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('This store may be inactive or no longer exists.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: AppColors.slate400, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final store = data.store;
    final products = data.listings;

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
                    value: '${products.length}',
                    label: 'Products',
                    isDark: isDark,
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
                  if (store.isVerified) ...[
                    _Divider(isDark: isDark),
                    _StatItem(
                      value: 'Verified',
                      label: 'Seller',
                      isDark: isDark,
                      icon: Icons.verified_rounded,
                      iconColor: AppColors.blue600,
                    ),
                  ],
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.blue600.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${products.length}',
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
          if (products.isEmpty)
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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => ProductCard(
                    product: products[i],
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailPage(product: products[i]),
                      ),
                    ),
                  ),
                  childCount: products.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Store Header ────────────────────────────────────────────────────────────

// ─── Store Skeleton ──────────────────────────────────────────────────────

class _StoreSkeleton extends StatelessWidget {
  const _StoreSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Skeleton(height: 240),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Column(
                    children: [
                      Skeleton(height: 15, width: 40),
                      const SizedBox(height: 6),
                      Skeleton(height: 10, width: 50),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Skeleton(height: 17, width: 100),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (_, __) =>
                  Skeleton(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final logoUrl = MediaUrl.resolve(store.logoUrl, view: 'small');
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
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 2.5),
                    ),
                    child: logoUrl != null
                        ? Image.network(logoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    store.initials,
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ))
                        : Center(
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
                            Expanded(
                              child: Text(
                                store.storeName,
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (store.isVerified) ...[
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
                          ],
                        ),
                        if ((store.tagline ?? store.description) != null)
                          Text(
                            store.tagline ?? store.description!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (store.city != null || store.country != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              [store.city, store.country]
                                  .where((e) => e != null && e.isNotEmpty)
                                  .join(', '),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
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
                            color:
                                following ? Colors.white : store.gradient.first,
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
            size: 16, color: isDark ? AppColors.slate300 : AppColors.slate700),
      ),
    );
  }
}
