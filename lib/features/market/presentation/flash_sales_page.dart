import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/market_service.dart';
import '../models/market_extras.dart';
import 'market_nav.dart';
import 'widgets/common.dart';
import 'widgets/flash_sale_card.dart';

/// Every live flash sale, ending soonest first — port of
/// market/flash-sales/flash-sales.client.tsx.
class FlashSalesPage extends StatefulWidget {
  const FlashSalesPage({super.key});

  @override
  State<FlashSalesPage> createState() => _FlashSalesPageState();
}

class _FlashSalesPageState extends State<FlashSalesPage> {
  final _api = MarketService();
  List<FlashSale>? _sales;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final list = await _api.getFlashSales(take: 50);
      list.sort((a, b) => a.endsAt.compareTo(b.endsAt));
      if (mounted) setState(() => _sales = list);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final sales = _sales;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(backgroundColor: p.bg, title: const Text('Flash sales')),
      body: RefreshIndicator(
        color: p.accent,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  'Limited-time prices from our sellers, while stock lasts.',
                  style: TextStyle(fontSize: 13.5, color: p.textSecondary),
                ),
              ),
            ),
            if (sales == null && _error)
              SliverToBoxAdapter(child: ErrorState(onRetry: _load))
            else if (sales == null)
              const ProductGridSkeleton()
            else if (sales.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.bolt_rounded,
                  title: 'No flash sales right now',
                  message: 'Check back soon, or browse the deals sellers are running today.',
                  actionLabel: 'See deals',
                  onAction: () => openSearch(context, onSale: true),
                ),
              )
            else
              for (final sale in sales) ..._saleSection(context, sale),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  List<Widget> _saleSection(BuildContext context, FlashSale sale) {
    final p = Palette.of(context);
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text),
                    ),
                    if (sale.description != null && sale.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        sale.description!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, height: 1.4, color: p.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SaleCountdownChip(endsAt: sale.endsAt),
            ],
          ),
        ),
      ),
      if (sale.items.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('No products in this sale yet.', style: TextStyle(fontSize: 13, color: p.textSecondary)),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: flashGridDelegate(context),
            delegate: SliverChildBuilderDelegate(
              (_, i) => FlashSaleCard(sale.items[i]),
              childCount: sale.items.length,
            ),
          ),
        ),
    ];
  }
}
