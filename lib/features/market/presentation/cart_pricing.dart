import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../data/cart_store.dart';
import '../data/local_lists.dart';
import '../data/market_service.dart';
import '../models/market_extras.dart';

// Shared cart pricing for the cart and checkout screens — port of
// frontend/app/components/market/CartPricing.tsx plus useCartQuote.

/// Keeps a server quote in step with the cart and the applied coupon.
/// Re-quotes ~350ms after the last change; `failed` means the latest request
/// did not go through (offline), so screens fall back to local totals.
class CartQuoteController extends ChangeNotifier {
  CartQuoteController() {
    CartStore.instance.addListener(_schedule);
    CouponStore.instance.addListener(_schedule);
    _schedule();
  }

  final _api = MarketService();
  Timer? _timer;
  int _seq = 0;
  String? _lastKey;
  bool _disposed = false;

  CartQuote? quote;
  bool loading = false;
  bool failed = false;

  String _key(List<CartItem> items, String? coupon) =>
      '${items.map((i) => '${i.id}x${i.quantity}').join(',')}|${coupon ?? ''}';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _schedule() {
    final items = CartStore.instance.value;
    final coupon = CouponStore.instance.value;
    final key = _key(items, coupon);
    if (key == _lastKey && (quote != null || loading)) return;
    _lastKey = key;
    _timer?.cancel();
    if (items.isEmpty) {
      _seq++;
      quote = null;
      loading = false;
      failed = false;
      _notify();
      return;
    }
    loading = true;
    _notify();
    _timer = Timer(const Duration(milliseconds: 350), () => _fetch(items, coupon));
  }

  /// Asks the server again right away (pull to refresh, retry).
  Future<void> refresh() async {
    _timer?.cancel();
    final items = CartStore.instance.value;
    if (items.isEmpty) return;
    _lastKey = _key(items, CouponStore.instance.value);
    loading = true;
    _notify();
    await _fetch(items, CouponStore.instance.value);
  }

  Future<void> _fetch(List<CartItem> items, String? coupon) async {
    final seq = ++_seq;
    try {
      final q = await _api.quote(
        items.map((i) => {'listing_id': i.id, 'quantity': i.quantity}).toList(),
        couponCode: coupon,
      );
      if (seq != _seq) return;
      quote = q;
      failed = false;
    } catch (_) {
      if (seq != _seq) return;
      failed = true;
    }
    loading = false;
    _notify();
  }

  /// Cart items the server says can't be bought right now.
  List<CartItem> unavailable(List<CartItem> items) {
    final ids = quote?.unavailable.toSet() ?? const <int>{};
    return items.where((i) => ids.contains(i.id)).toList();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    CartStore.instance.removeListener(_schedule);
    CouponStore.instance.removeListener(_schedule);
    super.dispose();
  }
}

/// Per-line unit price from the quote — flash price with the list price
/// struck, or "N at the sale price" when only some units qualify.
class QuoteLinePrice extends StatelessWidget {
  final QuoteLine? line;
  final CartItem item;
  final String suffix;
  final double fontSize;
  const QuoteLinePrice({super.key, required this.line, required this.item, this.suffix = ' each', this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final unit = line?.unitPrice ?? item.price;
    final orig = line?.originalPrice;
    final original = orig != null && orig > unit ? orig : null;
    final partial = line != null && original != null && line!.flashUnits > 0 && line!.flashUnits < line!.quantity;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 2,
      children: [
        Text(
          '${formatPrice(unit, item.currency)}$suffix',
          style: TextStyle(
            fontSize: fontSize,
            color: original != null ? AppColors.danger : p.textSecondary,
            fontWeight: original != null ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        if (original != null)
          Text(
            formatPrice(original, item.currency),
            style: TextStyle(fontSize: fontSize, color: p.textTertiary, decoration: TextDecoration.lineThrough),
          ),
        if (original != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded, size: fontSize + 2, color: AppColors.danger),
              Text(
                partial ? '${line!.flashUnits} at the sale price' : 'Flash price',
                style: TextStyle(fontSize: fontSize, color: AppColors.danger),
              ),
            ],
          ),
      ],
    );
  }
}

/// Coupon entry: apply a code, or show the applied one with the server's
/// verdict (`coupon.message`).
class CouponField extends StatefulWidget {
  final CartQuoteController controller;
  const CouponField({super.key, required this.controller});

  @override
  State<CouponField> createState() => _CouponFieldState();
}

class _CouponFieldState extends State<CouponField> {
  final _draft = TextEditingController();

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _apply() {
    final code = _draft.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    CouponStore.instance.apply(code);
    _draft.clear();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ValueListenableBuilder<String?>(
      valueListenable: CouponStore.instance,
      builder: (context, code, _) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          if (code == null) {
            return Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _draft,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _apply(),
                    autocorrect: false,
                    style: TextStyle(fontSize: 14, color: p.text),
                    decoration: const InputDecoration(hintText: 'Coupon code', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _draft,
                  builder: (_, v, __) => OutlinedButton(
                    onPressed: v.text.trim().isEmpty ? null : _apply,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      foregroundColor: p.accent,
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            );
          }
          final q = widget.controller.quote;
          final status = q?.coupon != null && q!.coupon!.code.toUpperCase() == code.toUpperCase() ? q.coupon : null;
          final checking = widget.controller.loading && status == null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sell_outlined, size: 18, color: p.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text)),
                  ),
                  TextButton.icon(
                    onPressed: CouponStore.instance.clear,
                    style: TextButton.styleFrom(foregroundColor: p.textSecondary, visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Remove'),
                  ),
                ],
              ),
              if (checking)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.6, color: p.textSecondary)),
                      const SizedBox(width: 8),
                      Text('Checking code', style: TextStyle(fontSize: 12, color: p.textSecondary)),
                    ],
                  ),
                )
              else if (status != null && status.message.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: (status.applied ? AppColors.success : AppColors.danger).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        status.applied ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                        size: 15,
                        color: status.applied ? AppColors.success : AppColors.danger,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(status.message,
                            style: TextStyle(
                                fontSize: 12, color: status.applied ? AppColors.success : AppColors.danger)),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Subtotal / discount (by store and promotion) / shipping / tax / total.
/// Uses the server quote; with no quote (offline) it shows local estimates.
class QuoteTotals extends StatelessWidget {
  final CartQuoteController controller;
  final List<CartItem> items;
  final String taxLabel;
  const QuoteTotals({super.key, required this.controller, required this.items, this.taxLabel = 'Tax'});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final q = controller.failed ? null : controller.quote;
    final local = CartTotals.of(items);
    final currency = q?.currency ?? (items.isEmpty ? null : items.first.currency);

    Widget row(String label, String value, {bool bold = false, Color? valueColor}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: bold ? 16 : 14,
                        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                        color: bold ? p.text : p.textSecondary)),
              ),
              Text(value,
                  style: TextStyle(
                      fontSize: bold ? 16 : 14,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                      color: valueColor ?? p.text)),
            ],
          ),
        );

    final subtotal = q?.subtotal ?? local.subtotal;
    final discount = q?.discount ?? 0;
    final shipping = q?.shipping ?? local.shipping;
    final tax = q?.tax ?? local.tax;
    final total = q?.total ?? local.total;
    final promos = (q?.promotions ?? const <QuotePromotion>[]).where((x) => x.discount > 0 || x.freeShipping).toList();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: controller.loading ? 0.6 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row('Subtotal', formatPrice(subtotal, currency)),
          if (discount > 0) row('Discount', '-${formatPrice(discount, currency)}', valueColor: AppColors.success),
          for (final promo in promos)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${promo.storeName ?? 'Store'} · ${promo.name}${promo.code != null ? ' (${promo.code})' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: p.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    promo.discount > 0 ? '-${formatPrice(promo.discount, currency)}' : 'Free shipping',
                    style: TextStyle(fontSize: 12, color: p.textSecondary),
                  ),
                ],
              ),
            ),
          row('Shipping', shipping == 0 ? 'Free' : formatPrice(shipping, currency),
              valueColor: shipping == 0 ? AppColors.success : null),
          row(taxLabel, formatPrice(tax, currency)),
          Divider(color: p.border, height: 20),
          row('Total', formatPrice(total, currency), bold: true),
          if (q == null && controller.failed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.cloud_off_rounded, size: 16, color: p.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Couldn't reach the market. These are estimates; discounts show once you're back online.",
                      style: TextStyle(fontSize: 12, color: p.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: controller.refresh,
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Notice for cart lines the server won't sell, with a remove action each.
class UnavailableNotice extends StatelessWidget {
  final List<CartItem> items;
  const UnavailableNotice({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    const fg = AppColors.warning;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(color: fg.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, size: 17, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  items.length == 1 ? 'One item is no longer available' : '${items.length} items are no longer available',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg),
                ),
              ),
            ],
          ),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(left: 25),
              child: Row(
                children: [
                  Expanded(
                    child: Text(i.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: fg)),
                  ),
                  TextButton(
                    onPressed: () => CartStore.instance.remove(i.id),
                    style: TextButton.styleFrom(foregroundColor: fg, visualDensity: VisualDensity.compact),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(left: 25, right: 6),
            child: Text('They are left out of your total. Remove them to check out.',
                style: TextStyle(fontSize: 12, color: fg)),
          ),
        ],
      ),
    );
  }
}
