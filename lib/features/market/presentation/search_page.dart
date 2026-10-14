import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../data/market_service.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import 'compare_page.dart';
import 'widgets/common.dart';
import 'widgets/product_tile.dart';

const _pageSize = 20;

/// Same options and labels as `SORTS` in market/search/search.client.tsx.
const _sorts = <(String, String)>[
  ('newest', 'Newest'),
  ('popular', 'Most popular'),
  ('rating', 'Top rated'),
  ('price_asc', 'Price: low to high'),
  ('price_desc', 'Price: high to low'),
];

const _conditions = <(String?, String)>[
  (null, 'Any'),
  ('new', 'New'),
  ('used', 'Used'),
  ('refurbished', 'Refurbished'),
];

String _sortLabel(String v) => _sorts.firstWhere((s) => s.$1 == v, orElse: () => _sorts.first).$2;

/// Everything the filter sheet edits.
class _Filters {
  final double? minPrice;
  final double? maxPrice;
  final String? condition;
  final bool onSale;
  final int? categoryId;
  final String? categoryName;
  const _Filters(
      {this.minPrice, this.maxPrice, this.condition, this.onSale = false, this.categoryId, this.categoryName});

  int get count =>
      (minPrice != null || maxPrice != null ? 1 : 0) +
      (condition != null ? 1 : 0) +
      (onSale ? 1 : 0) +
      (categoryId != null ? 1 : 0);
}

/// Search + category browse with sort and filters — port of
/// market/search/search.client.tsx. With a category or filter it opens
/// straight into results; otherwise it starts on the search box with recent
/// searches.
class SearchPage extends StatefulWidget {
  final String? initialQuery;
  final int? categoryId;
  final String? categoryName;
  final bool onSale;

  /// Lives in a bottom tab: no back button, and the keyboard only opens when
  /// [focusSignal] ticks (the home search bar), not at app start.
  final bool asTab;
  final ValueListenable<int>? focusSignal;

  const SearchPage({
    super.key,
    this.initialQuery,
    this.categoryId,
    this.categoryName,
    this.onSale = false,
    this.asTab = false,
    this.focusSignal,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _api = MarketService();
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;

  String _query = '';
  String _sort = 'newest';
  _Filters _filters = const _Filters();
  List<CategoryModel>? _categories;

  final List<ProductModel> _items = [];
  int _total = 0;
  bool _loading = false;
  bool _error = false;
  bool _searched = false;
  int _token = 0;
  List<String> _recent = [];

  bool get _hasFilters => _filters.count > 0 || _sort != 'newest';

  @override
  void initState() {
    super.initState();
    _filters = _Filters(categoryId: widget.categoryId, categoryName: widget.categoryName, onSale: widget.onSale);
    _query = widget.initialQuery?.trim() ?? '';
    _input.text = _query;
    _scroll.addListener(_onScroll);
    AppStorage.getRecentSearches().then((r) => mounted ? setState(() => _recent = r) : null);
    widget.focusSignal?.addListener(_focusField);
    if (_hasFilters || _query.isNotEmpty) {
      _load(reset: true);
    } else if (!widget.asTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    }
  }

  void _focusField() {
    if (mounted) _focus.requestFocus();
  }

  @override
  void dispose() {
    widget.focusSignal?.removeListener(_focusField);
    _debounce?.cancel();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final q = text.trim();
      if (q == _query) return;
      _query = q;
      _refresh();
    });
  }

  void _submit(String text) {
    _debounce?.cancel();
    final q = text.trim();
    if (q.isNotEmpty) _remember(q);
    _query = q;
    _focus.unfocus();
    _load(reset: true);
  }

  /// Reload results, or fall back to the recent-searches view when there's
  /// nothing to search for.
  void _refresh() {
    if (_query.isEmpty && !_hasFilters) {
      _token++;
      setState(() {
        _items.clear();
        _total = 0;
        _loading = false;
        _searched = false;
      });
      return;
    }
    _load(reset: true);
  }

  Future<void> _remember(String q) async {
    final next = [q, ..._recent.where((r) => r.toLowerCase() != q.toLowerCase())].take(8).toList();
    setState(() => _recent = next);
    await AppStorage.setRecentSearches(next);
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || _items.length >= _total)) return;
    final token = ++_token;
    setState(() {
      _loading = true;
      _error = false;
      _searched = true;
      if (reset) {
        _items.clear();
        _total = 0;
      }
    });
    try {
      final page = await _api.getListings(
        skip: _items.length,
        take: _pageSize,
        search: _query,
        categoryId: _filters.categoryId,
        sort: _sort,
        minPrice: _filters.minPrice,
        maxPrice: _filters.maxPrice,
        condition: _filters.condition,
        onSale: _filters.onSale,
      );
      if (token != _token || !mounted) return;
      setState(() {
        _items.addAll(page.items);
        _total = page.items.isEmpty ? _items.length : page.total;
      });
    } catch (_) {
      if (token == _token && mounted) setState(() => _error = true);
    } finally {
      if (token == _token && mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 500 && !_loading && !_error && _items.length < _total) _load();
  }

  void _applyFilters(_Filters f) {
    setState(() => _filters = f);
    _refresh();
  }

  void _setSort(String s) {
    if (s == _sort) return;
    setState(() => _sort = s);
    _refresh();
  }

  Future<void> _openSortSheet() async {
    final p = Palette.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Sort by', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text)),
            ),
            for (final s in _sorts)
              ListTile(
                onTap: () => Navigator.of(ctx).pop(s.$1),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(
                  s.$2,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: s.$1 == _sort ? FontWeight.w600 : FontWeight.w400,
                    color: s.$1 == _sort ? p.accent : p.text,
                  ),
                ),
                trailing: s.$1 == _sort ? Icon(Icons.check_rounded, color: p.accent, size: 20) : null,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) _setSort(picked);
  }

  Future<void> _openFilterSheet() async {
    if (_categories == null) {
      final cats = await _api.getCategories().catchError((_) => <CategoryModel>[]);
      if (cats.isNotEmpty) _categories = cats;
    }
    if (!mounted) return;
    final result = await showModalBottomSheet<_Filters>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _FilterSheet(initial: _filters, categories: _categories ?? const []),
    );
    if (result != null) _applyFilters(result);
  }

  List<(String, VoidCallback)> _chips() {
    final f = _filters;
    String money(double v) => formatPrice(v, null).replaceFirst(currencySymbol(null), '');
    return [
      if (f.categoryId != null)
        (
          f.categoryName ?? 'Category',
          () => _applyFilters(
              _Filters(minPrice: f.minPrice, maxPrice: f.maxPrice, condition: f.condition, onSale: f.onSale))
        ),
      if (f.minPrice != null || f.maxPrice != null)
        (
          f.minPrice != null && f.maxPrice != null
              ? 'Price ${money(f.minPrice!)}–${money(f.maxPrice!)}'
              : f.minPrice != null
                  ? 'Price from ${money(f.minPrice!)}'
                  : 'Price up to ${money(f.maxPrice!)}',
          () => _applyFilters(_Filters(
              condition: f.condition, onSale: f.onSale, categoryId: f.categoryId, categoryName: f.categoryName))
        ),
      if (f.condition != null)
        (
          _conditions.firstWhere((c) => c.$1 == f.condition, orElse: () => (f.condition, f.condition!)).$2,
          () => _applyFilters(_Filters(
              minPrice: f.minPrice,
              maxPrice: f.maxPrice,
              onSale: f.onSale,
              categoryId: f.categoryId,
              categoryName: f.categoryName))
        ),
      if (f.onSale)
        (
          'On sale',
          () => _applyFilters(_Filters(
              minPrice: f.minPrice,
              maxPrice: f.maxPrice,
              condition: f.condition,
              categoryId: f.categoryId,
              categoryName: f.categoryName))
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final chips = _chips();
    final categoryName = _filters.categoryId != null ? (_filters.categoryName ?? 'this category') : null;
    return Scaffold(
      backgroundColor: p.bg,
      floatingActionButton: const CompareFab(),
      appBar: AppBar(
        backgroundColor: p.bg,
        automaticallyImplyLeading: !widget.asTab,
        titleSpacing: widget.asTab ? 16 : 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: _input,
              focusNode: _focus,
              onChanged: (t) {
                setState(() {});
                _onChanged(t);
              },
              onSubmitted: _submit,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 14.5, color: p.text),
              decoration: InputDecoration(
                hintText: categoryName != null ? 'Search in $categoryName' : 'Search for a product or brand',
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: p.textSecondary),
                suffixIcon: _input.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close_rounded, size: 18, color: p.textSecondary),
                        onPressed: () {
                          _input.clear();
                          _onChanged('');
                          setState(() {});
                        },
                      ),
                contentPadding: EdgeInsets.zero,
                fillColor: p.card,
              ),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(chips.isEmpty ? 52 : 92),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _ToolbarButton(
                        icon: Icons.tune_rounded,
                        label: _filters.count > 0 ? 'Filters (${_filters.count})' : 'Filters',
                        active: _filters.count > 0,
                        onTap: _openFilterSheet,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ToolbarButton(
                        icon: Icons.swap_vert_rounded,
                        label: _sortLabel(_sort),
                        active: _sort != 'newest',
                        onTap: _openSortSheet,
                      ),
                    ),
                  ],
                ),
              ),
              if (chips.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    children: [
                      for (final c in chips)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InputChip(
                            label: Text(c.$1),
                            onDeleted: c.$2,
                            onPressed: _openFilterSheet,
                            deleteIcon: const Icon(Icons.close_rounded, size: 15),
                            backgroundColor: p.accentSoft,
                            side: BorderSide.none,
                            labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: p.accent),
                            deleteIconColor: p.accent,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      TextButton(
                        onPressed: () => _applyFilters(const _Filters()),
                        style: TextButton.styleFrom(
                            minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 8)),
                        child: const Text('Clear all'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      body: CustomScrollView(
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          if (_searched)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _query.isNotEmpty
                            ? (_loading && _items.isEmpty ? 'Searching…' : '$_total results for "$_query"')
                            : (_filters.categoryName ?? 'All products'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _query.isNotEmpty
                            ? TextStyle(fontSize: 13.5, color: p.textSecondary)
                            : TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.text),
                      ),
                    ),
                    if (_query.isEmpty && !_loading)
                      Text('$_total items', style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                  ],
                ),
              ),
            ),
          if (!_searched)
            SliverToBoxAdapter(child: _recentList(p))
          else if (_items.isEmpty && _loading)
            const ProductGridSkeleton()
          else if (_items.isEmpty && _error)
            SliverToBoxAdapter(child: ErrorState(onRetry: () => _load(reset: true)))
          else if (_items.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: _query.isEmpty ? 'Nothing here yet' : 'No results for "$_query"',
                message: _filters.count > 0
                    ? 'Try removing a filter or searching for something else.'
                    : 'Try a different word or browse another category.',
                actionLabel: _filters.count > 0 ? 'Clear filters' : null,
                onAction: _filters.count > 0 ? () => _applyFilters(const _Filters()) : null,
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
          SliverToBoxAdapter(
            child: SizedBox(
              height: 96,
              child: _items.isNotEmpty && _loading
                  ? Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: p.accent),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentList(Palette p) {
    if (_recent.isEmpty) {
      return const EmptyState(
        icon: Icons.search_rounded,
        title: 'Find something you love',
        message: 'Search across every store on the Aptigen market.',
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text('Recent searches', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text)),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _recent = []);
                  AppStorage.setRecentSearches(const []);
                },
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recent
                .map((r) => ActionChip(
                      label: Text(r),
                      avatar: Icon(Icons.history_rounded, size: 16, color: p.textSecondary),
                      backgroundColor: p.card,
                      side: BorderSide(color: p.border),
                      labelStyle: TextStyle(fontSize: 13, color: p.text),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onPressed: () {
                        _input.text = r;
                        _submit(r);
                      },
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToolbarButton({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final fg = active ? p.accent : p.text;
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: active ? p.accent.withValues(alpha: 0.5) : p.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet: price range, condition, on sale only and category.
class _FilterSheet extends StatefulWidget {
  final _Filters initial;
  final List<CategoryModel> categories;
  const _FilterSheet({required this.initial, required this.categories});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final _min = TextEditingController(text: _fmt(widget.initial.minPrice));
  late final _max = TextEditingController(text: _fmt(widget.initial.maxPrice));
  late String? _condition = widget.initial.condition;
  late bool _onSale = widget.initial.onSale;
  late int? _categoryId = widget.initial.categoryId;
  late String? _categoryName = widget.initial.categoryName;

  static String _fmt(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.round().toString() : v.toString());

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  double? _parse(String s) {
    final v = double.tryParse(s.trim());
    return v == null || v < 0 ? null : v;
  }

  void _apply() {
    var min = _parse(_min.text);
    var max = _parse(_max.text);
    if (min != null && max != null && min > max) {
      final t = min;
      min = max;
      max = t;
    }
    Navigator.of(context).pop(_Filters(
      minPrice: min,
      maxPrice: max,
      condition: _condition,
      onSale: _onSale,
      categoryId: _categoryId,
      categoryName: _categoryName,
    ));
  }

  void _reset() {
    setState(() {
      _min.clear();
      _max.clear();
      _condition = null;
      _onSale = false;
      _categoryId = null;
      _categoryName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget heading(String t) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 10),
          child: Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text)),
        );
    Widget choice(String label, bool selected, VoidCallback onTap) => ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          backgroundColor: p.card,
          selectedColor: p.accentSoft,
          side: BorderSide(color: selected ? p.accent.withValues(alpha: 0.5) : p.border),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? p.accent : p.text,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        );
    Widget priceField(TextEditingController c, String hint) => Expanded(
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            style: TextStyle(fontSize: 14, color: p.text),
            decoration: InputDecoration(hintText: hint),
          ),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child:
                          Text('Filters', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text)),
                    ),
                    TextButton(onPressed: _reset, child: const Text('Reset')),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heading('Price'),
                      Row(
                        children: [
                          priceField(_min, 'Min'),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('to', style: TextStyle(fontSize: 13, color: p.textSecondary)),
                          ),
                          priceField(_max, 'Max'),
                        ],
                      ),
                      heading('Condition'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in _conditions)
                            choice(c.$2, _condition == c.$1, () => setState(() => _condition = c.$1)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        value: _onSale,
                        onChanged: (v) => setState(() => _onSale = v),
                        contentPadding: EdgeInsets.zero,
                        activeTrackColor: p.accent,
                        title: Text('On sale only',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text)),
                        subtitle: Text('Discounts and live flash sales',
                            style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                      ),
                      if (widget.categories.isNotEmpty) ...[
                        heading('Category'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            choice(
                                'Any',
                                _categoryId == null,
                                () => setState(() {
                                      _categoryId = null;
                                      _categoryName = null;
                                    })),
                            for (final c in widget.categories)
                              choice(
                                  c.name,
                                  _categoryId == c.id,
                                  () => setState(() {
                                        _categoryId = c.id;
                                        _categoryName = c.name;
                                      })),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: _apply, child: const Text('Show results')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
