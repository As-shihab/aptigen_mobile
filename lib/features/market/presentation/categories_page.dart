import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/skeleton.dart';
import '../data/market_service.dart';
import '../models/category_model.dart';
import 'market_nav.dart';
import 'widgets/category_icons.dart';
import 'widgets/common.dart';

/// Every market category that has active listings.
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _api = MarketService();
  List<CategoryModel>? _items;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final c = await _api.getCategories();
      if (mounted) setState(() => _items = c);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget body;
    if (_items == null && _error) {
      body = ErrorState(onRetry: _load);
    } else if (_items == null) {
      body = GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: List.generate(9, (_) => const Skeleton()),
      );
    } else if (_items!.isEmpty) {
      body = const EmptyState(icon: Icons.category_outlined, title: 'No categories yet');
    } else {
      final width = MediaQuery.sizeOf(context).width;
      body = RefreshIndicator(
        color: p.accent,
        onRefresh: _load,
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: width >= 600 ? 5 : 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.92,
          ),
          itemCount: _items!.length,
          itemBuilder: (_, i) {
            final c = _items![i];
            final tone = p.tone(i);
            return Material(
              color: p.card,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => openSearch(context, categoryId: c.id, categoryName: c.name),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.border),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
                        child: Icon(categoryIcon(c.icon), color: tone.fg, size: 23),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        c.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, height: 1.2, fontWeight: FontWeight.w600, color: p.text),
                      ),
                      const SizedBox(height: 2),
                      Text('${c.count} items', style: TextStyle(fontSize: 11, color: p.textSecondary)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.bg,
        title: const Text('Categories'),
        actions: [
          IconButton(onPressed: () => openSearch(context), icon: const Icon(Icons.search_rounded)),
          const SizedBox(width: 4),
        ],
      ),
      body: body,
    );
  }
}
