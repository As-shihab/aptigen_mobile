import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../data/cart_store.dart';
import '../data/local_lists.dart';
import '../data/market_service.dart';
import '../models/product_model.dart';
import 'market_nav.dart';
import 'widgets/common.dart';
import 'widgets/countdown.dart';
import 'widgets/rating_stars.dart';

const _conditionLabels = {'new': 'New', 'used': 'Used', 'refurbished': 'Refurbished'};

/// Up to [CompareStore.max] listings side by side — port of
/// market/compare/compare.client.tsx. Columns scroll sideways together on
/// narrow phones.
class ComparePage extends StatefulWidget {
  const ComparePage({super.key});

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  final _api = MarketService();
  final _store = CompareStore.instance;
  final Map<int, ProductModel> _cache = {};
  bool _failed = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _store.addListener(_sync);
    _store.init().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _sync();
    });
  }

  @override
  void dispose() {
    _store.removeListener(_sync);
    super.dispose();
  }

  Future<void> _sync() async {
    if (!mounted) return;
    final missing = _store.value.where((id) => !_cache.containsKey(id)).toList();
    if (missing.isEmpty) {
      setState(() {});
      return;
    }
    setState(() => _failed = false);
    try {
      final page = await _api.getListings(ids: missing, take: CompareStore.max);
      if (!mounted) return;
      setState(() {
        for (final it in page.items) {
          _cache[it.id] = it;
        }
      });
      // Listings that no longer exist shouldn't keep holding a slot.
      final found = page.items.map((i) => i.id).toSet();
      for (final id in missing.where((id) => !found.contains(id))) {
        if (_store.contains(id)) _store.toggle(id);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ValueListenableBuilder<List<int>>(
      valueListenable: _store,
      builder: (context, ids, _) {
        final items = ids.map((id) => _cache[id]).whereType<ProductModel>().toList();
        final loading = !_ready || (!_failed && items.length < ids.length);
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            backgroundColor: p.bg,
            title: const Text('Compare products'),
            actions: [
              if (ids.isNotEmpty) TextButton(onPressed: _store.clear, child: const Text('Clear all')),
              const SizedBox(width: 4),
            ],
          ),
          body: !_ready
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : ids.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        child: EmptyState(
                          icon: Icons.compare_arrows_rounded,
                          title: 'Nothing to compare yet',
                          message: 'Add up to ${CompareStore.max} products from their pages to see them side by side.',
                          actionLabel: 'Browse products',
                          onAction: () => openSearch(context),
                        ),
                      ),
                    )
                  : _failed && items.isEmpty
                      ? ErrorState(onRetry: _sync)
                      : loading && items.isEmpty
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                          : _table(context, items, ids.length),
        );
      },
    );
  }

  Widget _table(BuildContext context, List<ProductModel> items, int selected) {
    final p = Palette.of(context);
    final width = MediaQuery.sizeOf(context).width;
    // Fit all columns on wide screens; at least 148px each on small phones.
    final colWidth = ((width - 32 - 10 * (items.length - 1)) / items.length).clamp(148.0, 260.0);

    final prices = items.map((i) => i.effectivePrice).toList();
    final distinct = prices.toSet();
    final lowest = prices.length > 1 && distinct.length > 1 ? prices.reduce((a, b) => a < b ? a : b) : null;

    final rows = <(String, Widget Function(ProductModel))>[
      ('Price', (it) => _priceCell(context, it, lowest)),
      (
        'Rating',
        (it) => it.ratingCount > 0
            ? Wrap(
                spacing: 4,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  RatingStars(value: it.ratingAvg, size: 13),
                  Text('${(it.ratingAvg ?? 0).toStringAsFixed(1)} (${it.ratingCount})',
                      style: TextStyle(fontSize: 12, color: p.textSecondary)),
                ],
              )
            : _muted(p, 'No reviews yet')
      ),
      (
        'Condition',
        (it) => it.condition == null
            ? _muted(p, 'Not specified')
            : _plain(p, _conditionLabels[it.condition] ?? it.condition!)
      ),
      ('Availability', (it) => _stockCell(it)),
      ('Minimum order', (it) => _plain(p, '${it.minOrder} ${it.minOrder == 1 ? 'unit' : 'units'}')),
      (
        'Seller',
        (it) => it.store == null
            ? _plain(p, 'Aptigen marketplace')
            : GestureDetector(
                onTap: () => openStore(context, it.store!.id),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(it.store!.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.accent)),
                    ),
                    if (it.store!.isVerified) ...[
                      const SizedBox(width: 3),
                      Icon(Icons.verified_rounded, size: 14, color: p.accent),
                    ],
                  ],
                ),
              )
      ),
      ('Location', (it) => it.location == null ? _muted(p, 'Not specified') : _plain(p, it.location!)),
      ('Category', (it) => _plain(p, it.categoryName ?? 'General')),
    ];

    final totalWidth = colWidth * items.length + 10 * (items.length - 1);
    Widget cells(Widget Function(ProductModel) build) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              SizedBox(width: colWidth, child: build(items[i])),
            ],
          ],
        );

    final table = SizedBox(
      width: totalWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cells((it) => _header(context, it)),
          for (final r in rows)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.$1, style: TextStyle(fontSize: 11.5, color: p.textSecondary)),
                  const SizedBox(height: 4),
                  cells(r.$2),
                ],
              ),
            ),
          const SizedBox(height: 8),
          cells((it) => FilledButton(
                onPressed: it.outOfStock
                    ? null
                    : () {
                        CartStore.instance.addProduct(it, quantity: it.minOrder);
                        showToast(context, 'Added to cart');
                      },
                style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: EdgeInsets.zero),
                child: FittedBox(child: Text(it.outOfStock ? 'Out of stock' : 'Add to cart')),
              )),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text('$selected of ${CompareStore.max} selected',
                    style: TextStyle(fontSize: 13, color: p.textSecondary)),
              ),
              if (selected < CompareStore.max)
                TextButton(onPressed: () => openSearch(context), child: const Text('Add another')),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: table,
        ),
      ],
    );
  }

  Widget _header(BuildContext context, ProductModel it) {
    final p = Palette.of(context);
    return GestureDetector(
      onTap: () => openProduct(context, it.id, preview: it),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetImage(it.coverUrl),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.85),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _store.toggle(it.id),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF1F2937)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: Text(
              it.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w600, color: p.text),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _priceCell(BuildContext context, ProductModel it, double? lowest) {
    final p = Palette.of(context);
    final isLowest = lowest != null && it.effectivePrice == lowest;
    final flash = it.liveFlash;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text(
              formatPrice(it.effectivePrice, it.currency),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isLowest ? AppColors.success : (flash != null ? AppColors.danger : p.text),
              ),
            ),
            if (it.strikePrice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  formatPrice(it.strikePrice!, it.currency),
                  style: TextStyle(
                    fontSize: 12,
                    color: p.textTertiary,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: p.textTertiary,
                  ),
                ),
              ),
          ],
        ),
        if (isLowest || it.discountPercent > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(
              spacing: 8,
              children: [
                if (isLowest)
                  const Text('Lowest price',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.success)),
                if (it.discountPercent > 0)
                  Text('Save ${it.discountPercent}%',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.danger)),
              ],
            ),
          ),
        if (flash != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 13, color: AppColors.danger),
                const SizedBox(width: 2),
                Expanded(
                  child: Countdown(
                    endsAt: flash.endsAt,
                    format: CountdownFormat.short,
                    prefix: 'Flash sale ends in ',
                    endedLabel: 'Flash sale ended',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _stockCell(ProductModel it) {
    final s = it.stock;
    final (String, Color) v = s == null
        ? ('In stock', AppColors.success)
        : s <= 0
            ? ('Out of stock', AppColors.danger)
            : s <= 5
                ? ('Only $s left', AppColors.warning)
                : ('$s in stock', AppColors.success);
    return Text(v.$1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: v.$2));
  }

  Widget _plain(Palette p, String text) => Text(text, style: TextStyle(fontSize: 13, color: p.text));
  Widget _muted(Palette p, String text) => Text(text, style: TextStyle(fontSize: 13, color: p.textTertiary));
}

/// Small floating "Compare (n)" pill — shows only while something is picked.
class CompareFab extends StatefulWidget {
  const CompareFab({super.key});

  @override
  State<CompareFab> createState() => _CompareFabState();
}

class _CompareFabState extends State<CompareFab> {
  @override
  void initState() {
    super.initState();
    CompareStore.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ValueListenableBuilder<List<int>>(
      valueListenable: CompareStore.instance,
      builder: (context, ids, _) {
        if (ids.isEmpty) return const SizedBox.shrink();
        return Material(
          color: p.isDark ? p.fill : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(24),
          elevation: 3,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => openCompare(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.compare_arrows_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Compare (${ids.length})',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
