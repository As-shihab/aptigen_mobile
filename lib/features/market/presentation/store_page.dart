import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/skeleton.dart';
import '../data/market_service.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';
import 'market_nav.dart';
import 'widgets/common.dart';
import 'widgets/product_tile.dart';

const _pageSize = 12;
final _visitedThisSession = <int>{};

String _fmtNum(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

/// Storefront — port of market/store/store.client.tsx.
class StorePage extends StatefulWidget {
  final int id;
  const StorePage({super.key, required this.id});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> with SingleTickerProviderStateMixin {
  final _api = MarketService();
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _scroll = ScrollController();
  final _searchInput = TextEditingController();
  Timer? _debounce;

  StoreModel? _store;
  int _followers = 0;
  bool _followed = false;
  bool _loading = true;
  bool _notFound = false;

  final List<ProductModel> _items = [];
  int _total = 0;
  bool _listLoading = false;
  String _search = '';
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _tabs.addListener(() => setState(() {}));
    _api.trackStoreVisit(widget.id, unique: _visitedThisSession.add(widget.id));
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabs.dispose();
    _scroll.dispose();
    _searchInput.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_listLoading || _items.length >= _total)) return;
    final token = ++_token;
    setState(() {
      _listLoading = true;
      if (reset) _items.clear();
    });
    try {
      final data = await _api.getStore(widget.id, skip: _items.length, take: _pageSize, search: _search);
      if (token != _token || !mounted) return;
      if (data == null) {
        setState(() => _notFound = _store == null);
        return;
      }
      setState(() {
        _store = data.store;
        _followers = data.followerCount;
        _items.addAll(data.listings);
        _total = data.listings.isEmpty ? _items.length : data.total;
      });
    } catch (_) {
      if (token == _token && mounted && _store == null) setState(() => _notFound = true);
    } finally {
      if (token == _token && mounted) {
        setState(() {
          _listLoading = false;
          _loading = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_tabs.index == 0 && _scroll.position.extentAfter < 500 && !_listLoading && _items.length < _total) _load();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final q = text.trim();
      if (q == _search) return;
      _search = q;
      _load(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    if (_loading && _store == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: p.bg),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Skeleton(height: 180),
            const SizedBox(height: 16),
            Skeleton(width: 180, height: 20, borderRadius: BorderRadius.circular(4)),
          ],
        ),
      );
    }
    if (_notFound || _store == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: p.bg),
        body: EmptyState(
          icon: Icons.storefront_outlined,
          title: 'Store not found',
          message: 'This store may be inactive or no longer exists.',
          actionLabel: 'Try again',
          onAction: () {
            setState(() {
              _loading = true;
              _notFound = false;
            });
            _load(reset: true);
          },
        ),
      );
    }

    final store = _store!;
    final accent = store.accent;
    final followers = _followers + (_followed ? 1 : 0);

    return Scaffold(
      backgroundColor: p.card,
      body: CustomScrollView(
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            backgroundColor: accent,
            foregroundColor: Colors.white,
            title: Text(store.storeName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            flexibleSpace: FlexibleSpaceBar(
              background: _StoreHero(
                store: store,
                productCount: _total,
                followers: followers,
                followed: _followed,
                onFollow: () => setState(() => _followed = !_followed),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabs,
                labelColor: p.text,
                unselectedLabelColor: p.textSecondary,
                indicatorColor: accent,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                tabs: [Tab(text: 'Products ($_total)'), const Tab(text: 'About')],
              ),
              p.card,
              p.border,
            ),
          ),
          if (_tabs.index == 0) ..._productSlivers(p) else SliverToBoxAdapter(child: _About(store: store, total: _total, followers: followers)),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  List<Widget> _productSlivers(Palette p) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: TextField(
              controller: _searchInput,
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 14, color: p.text),
              decoration: InputDecoration(
                hintText: "Search this store's products",
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: p.textSecondary),
              ),
            ),
          ),
        ),
        if (_items.isEmpty && _listLoading)
          const ProductGridSkeleton()
        else if (_items.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.inventory_2_outlined,
              title: _search.isNotEmpty ? 'No products match "$_search"' : 'No products listed yet',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: productGridDelegate(context),
              delegate: SliverChildBuilderDelegate((_, i) => ProductTile(_items[i]), childCount: _items.length),
            ),
          ),
        if (_items.isNotEmpty && _listLoading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: p.accent)),
              ),
            ),
          ),
      ];
}

class _StoreHero extends StatelessWidget {
  final StoreModel store;
  final int productCount;
  final int followers;
  final bool followed;
  final VoidCallback onFollow;

  const _StoreHero({
    required this.store,
    required this.productCount,
    required this.followers,
    required this.followed,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    final hasBanner = store.bannerUrl != null && store.bannerUrl!.isNotEmpty;
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasBanner) NetImage(store.bannerUrl, view: 'large') else Container(color: store.accent),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withValues(alpha: 0.72), Colors.black.withValues(alpha: hasBanner ? 0.2 : 0.05)],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, top, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: store.accent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 3),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: store.avatarUrl != null && store.avatarUrl!.isNotEmpty
                            ? NetImage(store.avatarUrl)
                            : Center(
                                child: Text(store.initials,
                                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                              ),
                      ),
                      if (store.isVerified)
                        Positioned(
                          right: -6,
                          bottom: -6,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: Icon(Icons.verified_rounded, size: 18, color: store.accent),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(store.storeName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 22, height: 1.2, fontWeight: FontWeight.w700, color: Colors.white)),
                        if (store.tagline != null && store.tagline!.isNotEmpty)
                          Text(store.tagline!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: Colors.white70)),
                        if (store.location != null)
                          Text(store.location!, style: const TextStyle(fontSize: 12, color: Colors.white60)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Stat('$productCount', 'Products'),
                  const SizedBox(width: 22),
                  _Stat(_fmtNum(followers), 'Followers'),
                  const SizedBox(width: 22),
                  _Stat('${store.createdAt?.year ?? '—'}', 'Since'),
                  const Spacer(),
                  if (store.email != null && store.email!.isNotEmpty) ...[
                    IconButton.filledTonal(
                      onPressed: () => openExternal('mailto:${store.email}'),
                      style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.15)),
                      icon: const Icon(Icons.mail_outline_rounded, color: Colors.white, size: 19),
                    ),
                    const SizedBox(width: 6),
                  ],
                  FilledButton(
                    onPressed: onFollow,
                    style: FilledButton.styleFrom(
                      backgroundColor: followed ? Colors.white.withValues(alpha: 0.18) : Colors.white,
                      foregroundColor: followed ? Colors.white : const Color(0xFF111827),
                      minimumSize: const Size(96, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(followed ? 'Following' : 'Follow'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ],
      );
}

class _About extends StatelessWidget {
  final StoreModel store;
  final int total;
  final int followers;
  const _About({required this.store, required this.total, required this.followers});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final accent = store.accent;
    Widget heading(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(t, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text)),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (store.bio != null && store.bio!.isNotEmpty) ...[
            heading('About ${store.storeName}'),
            Text(store.bio!, style: TextStyle(fontSize: 14, height: 1.55, color: p.textSecondary)),
            const SizedBox(height: 24),
          ],
          heading('What to expect'),
          ...['Direct from the seller', 'Buyer-protected checkout', 'Responsive support', 'Fast dispatch'].map(
            (h) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: accent),
                  const SizedBox(width: 10),
                  Text(h, style: TextStyle(fontSize: 14, color: p.text)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          heading('Store policies'),
          Row(
            children: [
              (Icons.shield_outlined, 'Buyer protection', 'Safe & secure checkout'),
              (Icons.local_shipping_outlined, 'Fast shipping', 'Dispatched promptly'),
              (Icons.replay_rounded, 'Easy returns', 'Contact the seller'),
            ]
                .map((it) => Expanded(
                      child: Column(
                        children: [
                          Icon(it.$1, color: accent, size: 22),
                          const SizedBox(height: 6),
                          Text(it.$2,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.text)),
                          const SizedBox(height: 2),
                          Text(it.$3, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: p.textSecondary)),
                        ],
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Store overview', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.text)),
                const SizedBox(height: 6),
                for (final row in [
                  (Icons.inventory_2_outlined, 'Total products', '$total'),
                  (Icons.people_outline_rounded, 'Followers', _fmtNum(followers)),
                  (Icons.calendar_today_outlined, 'Member since', '${store.createdAt?.year ?? '—'}'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        Icon(row.$1, size: 16, color: p.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(row.$2, style: TextStyle(fontSize: 13, color: p.textSecondary))),
                        Text(row.$3, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.text)),
                      ],
                    ),
                  ),
                if (store.isVerified)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                    child: Text('Verified seller', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accent)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar bar;
  final Color bg;
  final Color border;
  _TabBarDelegate(this.bar, this.bg, this.border);

  @override
  double get minExtent => bar.preferredSize.height + 1;
  @override
  double get maxExtent => bar.preferredSize.height + 1;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(
        decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: border))),
        child: bar,
      );

  @override
  bool shouldRebuild(_TabBarDelegate old) => old.bar != bar || old.bg != bg;
}
