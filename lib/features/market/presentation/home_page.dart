import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../../shared/skeleton.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/models/user_model.dart';
import '../data/local_lists.dart';
import '../data/market_service.dart';
import '../models/banner_model.dart';
import '../models/category_model.dart';
import '../models/market_extras.dart';
import '../models/product_model.dart';
import '../models/vendor_model.dart';
import 'compare_page.dart';
import 'market_nav.dart';
import 'widgets/category_icons.dart';
import 'widgets/common.dart';
import 'widgets/countdown.dart';
import 'widgets/flash_sale_card.dart';
import 'widgets/product_tile.dart';

const _pageSize = 12;

/// Market home — port of MarketClient.tsx: hero banners, categories, promo
/// cards, on-sale, featured, banner strip, top vendors and an infinite
/// "recommended" grid filterable by category.
class HomePage extends StatefulWidget {
  final VoidCallback onBrowseCategories;
  final VoidCallback onSearch;
  final VoidCallback onAccount;
  const HomePage({
    super.key,
    required this.onBrowseCategories,
    required this.onSearch,
    required this.onAccount,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _api = MarketService();
  final _scroll = ScrollController();

  // Each section loads on its own so a slow endpoint doesn't hold the rest.
  List<CategoryModel>? _categories;
  List<BannerModel>? _hero;
  List<BannerModel>? _promos;
  List<BannerModel>? _strips;
  List<VendorModel>? _vendors;
  List<ProductModel>? _pool;
  List<FlashSale>? _flashSales;
  List<ProductModel> _recent = const [];
  String _recentKey = '';

  int? _filterCategory;
  final List<ProductModel> _browse = [];
  int _browseTotal = 0;
  bool _browseLoading = false;
  bool _browseError = false;
  int _browseToken = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    RecentlyViewedStore.instance.addListener(_loadRecent);
    RecentlyViewedStore.instance.init().then((_) => _loadRecent());
    _loadAll();
  }

  @override
  void dispose() {
    RecentlyViewedStore.instance.removeListener(_loadRecent);
    _scroll.dispose();
    super.dispose();
  }

  /// Listings the shopper opened on this device, most recent first.
  Future<void> _loadRecent({bool force = false}) async {
    final ids = RecentlyViewedStore.instance.value;
    final key = ids.join(',');
    if (!force && key == _recentKey) return;
    _recentKey = key;
    if (ids.isEmpty) {
      _set(() => _recent = const []);
      return;
    }
    try {
      final page = await _api.getListings(ids: ids, take: ids.length);
      if (key != _recentKey) return;
      final byId = {for (final it in page.items) it.id: it};
      _set(() => _recent = ids.map((id) => byId[id]).whereType<ProductModel>().toList());
    } catch (_) {
      // Keep whatever was shown; the row is a nicety.
    }
  }

  Future<void> _loadAll() async {
    Future<T> safe<T>(Future<T> f, T fallback) => f.catchError((_) => fallback);
    await Future.wait([
      safe(_api.getCategories(), <CategoryModel>[]).then((v) => _set(() => _categories = v)),
      safe(_api.getBanners('hero'), <BannerModel>[]).then((v) => _set(() => _hero = v)),
      safe(_api.getBanners('promo_card'), <BannerModel>[]).then((v) => _set(() => _promos = v)),
      safe(_api.getBanners('strip'), <BannerModel>[]).then((v) => _set(() => _strips = v)),
      safe(_api.getVendors(take: 12), <VendorModel>[]).then((v) => _set(() => _vendors = v)),
      safe(_api.getListings(take: 40).then((r) => r.items), <ProductModel>[]).then((v) => _set(() => _pool = v)),
      safe(_api.getFlashSales(), <FlashSale>[]).then((v) => _set(() => _flashSales = v)),
      _loadRecent(force: true),
      _loadBrowse(reset: true),
    ]);
  }

  void _set(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> _loadBrowse({bool reset = false}) async {
    if (_browseLoading && !reset) return;
    if (!reset && _browse.length >= _browseTotal && _browseTotal > 0) return;
    final token = ++_browseToken;
    _set(() {
      _browseLoading = true;
      _browseError = false;
      if (reset) {
        _browse.clear();
        _browseTotal = 0;
      }
    });
    try {
      final page = await _api.getListings(skip: _browse.length, take: _pageSize, categoryId: _filterCategory);
      if (token != _browseToken) return;
      _set(() {
        _browse.addAll(page.items);
        _browseTotal = page.items.isEmpty ? _browse.length : page.total;
      });
    } catch (_) {
      if (token == _browseToken) _set(() => _browseError = true);
    } finally {
      if (token == _browseToken) _set(() => _browseLoading = false);
    }
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 600 && !_browseLoading && !_browseError && _browse.length < _browseTotal) {
      _loadBrowse();
    }
  }

  void _setFilter(int? id) {
    if (_filterCategory == id) return;
    _filterCategory = id;
    _loadBrowse(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final pool = _pool ?? const <ProductModel>[];
    final onSale = pool.where((l) => l.onSale).toList()..sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
    final featured = pool.where((l) => l.isFeatured).take(8).toList();

    return Scaffold(
      floatingActionButton: const CompareFab(),
      body: RefreshIndicator(
        color: p.accent,
        onRefresh: _loadAll,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _TopBar(onSearch: widget.onSearch, onAccount: widget.onAccount),

            // Hero
            SliverToBoxAdapter(
              child: _hero == null
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Skeleton(height: 280, borderRadius: BorderRadius.circular(18)),
                    )
                  : _hero!.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(padding: const EdgeInsets.only(top: 8), child: _HeroCarousel(_hero!)),
            ),

            // Flash sale — only while a sale is live
            if (_flashSales != null && _flashSales!.isNotEmpty)
              SliverToBoxAdapter(child: _FlashSaleStrip(_flashSales!)),

            // Categories
            if (_categories == null)
              const SliverToBoxAdapter(child: _CategorySkeleton())
            else if (_categories!.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader('Shop by category', actionLabel: 'See all', onAction: widget.onBrowseCategories),
                      _CategoryRow(_categories!),
                    ],
                  ),
                ),
              ),

            // Promo cards
            if (_promos != null && _promos!.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 112,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _PromoCard(_promos![i], i),
                    childCount: _promos!.length,
                  ),
                ),
              ),

            // On sale
            if (_pool == null)
              const SliverToBoxAdapter(child: _RowSkeleton())
            else if (onSale.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader('On sale now'),
                      _FlashDeals(onSale.take(2).toList()),
                      if (onSale.length > 2) ...[
                        const SizedBox(height: 16),
                        ProductRow(onSale.skip(2).take(8).toList()),
                      ],
                    ],
                  ),
                ),
              ),

            // Featured
            if (featured.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [const SectionHeader('Featured listings'), ProductRow(featured)],
                  ),
                ),
              ),

            // Banner strip
            if (_strips != null && _strips!.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                sliver: SliverList.separated(
                  itemCount: _strips!.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _StripBanner(_strips![i]),
                ),
              ),

            // Vendors
            if (_vendors != null && _vendors!.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [const SectionHeader('Shop by top vendors'), _VendorRow(_vendors!)],
                  ),
                ),
              ),

            // Recently viewed — this device's history only
            if (_recent.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        'Recently viewed',
                        actionLabel: 'Clear',
                        onAction: RecentlyViewedStore.instance.clear,
                      ),
                      ProductRow(_recent),
                    ],
                  ),
                ),
              ),

            // Recommended
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader('Recommended for you'),
                    if ((_categories ?? []).isNotEmpty)
                      _FilterChips(
                        categories: _categories!.take(8).toList(),
                        selected: _filterCategory,
                        onSelect: _setFilter,
                      ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            if (_browse.isEmpty && _browseLoading)
              const ProductGridSkeleton()
            else if (_browse.isEmpty && _browseError)
              SliverToBoxAdapter(child: ErrorState(onRetry: () => _loadBrowse(reset: true)))
            else if (_browse.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No listings yet',
                  message: 'Check back soon — new products land here every day.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: productGridDelegate(context),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => ProductTile(_browse[i]),
                    childCount: _browse.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 96,
                child: _browse.isNotEmpty && _browseLoading
                    ? Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: p.accent),
                        ),
                      )
                    : _browse.isNotEmpty && _browseError
                        ? Center(child: TextButton(onPressed: _loadBrowse, child: const Text('Load more')))
                        : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onAccount;
  const _TopBar({required this.onSearch, required this.onAccount});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 58,
      titleSpacing: 16,
      title: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 30, height: 30),
          const SizedBox(width: 8),
          Text('Aptigen', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.text)),
          const Spacer(),
          ValueListenableBuilder<UserModel?>(
            valueListenable: Session.user,
            builder: (_, user, __) => GestureDetector(
              onTap: onAccount,
              child: user == null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(8)),
                      child: const Text('Sign in',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    )
                  : CircleAvatar(
                      radius: 18,
                      backgroundColor: p.accentSoft,
                      child: Text(user.initials,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.accent)),
                    ),
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(58),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: GestureDetector(
            onTap: onSearch,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Expanded(
                    child:
                        Text('Search for a product or brand', style: TextStyle(fontSize: 14, color: p.textSecondary)),
                  ),
                  Icon(Icons.search_rounded, size: 21, color: p.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero carousel ─────────────────────────────────────────────────────────

class _HeroCarousel extends StatefulWidget {
  final List<BannerModel> slides;
  const _HeroCarousel(this.slides);

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

/// Full-width hero like HeroSlider.tsx: one slide at a time, swipeable,
/// auto-advancing every 5 s, dots overlaid at the bottom.
class _HeroCarouselState extends State<_HeroCarousel> {
  final _ctrl = PageController();
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    if (widget.slides.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_ctrl.hasClients) return;
      _ctrl.animateToPage((_index + 1) % widget.slides.length,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 0.78).clamp(260.0, 380.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              NotificationListener<ScrollStartNotification>(
                onNotification: (n) {
                  if (n.dragDetails != null) _restart();
                  return false;
                },
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: widget.slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _HeroSlide(widget.slides[i], tone: p.tone(i)),
                ),
              ),
              if (widget.slides.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _index ? AppColors.accent : const Color(0x9994A3B8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSlide extends StatelessWidget {
  final BannerModel s;
  final Tone tone;
  const _HeroSlide(this.s, {required this.tone});

  @override
  Widget build(BuildContext context) {
    final hasImage = s.imageUrl != null && s.imageUrl!.isNotEmpty;
    final fg = hasImage ? Colors.white : const Color(0xFF111827);
    return GestureDetector(
      onTap: () => openMarketLink(context, s.linkUrl),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage) ...[
            NetImage(s.imageUrl, view: 'large'),
            Container(color: Colors.black.withValues(alpha: 0.4)),
          ] else
            Container(color: tone.bg),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (s.subtitle != null && s.subtitle!.isNotEmpty) ...[
                  Text(
                    s.subtitle!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: hasImage ? Colors.white.withValues(alpha: 0.9) : AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  s.title,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 26, height: 1.2, fontWeight: FontWeight.w600, color: fg),
                ),
                if (s.ctaLabel != null && s.ctaLabel!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s.ctaLabel!,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white)),
                        const SizedBox(width: 8),
                        const Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.white),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Categories ────────────────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  final List<CategoryModel> categories;
  const _CategoryRow(this.categories);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (_, i) {
          final c = categories[i];
          final tone = p.tone(i);
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => openSearch(context, categoryId: c.id, categoryName: c.name),
            child: SizedBox(
              width: 84,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
                      child: Icon(categoryIcon(c.icon), color: tone.fg, size: 27),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, height: 1.2, fontWeight: FontWeight.w500, color: p.text),
                    ),
                    if (c.count > 0)
                      Text('${c.count} products', style: TextStyle(fontSize: 10.5, height: 1.4, color: p.textTertiary)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final List<CategoryModel> categories;
  final int? selected;
  final ValueChanged<int?> onSelect;
  const _FilterChips({required this.categories, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget chip(String label, int? id, int index) {
      final active = selected == id;
      final tone = p.tone(index);
      return GestureDetector(
        onTap: () => onSelect(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? p.accent : tone.bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: active ? Colors.white : tone.fg),
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip('All', null, 0),
          for (var i = 0; i < categories.length; i++) ...[
            const SizedBox(width: 8),
            chip(categories[i].name, categories[i].id, i + 1),
          ],
        ],
      ),
    );
  }
}

// ── Banners ───────────────────────────────────────────────────────────────

class _PromoCard extends StatelessWidget {
  final BannerModel banner;
  final int index;
  const _PromoCard(this.banner, this.index);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final tones = {'blue': 0, 'rose': 1, 'amber': 2, 'lime': 7, 'sky': 5, 'violet': 4};
    final tone = p.tone(tones[banner.tone] ?? index);
    final hasImage = banner.imageUrl != null && banner.imageUrl!.isNotEmpty;
    return GestureDetector(
      onTap: () => openMarketLink(context, banner.linkUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage) ...[
              NetImage(banner.imageUrl),
              Container(color: Colors.black.withValues(alpha: 0.32)),
            ] else ...[
              Container(color: tone.bg),
              Positioned(
                right: -10,
                bottom: -10,
                child: Icon(Icons.shopping_bag_outlined, size: 72, color: tone.fg.withValues(alpha: 0.22)),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banner.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: hasImage ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  if (banner.ctaLabel != null && banner.ctaLabel!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: hasImage ? AppColors.accent : tone.fg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            banner.ctaLabel!,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StripBanner extends StatelessWidget {
  final BannerModel banner;
  const _StripBanner(this.banner);

  @override
  Widget build(BuildContext context) {
    final hasImage = banner.imageUrl != null && banner.imageUrl!.isNotEmpty;
    return GestureDetector(
      onTap: () => openMarketLink(context, banner.linkUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          color: AppColors.accent,
          height: 116,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage) Opacity(opacity: 0.4, child: NetImage(banner.imageUrl, view: 'large')),
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Icon(Icons.shopping_bag_outlined, size: 68, color: Colors.white.withValues(alpha: 0.25)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 96, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      banner.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    if (banner.subtitle != null && banner.subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          banner.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFDBEAFE)),
                        ),
                      ),
                    if (banner.ctaLabel != null && banner.ctaLabel!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          banner.ctaLabel!,
                          style:
                              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentDark),
                        ),
                      ),
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

// ── Flash sale strip ──────────────────────────────────────────────────────

/// Port of FlashSaleStrip.tsx: the sale ending soonest, its live countdown
/// and a row of its products. Hides itself the moment the countdown ends.
class _FlashSaleStrip extends StatelessWidget {
  final List<FlashSale> sales;
  const _FlashSaleStrip(this.sales);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final live = sales.where((s) => s.items.isNotEmpty).toList()..sort((a, b) => a.endsAt.compareTo(b.endsAt));
    if (live.isEmpty) return const SizedBox.shrink();
    final sale = live.first;
    // Built once; the ticker below only swaps it out when the sale ends (an
    // identical widget instance is not rebuilt each second).
    final content = Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: p.isDark ? AppColors.danger.withValues(alpha: 0.16) : const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt_rounded, size: 22, color: AppColors.danger),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Flash sale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text)),
                      Text(
                        sale.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SaleCountdownChip(endsAt: sale.endsAt, showLabel: false),
                TextButton(
                  onPressed: () => openFlashSales(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(live.length > 1 ? 'See all ${live.length}' : 'See all'),
                ),
              ],
            ),
          ),
          FlashSaleRow(sale.items),
        ],
      ),
    );
    return CountdownBuilder(
      endsAt: sale.endsAt,
      builder: (context, left) => left == Duration.zero ? const SizedBox.shrink() : content,
    );
  }
}

// ── On sale highlight cards ───────────────────────────────────────────────

class _FlashDeals extends StatelessWidget {
  final List<ProductModel> deals;
  const _FlashDeals(this.deals);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final d in deals)
            GestureDetector(
              onTap: () => openProduct(context, d.id, preview: d),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                          width: 112, height: 112, child: NetImage(d.coverUrl, fallbackIcon: Icons.sell_outlined)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Save ${d.discountPercent}%',
                              style:
                                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.danger)),
                          const SizedBox(height: 4),
                          Text(d.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w600, color: p.text)),
                          const SizedBox(height: 6),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.end,
                            spacing: 8,
                            children: [
                              Text(formatPrice(d.effectivePrice, d.currency),
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text)),
                              Text(
                                formatPrice(d.strikePrice ?? d.price, d.currency),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.7,
                                  color: p.textTertiary,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: p.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Row(
                            children: [
                              Text('Shop deal',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.danger)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.danger),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Vendors ───────────────────────────────────────────────────────────────

class _VendorRow extends StatelessWidget {
  final List<VendorModel> vendors;
  const _VendorRow(this.vendors);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      height: 158,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: vendors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final v = vendors[i];
          final tone = p.tone(i);
          return GestureDetector(
            onTap: () => openStore(context, v.storeId),
            child: Container(
              width: 250,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: v.avatarUrl != null && v.avatarUrl!.isNotEmpty
                              ? NetImage(v.avatarUrl, fallbackIcon: Icons.storefront_rounded, iconSize: 22)
                              : Container(
                                  color: tone.fg,
                                  alignment: Alignment.center,
                                  child: Text(v.storeName.isEmpty ? '?' : v.storeName[0].toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(v.storeName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text)),
                                ),
                                if (v.isVerified) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.verified_rounded, size: 16, color: p.accent),
                                ],
                              ],
                            ),
                            Text('${v.listingCount} ${v.listingCount == 1 ? 'product' : 'products'}',
                                style: TextStyle(fontSize: 12, color: p.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    v.tagline?.isNotEmpty == true ? v.tagline! : 'Independent seller on Aptigen',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, height: 1.35, color: p.textSecondary),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text('Visit store', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: p.accent)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 15, color: p.accent),
                    ],
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

// ── Skeletons ─────────────────────────────────────────────────────────────

class _CategorySkeleton extends StatelessWidget {
  const _CategorySkeleton();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
        child: Row(
          children: List.generate(
            5,
            (_) => const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Skeleton(width: 60, height: 60, circle: true),
            ),
          ),
        ),
      );
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 140, height: 18, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 14),
            SizedBox(
              height: 132,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  Skeleton(width: 280, height: 132),
                  SizedBox(width: 12),
                  Skeleton(width: 280, height: 132),
                ],
              ),
            ),
          ],
        ),
      );
}
