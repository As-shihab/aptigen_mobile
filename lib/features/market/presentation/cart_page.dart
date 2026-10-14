import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../data/cart_store.dart';
import '../models/market_extras.dart';
import 'cart_pricing.dart';
import 'checkout_page.dart';
import 'market_nav.dart';
import 'widgets/common.dart';

/// Cart — port of market/cart/page.tsx. Lives as a bottom tab, and can also
/// be pushed on its own (`standalone`) from a product page. Prices come from
/// the server quote (flash prices, promotions, coupon); local totals are the
/// fallback when the quote can't be fetched.
class CartPage extends StatefulWidget {
  final bool standalone;
  final VoidCallback? onShop;
  const CartPage({super.key, this.standalone = false, this.onShop});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _quote = CartQuoteController();

  @override
  void dispose() {
    _quote.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await CartStore.instance.refresh();
    await _quote.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: CartStore.instance,
      builder: (context, items, _) => ListenableBuilder(
        listenable: _quote,
        builder: (context, _) {
          final quote = _quote.failed ? null : _quote.quote;
          final unavailable = _quote.unavailable(items);
          final currency = quote?.currency ?? CartStore.instance.currency;
          final total = quote?.total ?? CartStore.instance.totals.total;
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: widget.standalone,
              backgroundColor: p.bg,
              title: Text(items.isEmpty ? 'Cart' : 'Cart (${CartStore.instance.count})'),
            ),
            body: items.isEmpty
                ? Center(
                    child: EmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Your cart is empty',
                      message: 'Add something from the market to see it here.',
                      actionLabel: 'Shop the market',
                      onAction: () {
                        if (widget.standalone) {
                          Navigator.of(context).popUntil((r) => r.isFirst);
                        }
                        widget.onShop?.call();
                      },
                    ),
                  )
                : RefreshIndicator(
                    color: p.accent,
                    onRefresh: _refresh,
                    child: ListView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        if (unavailable.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: UnavailableNotice(items: unavailable),
                          ),
                        ...items.map((i) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _CartLine(
                                item: i,
                                line: quote?.lineFor(i.id),
                                unavailable: unavailable.contains(i),
                              ),
                            )),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: p.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: p.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Order summary',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text)),
                              const SizedBox(height: 12),
                              CouponField(controller: _quote),
                              const SizedBox(height: 12),
                              QuoteTotals(controller: _quote, items: items, taxLabel: 'Estimated tax'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            bottomNavigationBar: items.isEmpty
                ? null
                : Container(
                    padding: EdgeInsets.fromLTRB(
                        16, 12, 16, 12 + (widget.standalone ? MediaQuery.paddingOf(context).bottom : 0)),
                    decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.border))),
                    child: Row(
                      children: [
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total', style: TextStyle(fontSize: 12, color: p.textSecondary)),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(formatPrice(total, currency),
                                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: p.text)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: unavailable.isNotEmpty
                                ? null
                                : () => Navigator.of(context)
                                    .push(MaterialPageRoute(builder: (_) => const CheckoutPage())),
                            child: Text(unavailable.isNotEmpty ? 'Remove unavailable items' : 'Checkout',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
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

class _CartLine extends StatelessWidget {
  final CartItem item;
  final QuoteLine? line;
  final bool unavailable;
  const _CartLine({required this.item, required this.line, required this.unavailable});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final lineTotal = line?.lineTotal ?? item.lineTotal;
    return Dismissible(
      key: ValueKey('cart-${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => CartStore.instance.remove(item.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Opacity(
        opacity: unavailable ? 0.55 : 1,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => openProduct(context, item.id),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(width: 84, height: 84, child: NetImage(item.image)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11.5, color: p.textSecondary)),
                              const SizedBox(height: 2),
                              GestureDetector(
                                onTap: () => openProduct(context, item.id),
                                child: Text(
                                  item.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14, height: 1.3, fontWeight: FontWeight.w600, color: p.text),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            color: p.textTertiary,
                            onPressed: () => CartStore.instance.remove(item.id),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (unavailable)
                      const Text('No longer available', style: TextStyle(fontSize: 12, color: AppColors.warning))
                    else
                      QuoteLinePrice(line: line, item: item),
                    if (item.minOrder > 1)
                      Text('Min order ${item.minOrder}', style: TextStyle(fontSize: 11.5, color: p.textTertiary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        QtyStepper(
                          compact: true,
                          value: item.quantity,
                          min: item.minOrder,
                          onChanged: (q) => CartStore.instance.setQuantity(item.id, q),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            formatPrice(lineTotal, item.currency),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text),
                          ),
                        ),
                      ],
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
