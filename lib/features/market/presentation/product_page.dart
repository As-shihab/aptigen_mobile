import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/html_text.dart';
import '../../../core/utils/media_url.dart';
import '../../../shared/skeleton.dart';
import '../data/cart_store.dart';
import '../data/local_lists.dart';
import '../data/market_service.dart';
import '../models/market_extras.dart';
import '../models/product_model.dart';
import 'cart_page.dart';
import 'market_nav.dart';
import 'widgets/common.dart';
import 'widgets/countdown.dart';
import 'widgets/product_tile.dart';
import 'widgets/rating_stars.dart';

const _conditionLabels = {'new': 'New', 'used': 'Used', 'refurbished': 'Refurbished'};
const _typeLabels = {'fixed': 'Fixed price', 'auction': 'Auction', 'negotiable': 'Negotiable'};

/// A view counts as "unique" once per app session (web dedups per browser
/// session the same way).
final _viewedThisSession = <int>{};

/// Product detail — port of market/view/view.client.tsx.
class ProductPage extends StatefulWidget {
  final int id;
  final ProductModel? preview;
  const ProductPage({super.key, required this.id, this.preview});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final _api = MarketService();
  ProductModel? _listing;
  bool _loading = true;
  bool _notFound = false;
  List<ProductModel> _related = [];
  int _qty = 1;
  bool _justAdded = false;

  ReviewPage? _reviews;
  bool _reviewsLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _listing = widget.preview;
    _qty = widget.preview?.minOrder ?? 1;
    RecentlyViewedStore.instance.init().then((_) => RecentlyViewedStore.instance.push(widget.id));
    CompareStore.instance.init();
    _load();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final page = await _api.getListingReviews(widget.id, take: 5);
    if (mounted) setState(() => _reviews = page);
  }

  Future<void> _loadMoreReviews() async {
    final current = _reviews;
    if (current == null || _reviewsLoadingMore) return;
    setState(() => _reviewsLoadingMore = true);
    final next = await _api.getListingReviews(widget.id, skip: current.items.length, take: 10);
    if (!mounted) return;
    final seen = current.items.map((r) => r.id).toSet();
    setState(() {
      _reviewsLoadingMore = false;
      _reviews = ReviewPage(
        items: [...current.items, ...next.items.where((r) => !seen.contains(r.id))],
        // An empty page means there's nothing more, whatever the count said.
        total: next.items.isEmpty ? current.items.length : current.total,
        average: current.average,
        distribution: current.distribution,
      );
    });
  }

  void _toggleCompare() {
    final store = CompareStore.instance;
    final was = store.contains(widget.id);
    if (!store.toggle(widget.id)) {
      _compareSnack('You can compare up to ${CompareStore.max} products');
      return;
    }
    _compareSnack(was ? 'Removed from compare' : 'Added to compare');
  }

  void _compareSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        action: CompareStore.instance.value.isEmpty
            ? null
            : SnackBarAction(label: 'View', textColor: const Color(0xFF93C5FD), onPressed: () => openCompare(context)),
      ));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _notFound = false;
    });
    try {
      final l = await _api.getListing(widget.id);
      if (!mounted) return;
      if (l == null) {
        setState(() => _notFound = _listing == null);
        return;
      }
      setState(() {
        _listing = l;
        if (_qty < l.minOrder) _qty = l.minOrder;
      });
      _api.trackEvent(l.id, 'view', unique: _viewedThisSession.add(l.id));
      if (l.categoryId != null) {
        _api.getListings(take: 9, categoryId: l.categoryId).then((r) {
          if (mounted) setState(() => _related = r.items.where((i) => i.id != l.id).take(8).toList());
        }).catchError((_) {});
      }
    } catch (_) {
      if (mounted && _listing == null) setState(() => _notFound = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addToCart() {
    final l = _listing!;
    CartStore.instance.addProduct(l, quantity: _qty);
    setState(() => _justAdded = true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _justAdded = false);
    });
  }

  void _buyNow() {
    final l = _listing!;
    if (!CartStore.instance.contains(l.id)) CartStore.instance.addProduct(l, quantity: _qty);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartPage(standalone: true)));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final l = _listing;

    if (l == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: p.bg),
        body: _notFound
            ? EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Listing not found',
                message: 'This listing may be inactive or no longer exists.',
                actionLabel: 'Try again',
                onAction: _load,
              )
            : const _DetailSkeleton(),
      );
    }

    final minOrder = l.minOrder;
    final store = l.store;
    final description = htmlToPlainText(l.description);
    final details = <(String, String)>[
      if (l.categoryName != null) ('Category', l.categoryName!),
      if (l.condition != null) ('Condition', _conditionLabels[l.condition] ?? l.condition!),
      if (l.listingType != null) ('Listing type', _typeLabels[l.listingType] ?? l.listingType!),
      if (minOrder > 1) ('Minimum order', '$minOrder units'),
      if (l.maxOrder != null) ('Maximum order', '${l.maxOrder} units'),
      if (l.location != null) ('Location', l.location!),
    ];

    return Scaffold(
      backgroundColor: p.card,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: p.card,
            expandedHeight: MediaQuery.sizeOf(context).width,
            leading: const _RoundAction(icon: Icons.arrow_back_rounded, isBack: true),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _CompareAction(id: l.id, onTap: _toggleCompare),
              ),
              Padding(padding: const EdgeInsets.only(right: 4), child: WishlistHeart(l.id, size: 40)),
              const Padding(padding: EdgeInsets.only(right: 12), child: _CartAction()),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _Gallery(listing: l),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (l.categoryName != null)
                    GestureDetector(
                      onTap: () => openSearch(context, categoryId: l.categoryId, categoryName: l.categoryName),
                      child: Text(l.categoryName!,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.accent)),
                    ),
                  const SizedBox(height: 6),
                  Text(l.title,
                      style: TextStyle(fontSize: 21, height: 1.3, fontWeight: FontWeight.w700, color: p.text)),
                  const SizedBox(height: 10),
                  _SellerInline(listing: l),
                  if (l.ratingCount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        RatingStars(value: l.ratingAvg, size: 15),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${(l.ratingAvg ?? 0).toStringAsFixed(1)} · ${l.ratingCount} ${l.ratingCount == 1 ? 'review' : 'reviews'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (l.liveFlash != null) ...[
                    _FlashBand(flash: l.liveFlash!),
                    const SizedBox(height: 14),
                  ],
                  _PriceBlock(listing: l),
                  if (l.stock != null) ...[
                    const SizedBox(height: 10),
                    _Availability(listing: l),
                  ],
                  if (minOrder > 1) ...[
                    const SizedBox(height: 6),
                    Text('Minimum order is $minOrder units.', style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                  ],
                  if (store?.phone != null && store!.phone!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final digits = store.phone!.replaceAll(RegExp(r'[^\d]'), '');
                          final text = Uri.encodeComponent('Hi, I\'m interested in "${l.title}"');
                          openExternal('https://wa.me/$digits?text=$text');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.success,
                          side: BorderSide(color: AppColors.success.withValues(alpha: 0.35)),
                        ),
                        icon: const Icon(Icons.chat_rounded, size: 18),
                        label: const Text('Order on WhatsApp'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Divider(color: p.border, height: 1),
                  const SizedBox(height: 16),
                  if (l.location != null) _InfoLine(Icons.place_outlined, 'Ships from ${l.location}'),
                  const _InfoLine(Icons.local_shipping_outlined, 'Delivery arranged by the seller after you order'),
                  const _InfoLine(Icons.verified_user_outlined, 'Secure checkout on Aptigen'),
                ],
              ),
            ),
          ),

          // About + details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: p.border, height: 24),
                  Text('About this product',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text)),
                  const SizedBox(height: 10),
                  _ExpandableText(description.isEmpty ? "The seller hasn't added a description yet." : description),
                  if (l.tags.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: l.tags
                          .map((t) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(20)),
                                child: Text(t, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                              ))
                          .toList(),
                    ),
                  ],
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Details', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text)),
                    const SizedBox(height: 6),
                    ...details.map((d) => Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.fill))),
                          child: Row(
                            children: [
                              Expanded(child: Text(d.$1, style: TextStyle(fontSize: 13.5, color: p.textSecondary))),
                              Flexible(
                                child: Text(d.$2,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.text)),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),

          // Seller strip
          if (store != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: _SellerCard(store: store),
              ),
            ),

          SliverToBoxAdapter(
            child: _ReviewsSection(
              reviews: _reviews,
              loadingMore: _reviewsLoadingMore,
              onMore: _loadMoreReviews,
            ),
          ),

          if (_related.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      'You might also like',
                      actionLabel: 'See all',
                      onAction: () => openSearch(context, categoryId: l.categoryId, categoryName: l.categoryName),
                    ),
                    ProductRow(_related),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(child: _TrustRow()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      bottomNavigationBar: _BuyBar(
        listing: l,
        qty: _qty,
        loading: _loading,
        justAdded: _justAdded,
        onQty: (q) => setState(() => _qty = q),
        onAdd: _addToCart,
        onBuy: _buyNow,
      ),
    );
  }
}

// ── Gallery ───────────────────────────────────────────────────────────────

class _Gallery extends StatefulWidget {
  final ProductModel listing;
  const _Gallery({required this.listing});

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _ctrl = PageController();
  int _index = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final gallery = widget.listing.gallery;
    final l = widget.listing;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (gallery.isEmpty)
          Container(color: p.fill, child: Icon(Icons.inventory_2_outlined, size: 72, color: p.textTertiary))
        else
          PageView.builder(
            controller: _ctrl,
            itemCount: gallery.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final m = gallery[i];
              if (m.isVideo) {
                return GestureDetector(
                  onTap: () {
                    final url = MediaUrl.resolve(m.url);
                    if (url != null) openExternal(url);
                  },
                  child: Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration:
                              BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
                        ),
                        const SizedBox(height: 10),
                        const Text('Play video', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }
              return Container(color: p.fill, child: NetImage(m.url, view: 'large'));
            },
          ),
        if (l.onSale && l.discountPercent > 0)
          Positioned(
            left: 16,
            bottom: 16,
            child: Pill(
              l.liveFlash != null ? 'Flash sale -${l.discountPercent}%' : '-${l.discountPercent}%',
              bg: AppColors.danger,
              fg: Colors.white,
            ),
          ),
        if (gallery.length > 1)
          Positioned(
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration:
                  BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20)),
              child: Text('${_index + 1} / ${gallery.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500)),
            ),
          ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final bool isBack;
  const _RoundAction({required this.icon, this.isBack = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          color: Colors.white.withValues(alpha: 0.9),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).maybePop(),
            child: Icon(icon, size: 20, color: const Color(0xFF111827)),
          ),
        ),
      );
}

class _CartAction extends StatelessWidget {
  const _CartAction();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: CartStore.instance,
      builder: (_, items, __) {
        final count = CartStore.instance.count;
        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartPage(standalone: true))),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)],
            ),
            child: Badge(
              isLabelVisible: count > 0,
              backgroundColor: AppColors.accent,
              label: Text('$count'),
              child: const Icon(Icons.shopping_bag_outlined, size: 20, color: Color(0xFF111827)),
            ),
          ),
        );
      },
    );
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────

class _SellerInline extends StatelessWidget {
  final ProductModel listing;
  const _SellerInline({required this.listing});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final store = listing.store;
    return GestureDetector(
      onTap: store == null ? null : () => openStore(context, store.id),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 24,
              height: 24,
              child: NetImage(store?.avatarUrl, fallbackIcon: Icons.storefront_rounded, iconSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Text('by ', style: TextStyle(fontSize: 13, color: p.textSecondary)),
          Flexible(
            child: Text(
              store?.name ?? 'Aptigen marketplace',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.text),
            ),
          ),
          if (store?.isVerified == true) ...[
            const SizedBox(width: 4),
            Icon(Icons.verified_rounded, size: 16, color: p.accent),
          ],
          if (listing.condition != null) ...[
            Container(width: 1, height: 14, color: p.border, margin: const EdgeInsets.symmetric(horizontal: 8)),
            Text(_conditionLabels[listing.condition] ?? listing.condition!,
                style: TextStyle(fontSize: 13, color: p.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _Availability extends StatelessWidget {
  final ProductModel listing;
  const _Availability({required this.listing});

  @override
  Widget build(BuildContext context) {
    final color = listing.outOfStock
        ? AppColors.danger
        : listing.lowStock
            ? AppColors.warning
            : AppColors.success;
    final label = listing.outOfStock
        ? 'Out of stock'
        : listing.lowStock
            ? 'Only ${listing.stock} left'
            : 'In stock';
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: p.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13.5, color: p.text))),
        ],
      ),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  final String text;
  const _ExpandableText(this.text);

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final style = TextStyle(fontSize: 14, height: 1.6, color: p.textSecondary);
    final long = widget.text.length > 320;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.text,
            style: style,
            maxLines: _expanded || !long ? null : 6,
            overflow: _expanded || !long ? null : TextOverflow.fade),
        if (long)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
            child: Text(_expanded ? 'Show less' : 'Read more'),
          ),
      ],
    );
  }
}

class _SellerCard extends StatelessWidget {
  final StoreSummary store;
  const _SellerCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 52,
              height: 52,
              child: NetImage(store.avatarUrl, fallbackIcon: Icons.storefront_rounded, iconSize: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sold by', style: TextStyle(fontSize: 11.5, color: p.textSecondary)),
                Row(
                  children: [
                    Flexible(
                      child: Text(store.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text)),
                    ),
                    if (store.isVerified) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.verified_rounded, size: 16, color: p.accent),
                    ],
                  ],
                ),
                if (store.isVerified) Text('Verified seller', style: TextStyle(fontSize: 11.5, color: p.textSecondary)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => openStore(context, store.id),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              backgroundColor: p.card,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text('Visit store'),
          ),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    const items = [
      (Icons.local_shipping_outlined, 'Fast shipping', 0),
      (Icons.verified_user_outlined, 'Buyer protection', 3),
      (Icons.account_balance_wallet_outlined, 'Secure payments', 2),
      (Icons.inventory_outlined, 'Trusted sellers', 4),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 3.6,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: items.map((it) {
          final tone = p.tone(it.$3);
          return Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(it.$1, size: 19, color: tone.fg),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(it.$2, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: p.text))),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _BuyBar extends StatelessWidget {
  final ProductModel listing;
  final int qty;
  final bool loading;
  final bool justAdded;
  final ValueChanged<int> onQty;
  final VoidCallback onAdd;
  final VoidCallback onBuy;

  const _BuyBar({
    required this.listing,
    required this.qty,
    required this.loading,
    required this.justAdded,
    required this.onQty,
    required this.onAdd,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final out = listing.outOfStock;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.border))),
      child: Row(
        children: [
          QtyStepper(
              value: qty,
              min: listing.minOrder,
              max: listing.maxQty < listing.minOrder ? listing.minOrder : listing.maxQty,
              onChanged: onQty),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: out || loading ? null : onAdd,
              style: OutlinedButton.styleFrom(
                foregroundColor: justAdded ? AppColors.success : p.accent,
                side: BorderSide(color: justAdded ? AppColors.success : p.accent),
                padding: EdgeInsets.zero,
              ),
              child: FittedBox(child: Text(justAdded ? 'Added' : 'Add to cart')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: out || loading ? null : onBuy,
              style: FilledButton.styleFrom(padding: EdgeInsets.zero),
              child: FittedBox(child: Text(out ? 'Out of stock' : 'Buy now')),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareAction extends StatelessWidget {
  final int id;
  final VoidCallback onTap;
  const _CompareAction({required this.id, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<int>>(
      valueListenable: CompareStore.instance,
      builder: (context, ids, _) {
        final on = ids.contains(id);
        return Semantics(
          button: true,
          label: on ? 'Remove from compare' : 'Add to compare',
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: on ? AppColors.accent : Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)],
              ),
              child: Icon(
                Icons.compare_arrows_rounded,
                size: 20,
                color: on ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Live flash sale band: sale name and an "Ends in HH:MM:SS" countdown.
class _FlashBand extends StatelessWidget {
  final FlashPrice flash;
  const _FlashBand({required this.flash});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final fg = p.isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.isDark ? AppColors.danger.withValues(alpha: 0.14) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, size: 20, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              flash.saleName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Countdown(
              endsAt: flash.endsAt,
              prefix: 'Ends in ',
              endedLabel: 'This sale has ended',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Effective price, the struck price and % saved, plus flash-sale limits.
class _PriceBlock extends StatelessWidget {
  final ProductModel listing;
  const _PriceBlock({required this.listing});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final l = listing;
    final flash = l.liveFlash;
    final strike = l.strikePrice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 10,
          runSpacing: 4,
          children: [
            Text(
              formatPrice(l.effectivePrice, l.currency),
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800, color: flash != null ? AppColors.danger : p.text),
            ),
            if (strike != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  formatPrice(strike, l.currency),
                  style: TextStyle(
                    fontSize: 16,
                    color: p.textTertiary,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: p.textTertiary,
                  ),
                ),
              ),
            if (strike != null && l.discountPercent > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('Save ${l.discountPercent}%',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.danger)),
              ),
          ],
        ),
        if (flash != null && (flash.remaining != null || flash.perOrderLimit != null))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text.rich(
              TextSpan(children: [
                if (flash.remaining != null)
                  TextSpan(
                    text: '${flash.remaining} left at this price',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.warning),
                  ),
                if (flash.remaining != null && flash.perOrderLimit != null) const TextSpan(text: ' · '),
                if (flash.perOrderLimit != null)
                  TextSpan(text: 'Limit ${flash.perOrderLimit} per order at the sale price'),
              ]),
              style: TextStyle(fontSize: 12.5, height: 1.4, color: p.textSecondary),
            ),
          ),
      ],
    );
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _reviewDate(DateTime? d) => d == null ? '' : '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// Reviews: average, 1–5 distribution and the review list with seller
/// replies — the "Reviews" section of view.client.tsx.
class _ReviewsSection extends StatelessWidget {
  final ReviewPage? reviews;
  final bool loadingMore;
  final VoidCallback onMore;
  const _ReviewsSection({required this.reviews, required this.loadingMore, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final r = reviews;
    final count = r == null ? 0 : (r.total > 0 ? r.total : r.items.length);

    final Widget body;
    if (r == null) {
      body = Column(
        children: [
          Skeleton(height: 72, borderRadius: BorderRadius.circular(12)),
          const SizedBox(height: 10),
          Skeleton(height: 56, borderRadius: BorderRadius.circular(12)),
        ],
      );
    } else if (count == 0) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: p.accentSoft, shape: BoxShape.circle),
            child: Icon(Icons.chat_bubble_outline_rounded, size: 19, color: p.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No reviews yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text)),
                const SizedBox(height: 3),
                Text(
                  'Reviews come from buyers after their order is delivered, so every rating here is from a real purchase.',
                  style: TextStyle(fontSize: 13, height: 1.45, color: p.textSecondary),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      final distCount = r.distribution.values.fold<int>(0, (a, b) => a + b);
      final denom = distCount > 0 ? distCount : count;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text((r.average ?? 0).toStringAsFixed(1),
                  style: TextStyle(fontSize: 36, height: 1, fontWeight: FontWeight.w700, color: p.text)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RatingStars(value: r.average, size: 16),
                    const SizedBox(height: 3),
                    Text('Based on $count ${count == 1 ? 'review' : 'reviews'}',
                        style: TextStyle(fontSize: 12, color: p.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var star = 5; star >= 1; star--)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  SizedBox(
                      width: 48, child: Text('$star star', style: TextStyle(fontSize: 12.5, color: p.textSecondary))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: denom == 0 ? 0 : (r.distribution[star] ?? 0) / denom,
                        minHeight: 7,
                        backgroundColor: p.fill,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text('${r.distribution[star] ?? 0}',
                        textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          for (var i = 0; i < r.items.length; i++) ...[
            if (i > 0) Divider(color: p.fill, height: 1),
            _ReviewTile(review: r.items[i]),
          ],
          if (r.items.length < r.total)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton(
                onPressed: loadingMore ? null : onMore,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                child: Text(loadingMore ? 'Loading…' : 'Show more reviews (${r.total - r.items.length})'),
              ),
            ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: p.border, height: 24),
          Text('Reviews', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text)),
          const SizedBox(height: 14),
          body,
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final ListingReview review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final r = review;
    final tone = p.tone(r.id);
    final name = r.reviewer.trim().isEmpty ? 'Buyer' : r.reviewer.trim();
    final comment = r.comment?.trim() ?? '';
    final reply = r.sellerReply?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: tone.bg,
                child: Text(name.characters.first.toUpperCase(),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tone.fg)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.text)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        RatingStars(value: r.rating, size: 13),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(_reviewDate(r.createdAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: p.textTertiary)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(comment, style: TextStyle(fontSize: 14, height: 1.55, color: p.textSecondary)),
          ],
          if (reply.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 12, top: 12),
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: p.accent.withValues(alpha: 0.3), width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Response from the seller',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.text)),
                      if (r.sellerRepliedAt != null)
                        Text(_reviewDate(r.sellerRepliedAt), style: TextStyle(fontSize: 11.5, color: p.textTertiary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(reply, style: TextStyle(fontSize: 13, height: 1.5, color: p.textSecondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AspectRatio(aspectRatio: 1, child: Skeleton()),
          const SizedBox(height: 18),
          Skeleton(width: 120, height: 14, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 10),
          Skeleton(height: 22, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 10),
          Skeleton(width: 160, height: 28, borderRadius: BorderRadius.circular(4)),
        ],
      );
}
