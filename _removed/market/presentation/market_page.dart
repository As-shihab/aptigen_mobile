import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/http_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/media_url.dart';
import '../../../shared/aptigen_app_bar.dart';
import '../../../shared/skeleton.dart';
import '../data/cart_store.dart';
import '../data/market_service.dart';
import '../models/banner_model.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/vendor_model.dart';
import '../utils/market_icons.dart';
import 'product_detail_page.dart';
import 'store_profile_page.dart';
import 'widgets/product_card.dart';

const int _pageSize = 20;

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  final _service = MarketService(ApiClient());
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  bool _bootLoading = true;
  List<CategoryModel> _categories = [];
  List<BannerModel> _heroBanners = [];
  List<BannerModel> _promoCards = [];
  List<BannerModel> _stripBanners = [];
  List<VendorModel> _vendors = [];
  List<ProductModel> _pool = [];

  List<ProductModel> _browse = [];
  int _browseTotal = 0;
  bool _browseLoading = true;
  bool _browseLoadingMore = false;
  String? _browseError;
  String _activeFilter = 'All';
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadAll();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final nearBottom = _scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 400;
    if (!nearBottom) return;
    if (_browseLoadingMore || _browseLoading) return;
    if (_browse.length >= _browseTotal) return;
    _loadMoreBrowse();
  }

  int? get _activeCategoryId {
    if (_activeFilter == 'All') return null;
    final match = _categories.where((c) => c.name == _activeFilter);
    return match.isEmpty ? null : match.first.id;
  }

  Future<void> _loadAll() async {
    setState(() => _bootLoading = true);
    final results = await Future.wait<dynamic>([
      _service.getCategories().catchError((_) => <CategoryModel>[]),
      _service.getBanners('hero').catchError((_) => <BannerModel>[]),
      _service.getBanners('promo_card').catchError((_) => <BannerModel>[]),
      _service.getBanners('strip').catchError((_) => <BannerModel>[]),
      _service.getVendors(take: 12).catchError((_) => <VendorModel>[]),
      _service
          .getListings(take: 40)
          .then((p) => p.items)
          .catchError((_) => <ProductModel>[]),
    ]);
    if (!mounted) return;
    setState(() {
      _categories = results[0] as List<CategoryModel>;
      _heroBanners = results[1] as List<BannerModel>;
      _promoCards = results[2] as List<BannerModel>;
      _stripBanners = results[3] as List<BannerModel>;
      _vendors = results[4] as List<VendorModel>;
      _pool = results[5] as List<ProductModel>;
      _bootLoading = false;
    });
    await _loadBrowse(reset: true);
  }

  Future<void> _loadBrowse({bool reset = false}) async {
    setState(() {
      _browseLoading = true;
      _browseError = null;
      if (reset) _browse = [];
    });
    try {
      final page = await _service.getListings(
        skip: 0,
        take: _pageSize,
        search: _searchCtrl.text.trim(),
        categoryId: _activeCategoryId,
      );
      if (!mounted) return;
      setState(() {
        _browse = page.items;
        _browseTotal = page.total;
      });
    } catch (_) {
      if (mounted) {
        setState(
            () => _browseError = 'Failed to load products. Pull to retry.');
      }
    } finally {
      if (mounted) setState(() => _browseLoading = false);
    }
  }

  Future<void> _loadMoreBrowse() async {
    setState(() => _browseLoadingMore = true);
    try {
      final page = await _service.getListings(
        skip: _browse.length,
        take: _pageSize,
        search: _searchCtrl.text.trim(),
        categoryId: _activeCategoryId,
      );
      if (!mounted) return;
      setState(() {
        _browse = [..._browse, ...page.items];
        _browseTotal = page.total;
      });
    } catch (_) {
      // best-effort; the user can keep scrolling to retry
    } finally {
      if (mounted) setState(() => _browseLoadingMore = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(
        const Duration(milliseconds: 400), () => _loadBrowse(reset: true));
  }

  void _setFilter(String filter) {
    if (filter == _activeFilter) return;
    setState(() => _activeFilter = filter);
    _loadBrowse(reset: true);
  }

  Future<void> _refresh() async {
    await _loadAll();
  }

  List<ProductModel> get _onSaleListings {
    final list = _pool.where((p) => p.effectiveDiscount != null).toList()
      ..sort((a, b) => b.effectiveDiscount!.compareTo(a.effectiveDiscount!));
    return list;
  }

  List<ProductModel> get _featuredListings =>
      _pool.where((p) => p.isFeatured).take(6).toList();

  void _openDetail(ProductModel product, {String? heroTagPrefix}) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => ProductDetailPage(product: product, heroTagPrefix: heroTagPrefix),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.white;
    final filters = ['All', ..._categories.take(6).map((c) => c.name)];

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const BackgroundOrbs(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.blue600,
              child: CustomScrollView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: AptigenAppBar(
                              isDark: isDark,
                              onSearch: () =>
                                  setState(() => _searchOpen = !_searchOpen),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _CartBadge(isDark: isDark),
                        ],
                      ),
                    ),
                  ),
                  // Search — collapsed behind the header's search icon
                  if (_searchOpen)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _SearchBar(
                            ctrl: _searchCtrl,
                            onChanged: _onSearchChanged,
                            isDark: isDark,
                            autofocus: true),
                      ),
                    ),
                  // Categories — real market_categories, decorative browse aid
                  if (_bootLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 0, 0),
                        child: _CategorySkeletonRow(),
                      ),
                    )
                  else if (_categories.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 0, 0),
                        child: _CategoryIconRow(
                            categories: _categories, isDark: isDark),
                      ),
                    ),
                  // Hero banners — real market_banners (placement: hero)
                  if (_bootLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: Skeleton(
                            height: 190,
                            borderRadius: BorderRadius.circular(20)),
                      ),
                    )
                  else if (_heroBanners.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: _HeroBannerSlider(banners: _heroBanners),
                      ),
                    ),
                  // Promo cards — real market_banners (placement: promo_card)
                  if (_bootLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: _PromoSkeletonGrid(),
                      ),
                    )
                  else if (_promoCards.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: _PromoCardsGrid(cards: _promoCards),
                      ),
                    ),
                  // On Sale — real active listings with a compare_price discount
                  if (_bootLoading) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                        child: _SectionHeaderSkeleton(),
                      ),
                    ),
                    SliverToBoxAdapter(child: _ProductRowSkeleton()),
                  ] else if (_onSaleListings.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                        child: _SectionHeader(
                            title: 'On Sale Now', isDark: isDark),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 230,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: _onSaleListings.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (_, i) => SizedBox(
                            width: 160,
                            child: ProductCard(
                              product: _onSaleListings[i],
                              isDark: isDark,
                              heroTagPrefix: 'onsale-',
                              onTap: () => _openDetail(_onSaleListings[i], heroTagPrefix: 'onsale-'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  // Featured — real market_listings.is_featured picks
                  if (!_bootLoading && _featuredListings.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                        child:
                            _SectionHeader(title: 'Featured', isDark: isDark),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 230,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: _featuredListings.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (_, i) => SizedBox(
                            width: 160,
                            child: ProductCard(
                              product: _featuredListings[i],
                              isDark: isDark,
                              heroTagPrefix: 'featured-',
                              onTap: () => _openDetail(_featuredListings[i], heroTagPrefix: 'featured-'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  // Banner strip — real market_banners (placement: strip)
                  if (_bootLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                        child: _BannerStripSkeleton(),
                      ),
                    )
                  else if (_stripBanners.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                        child: _BannerStrip(banners: _stripBanners),
                      ),
                    ),
                  // Vendors — real stores, ranked by active listing count
                  if (_bootLoading) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                        child: _SectionHeaderSkeleton(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _VendorSkeletonRow(),
                      ),
                    ),
                  ] else if (_vendors.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                        child: _SectionHeader(
                            title: 'Top Vendors',
                            isDark: isDark,
                            showSeeAll: false),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _VendorsRow(vendors: _vendors, isDark: isDark),
                    ),
                  ],
                  // Recommended — real active listings, filterable + searchable
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _searchCtrl.text.trim().isNotEmpty
                                ? 'Search results'
                                : 'Recommended for you',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.slate900,
                            ),
                          ),
                          if (filters.length > 1) ...[
                            const SizedBox(height: 12),
                            _FilterChips(
                                filters: filters,
                                active: _activeFilter,
                                onSelect: _setFilter,
                                isDark: isDark),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_browseLoading)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      sliver: _ProductGridSkeleton(count: 6),
                    )
                  else if (_browseError != null)
                    SliverToBoxAdapter(
                      child: _ErrorState(
                          error: _browseError!,
                          onRetry: () => _loadBrowse(reset: true)),
                    )
                  else if (_browse.isEmpty)
                    const SliverToBoxAdapter(child: _EmptyState())
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                            product: _browse[i],
                            isDark: isDark,
                            heroTagPrefix: 'browse-',
                            onTap: () => _openDetail(_browse[i], heroTagPrefix: 'browse-'),
                          ),
                          childCount: _browse.length,
                        ),
                      ),
                    ),
                    if (_browseLoadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: AppColors.blue600, strokeWidth: 2),
                            ),
                          ),
                        ),
                      ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Category Icon Row ─────────────────────────────────────────────────────

class _CategoryIconRow extends StatelessWidget {
  final List<CategoryModel> categories;
  final bool isDark;
  const _CategoryIconRow({required this.categories, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        padding: const EdgeInsets.only(right: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final tint = marketCategoryTint(i);
          return SizedBox(
            width: 64,
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(resolveMarketCategoryIcon(cat.icon),
                      color: tint, size: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  cat.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.slate800,
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

// ─── Hero Banner Slider ─────────────────────────────────────────────────────

class _HeroBannerSlider extends StatefulWidget {
  final List<BannerModel> banners;
  const _HeroBannerSlider({required this.banners});

  @override
  State<_HeroBannerSlider> createState() => _HeroBannerSliderState();
}

class _HeroBannerSliderState extends State<_HeroBannerSlider> {
  final _pageCtrl = PageController();
  Timer? _timer;
  int _page = 0;

  static const _tints = [
    Color(0xFFEAF3FC),
    Color(0xFFFFF1F2),
    Color(0xFFFFFBEB),
    Color(0xFFF7FEE7),
    Color(0xFFF0F9FF),
    Color(0xFFF5F3FF),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_pageCtrl.hasClients) return;
        final next = (_page + 1) % widget.banners.length;
        _pageCtrl.animateToPage(next,
            duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    return SizedBox(
      height: 190,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: banners.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final b = banners[i];
                final imageUrl = MediaUrl.resolve(b.imageUrl, view: 'large');
                return Container(
                  color: _tints[i % _tints.length],
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl != null)
                        Image.network(imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox()),
                      if (imageUrl != null)
                        Container(color: Colors.black.withValues(alpha: 0.32)),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (b.subtitle != null)
                              Text(
                                b.subtitle!,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: imageUrl != null
                                      ? Colors.white70
                                      : AppColors.blue600,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              b.title,
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                color: imageUrl != null
                                    ? Colors.white
                                    : AppColors.gray900,
                              ),
                            ),
                            if (b.ctaLabel != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 9),
                                decoration: BoxDecoration(
                                  color: AppColors.blue600,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  b.ctaLabel!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (banners.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(banners.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Promo Cards Grid ───────────────────────────────────────────────────────

class _PromoCardsGrid extends StatelessWidget {
  final List<BannerModel> cards;
  const _PromoCardsGrid({required this.cards});

  static const _toneColors = {
    'blue': Color(0xFFEAF3FC),
    'rose': Color(0xFFFFF1F2),
    'amber': Color(0xFFFFFBEB),
    'lime': Color(0xFFF7FEE7),
    'sky': Color(0xFFF0F9FF),
    'violet': Color(0xFFF5F3FF),
  };
  static const _toneAccent = {
    'blue': Color(0xFF0A6ED1),
    'rose': Color(0xFFF43F5E),
    'amber': Color(0xFFD97706),
    'lime': Color(0xFF65A30D),
    'sky': Color(0xFF0284C7),
    'violet': Color(0xFF7C3AED),
  };

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (_, i) {
        final card = cards[i];
        final bg = _toneColors[card.tone] ?? _toneColors['blue']!;
        final accent = _toneAccent[card.tone] ?? _toneAccent['blue']!;
        final imageUrl = MediaUrl.resolve(card.imageUrl, view: 'small');
        return Container(
          padding: const EdgeInsets.all(14),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: imageUrl == null ? bg : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              if (imageUrl != null)
                Positioned.fill(
                  child: Image.network(imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: bg)),
                ),
              if (imageUrl != null)
                Positioned.fill(
                    child:
                        Container(color: Colors.black.withValues(alpha: 0.32))),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    card.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color:
                          imageUrl != null ? Colors.white : AppColors.gray900,
                    ),
                  ),
                  if (card.ctaLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: imageUrl != null ? AppColors.blue600 : accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        card.ctaLabel!,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Banner Strip ───────────────────────────────────────────────────────────

class _BannerStrip extends StatelessWidget {
  final List<BannerModel> banners;
  const _BannerStrip({required this.banners});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: banners
          .map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  height: 100,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.blue600,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      if (b.imageUrl != null)
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.4,
                            child: Image.network(
                              MediaUrl.resolve(b.imageUrl, view: 'large') ?? '',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              b.title,
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            if (b.subtitle != null)
                              Text(
                                b.subtitle!,
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: Colors.white70),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ─── Vendors Row ────────────────────────────────────────────────────────────

class _VendorsRow extends StatelessWidget {
  final List<VendorModel> vendors;
  final bool isDark;
  const _VendorsRow({required this.vendors, required this.isDark});

  static const _tints = [
    Color(0xFF0A6ED1),
    Color(0xFFD97706),
    Color(0xFF0284C7),
    Color(0xFFF43F5E),
    Color(0xFF16A34A),
    Color(0xFFEA580C),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: vendors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final v = vendors[i];
          final avatarUrl = MediaUrl.resolve(v.avatarUrl, view: 'small');
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => StoreProfilePage(storeId: v.storeId)),
            ),
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isDark ? AppColors.slate700 : AppColors.slate100),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3))
                      ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                        color: _tints[i % _tints.length],
                        shape: BoxShape.circle),
                    child: avatarUrl != null
                        ? Image.network(avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                      v.storeName.substring(0, 1).toUpperCase(),
                                      style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800)),
                                ))
                        : Center(
                            child: Text(
                                v.storeName.substring(0, 1).toUpperCase(),
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800)),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                v.storeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.slate900,
                                ),
                              ),
                            ),
                            if (v.isVerified) ...[
                              const SizedBox(width: 3),
                              const Icon(Icons.verified_rounded,
                                  size: 12, color: AppColors.blue600),
                            ],
                          ],
                        ),
                        Text(
                          v.tagline ?? '${v.listingCount} listings',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.slate500),
                        ),
                      ],
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

// ─── Skeletons ───────────────────────────────────────────────────────────

class _SectionHeaderSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Skeleton(width: 120, height: 16),
        Skeleton(width: 48, height: 14),
      ],
    );
  }
}

class _CategorySkeletonRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        padding: const EdgeInsets.only(right: 16),
        scrollDirection: Axis.horizontal,
        itemCount: 8,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, __) => SizedBox(
          width: 64,
          child: Column(
            children: [
              const Skeleton(width: 56, height: 56, circle: true),
              const SizedBox(height: 8),
              Skeleton(width: 40, height: 9),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoSkeletonGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (_, __) => Skeleton(borderRadius: BorderRadius.circular(16)),
    );
  }
}

class _ProductRowSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => SizedBox(
          width: 160,
          child: _ProductCardSkeleton(),
        ),
      ),
    );
  }
}

class _ProductCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
            flex: 5, child: Skeleton(borderRadius: BorderRadius.circular(20))),
        const SizedBox(height: 8),
        Skeleton(height: 12, width: 90),
        const SizedBox(height: 6),
        Skeleton(height: 10, width: 60),
      ],
    );
  }
}

class _ProductGridSkeleton extends StatelessWidget {
  final int count;
  const _ProductGridSkeleton({this.count = 6});

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      delegate: SliverChildBuilderDelegate(
        (_, __) => _ProductCardSkeleton(),
        childCount: count,
      ),
    );
  }
}

class _BannerStripSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Skeleton(height: 100, borderRadius: BorderRadius.circular(16)),
        const SizedBox(height: 12),
        Skeleton(height: 100, borderRadius: BorderRadius.circular(16)),
      ],
    );
  }
}

class _VendorSkeletonRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Container(
          width: 220,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Skeleton(width: 48, height: 48, circle: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 12, width: 100),
                    const SizedBox(height: 6),
                    Skeleton(height: 10, width: 70),
                  ],
                ),
              ),
            ],
          ),
        ),
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                          color:
                              isDark ? AppColors.slate800 : AppColors.slate100),
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
                        20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color:
                              isDark ? AppColors.slate800 : AppColors.slate100,
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
                                color:
                                    isDark ? Colors.white : AppColors.slate900,
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
        child: Icon(icon,
            size: 14, color: isDark ? AppColors.slate300 : AppColors.slate700),
      ),
    );
  }
}

// ─── Search Bar ────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final ValueChanged<String> onChanged;
  final bool isDark;
  final bool autofocus;
  const _SearchBar(
      {required this.ctrl,
      required this.onChanged,
      required this.isDark,
      this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : AppColors.slate100,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
      ),
      child: TextField(
        controller: ctrl,
        autofocus: autofocus,
        onChanged: onChanged,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: isDark ? AppColors.darkFg : AppColors.lightFg,
        ),
        decoration: InputDecoration(
          hintText: 'Search products, sellers…',
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

// ─── Filter Chips ───────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final List<String> filters;
  final String active;
  final ValueChanged<String> onSelect;
  final bool isDark;
  const _FilterChips({
    required this.filters,
    required this.active,
    required this.onSelect,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final label = filters[i];
          final selected = label == active;
          return GestureDetector(
            onTap: () => onSelect(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: selected ? AppGradients.primaryBtn : null,
                color: selected
                    ? null
                    : (isDark ? AppColors.slate800 : AppColors.slate100),
                borderRadius: BorderRadius.circular(20),
                border: selected
                    ? null
                    : Border.all(
                        color:
                            isDark ? AppColors.slate700 : AppColors.slate200),
              ),
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : (isDark ? AppColors.slate400 : AppColors.slate600),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Section Header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  final bool showSeeAll;
  const _SectionHeader(
      {required this.title, required this.isDark, this.showSeeAll = true});

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
        if (showSeeAll)
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppGradients.primaryBtn,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Retry',
                    style: GoogleFonts.poppins(
                        color: AppColors.white, fontWeight: FontWeight.w600)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                color: AppColors.slate300, size: 56),
            const SizedBox(height: 12),
            Text('No listings yet',
                style: GoogleFonts.poppins(
                    color: AppColors.slate500,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('Check back soon, or try a different search',
                style: GoogleFonts.poppins(
                    color: AppColors.slate400, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
