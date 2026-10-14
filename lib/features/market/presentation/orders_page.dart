import 'package:flutter/material.dart';
import '../../../core/network/http_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../../shared/skeleton.dart';
import '../../auth/data/auth_service.dart';
import '../data/market_service.dart';
import '../models/market_extras.dart';
import '../models/order_model.dart';
import 'market_nav.dart';
import 'widgets/common.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _date(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  return '${l.day} ${_months[l.month - 1]} ${l.year}';
}

const _violet = Color(0xFF7C3AED);

(Color, String) _status(String s) => switch (s) {
      'paid' => (AppColors.accent, 'Paid'),
      'packaged' => (_violet, 'Packed'),
      'delivered' => (AppColors.success, 'Delivered'),
      'cancelled' => (AppColors.danger, 'Cancelled'),
      _ => (AppColors.warning, 'Order placed'),
    };

(Color, String) _refundStatus(String s) => switch (s) {
      'approved' => (AppColors.accent, 'Refund approved'),
      'rejected' => (AppColors.danger, 'Refund declined'),
      'refunded' => (AppColors.success, 'Refunded'),
      _ => (AppColors.warning, 'Refund requested'),
    };

String _methodLabel(String id) => switch (id) {
      'cash' => 'Cash on delivery',
      'mobile' => 'Mobile wallet',
      'bank' => 'Bank transfer',
      'card' => 'Card',
      _ => id,
    };

const _steps = [
  ('pending', 'Order placed'),
  ('paid', 'Payment confirmed'),
  ('packaged', 'Packed'),
  ('delivered', 'Delivered'),
];

/// Units of an item still refundable: bought minus anything already
/// refunded or in an open request.
int _refundableQty(OrderItem item, List<BuyerRefund> refunds) {
  final used = refunds.where((r) => r.isOpen).fold<int>(0, (n, r) => n + r.quantity);
  return (item.quantity - used).clamp(0, item.quantity);
}

/// Buyer's purchase history (GET /api/market/orders) — status timeline,
/// delivery and payment details, refunds and per-item reviews. Same as the
/// orders tab on web (me/profile/_components/OrdersTab.tsx).
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _api = MarketService();
  List<OrderModel>? _orders;
  List<BuyerRefund> _refunds = const [];
  bool _error = false;
  int? _expanded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    final refunds = _api.getMyRefunds().catchError((_) => _refunds);
    try {
      final o = await _api.getOrders();
      final r = await refunds;
      if (mounted) {
        setState(() {
          _orders = o;
          _refunds = r;
          _expanded ??= o.isEmpty ? null : o.first.id;
        });
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) await Session.expire();
      if (mounted) setState(() => _error = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget body;
    if (_orders == null && _error) {
      body = ErrorState(onRetry: _load);
    } else if (_orders == null) {
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: 12), child: Skeleton(height: 140))),
      );
    } else if (_orders!.isEmpty) {
      body = const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No orders yet',
        message: 'Orders you place on the market show up here.',
      );
    } else {
      body = RefreshIndicator(
        color: p.accent,
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: _orders!.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final o = _orders![i];
            return _OrderCard(
              order: o,
              expanded: _expanded == o.id,
              onToggle: () => setState(() => _expanded = _expanded == o.id ? null : o.id),
              refunds: _refunds.where((r) => r.orderId == o.id || o.items.any((it) => it.id == r.orderItemId)).toList(),
              onRefundCreated: (r) => setState(() => _refunds = [r, ..._refunds]),
            );
          },
        ),
      );
    }
    return Scaffold(appBar: AppBar(backgroundColor: p.bg, title: const Text('My orders')), body: body);
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final bool expanded;
  final VoidCallback onToggle;
  final List<BuyerRefund> refunds;
  final ValueChanged<BuyerRefund> onRefundCreated;
  const _OrderCard({
    required this.order,
    required this.expanded,
    required this.onToggle,
    required this.refunds,
    required this.onRefundCreated,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (color, label) = _status(order.status);
    final units = order.items.fold<int>(0, (n, i) => n + i.quantity);
    final thumbs = order.items.take(4).toList();
    final extra = order.items.length - thumbs.length;

    return Container(
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.orderNo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.text)),
                            Text('${_date(order.createdAt)} · $units item${units == 1 ? '' : 's'}',
                                style: TextStyle(fontSize: 12, color: p.textSecondary)),
                          ],
                        ),
                      ),
                      Pill(label, bg: color.withValues(alpha: 0.12), fg: color),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final it in thumbs)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(width: 36, height: 36, child: NetImage(it.thumbnailUrl, iconSize: 14)),
                          ),
                        ),
                      if (extra > 0) Text('+$extra', style: TextStyle(fontSize: 12, color: p.textSecondary)),
                      const Spacer(),
                      Text(formatPrice(order.total, order.currency),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text)),
                      const SizedBox(width: 2),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(Icons.expand_more_rounded, color: p.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: expanded ? _details(context, p) : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _details(BuildContext context, Palette p) {
    Widget money(String label, double v, {Color? color, bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: bold ? 14.5 : 13,
                        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                        color: bold ? p.text : p.textSecondary)),
              ),
              Text(
                v < 0 ? '-${formatPrice(-v, order.currency)}' : formatPrice(v, order.currency),
                style: TextStyle(
                    fontSize: bold ? 14.5 : 13,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    color: color ?? p.text),
              ),
            ],
          ),
        );

    final delivery = order.deliveryLine;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(color: p.border, height: 1),
          const SizedBox(height: 14),
          _Timeline(status: order.status),
          const SizedBox(height: 14),
          ...order.items.map((it) => _ItemRow(
                item: it,
                currency: order.currency,
                delivered: order.status == 'delivered',
                refundable: order.refundable,
                refunds: refunds.where((r) => r.orderItemId == it.id).toList(),
                onRefundCreated: onRefundCreated,
              )),
          Divider(color: p.border, height: 20),
          if (delivery != null || (order.shippingName?.isNotEmpty ?? false)) ...[
            _InfoBlock(
              icon: Icons.location_on_outlined,
              title: 'Delivery',
              lines: [
                [order.shippingName, order.shippingPhone].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                if (delivery != null) delivery,
                if (order.deliveryNote?.trim().isNotEmpty ?? false) 'Note: ${order.deliveryNote!.trim()}',
              ].where((s) => s.isNotEmpty).toList(),
            ),
            const SizedBox(height: 10),
          ],
          _InfoBlock(
            icon: Icons.payments_outlined,
            title: 'Payment',
            lines: [
              _methodLabel(order.paymentMethod),
              if (order.paymentReference?.trim().isNotEmpty ?? false) 'Transaction id ${order.paymentReference!.trim()}',
            ],
          ),
          Divider(color: p.border, height: 22),
          money('Subtotal', order.subtotal),
          if (order.discount > 0)
            money(
              order.couponCode != null && order.couponCode!.isNotEmpty ? 'Discount (${order.couponCode})' : 'Discount',
              -order.discount,
              color: AppColors.success,
            ),
          if (order.shipping > 0)
            money('Shipping', order.shipping)
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(child: Text('Shipping', style: TextStyle(fontSize: 13, color: p.textSecondary))),
                  const Text('Free',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.success)),
                ],
              ),
            ),
          money('Tax', order.tax),
          const SizedBox(height: 4),
          money('Total', order.total, bold: true),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final String status;
  const _Timeline({required this.status});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    if (status == 'cancelled') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cancel_outlined, size: 17, color: AppColors.danger),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'This order was cancelled. If you already paid, the seller will arrange a refund.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.danger),
              ),
            ),
          ],
        ),
      );
    }
    final current = _steps.indexWhere((s) => s.$1 == status).clamp(0, _steps.length - 1);
    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 18,
                child: Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(top: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= current ? p.accent : p.card,
                        border: Border.all(color: i <= current ? p.accent : p.border, width: 2),
                      ),
                    ),
                    if (i < _steps.length - 1)
                      Container(width: 2, height: 16, color: i < current ? p.accent : p.border),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _steps[i].$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: i == current ? FontWeight.w600 : FontWeight.w400,
                    color: i <= current ? p.text : p.textTertiary,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;
  const _InfoBlock({required this.icon, required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: p.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: p.textSecondary)),
              for (var i = 0; i < lines.length; i++)
                Text(
                  lines[i],
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: i == 0 ? FontWeight.w500 : FontWeight.w400,
                    color: i == 0 ? p.text : p.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends StatefulWidget {
  final OrderItem item;
  final String currency;
  final bool delivered;
  final bool refundable;
  final List<BuyerRefund> refunds;
  final ValueChanged<BuyerRefund> onRefundCreated;
  const _ItemRow({
    required this.item,
    required this.currency,
    required this.delivered,
    required this.refundable,
    required this.refunds,
    required this.onRefundCreated,
  });

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  late OrderItem _item = widget.item;

  @override
  void didUpdateWidget(covariant _ItemRow old) {
    super.didUpdateWidget(old);
    if (old.item != widget.item) _item = widget.item;
  }

  Future<void> _review() async {
    final review = await showModalBottomSheet<ItemReview>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReviewSheet(item: _item),
    );
    if (review != null && mounted) setState(() => _item = _item.withReview(review));
  }

  Future<void> _refund(int maxQty) async {
    final refund = await showModalBottomSheet<BuyerRefund>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RefundSheet(item: _item, maxQty: maxQty),
    );
    if (refund != null && mounted) {
      widget.onRefundCreated(refund);
      showToast(context, 'Refund request sent');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final review = _item.review;
    final original = _item.originalPrice != null && _item.originalPrice! > _item.price ? _item.originalPrice : null;
    final left = _refundableQty(_item, widget.refunds);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => openProduct(context, _item.listingId),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 48, height: 48, child: NetImage(_item.thumbnailUrl, iconSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: p.text)),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('${_item.quantity} × ${formatPrice(_item.price, widget.currency)}',
                              style: TextStyle(fontSize: 12, color: p.textSecondary)),
                          if (original != null)
                            Text(formatPrice(original, widget.currency),
                                style: TextStyle(
                                    fontSize: 12, color: p.textTertiary, decoration: TextDecoration.lineThrough)),
                          if (_item.discount > 0)
                            Text('-${formatPrice(_item.discount, widget.currency)} discount',
                                style: const TextStyle(fontSize: 12, color: AppColors.success)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(formatPrice(_item.lineTotal, widget.currency),
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.text)),
              ],
            ),
          ),
          if (widget.refunds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 60, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final r in widget.refunds) _RefundChip(refund: r, currency: widget.currency)],
              ),
            ),
          if (review != null)
            Padding(
              padding: const EdgeInsets.only(left: 60, top: 6),
              child: Row(
                children: [
                  ...List.generate(
                    5,
                    (i) => Icon(Icons.star_rounded, size: 15, color: i < review.rating ? AppColors.star : p.border),
                  ),
                  if (review.comment != null && review.comment!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(review.comment!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: p.textSecondary)),
                    ),
                  ],
                ],
              ),
            ),
          if ((review == null && widget.delivered) || (widget.refundable && left > 0))
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Wrap(
                children: [
                  if (review == null && widget.delivered)
                    TextButton.icon(
                      onPressed: _review,
                      icon: const Icon(Icons.star_outline_rounded, size: 17),
                      label: const Text('Write a review'),
                    ),
                  if (widget.refundable && left > 0)
                    TextButton.icon(
                      onPressed: () => _refund(left),
                      style: TextButton.styleFrom(foregroundColor: p.textSecondary),
                      icon: const Icon(Icons.replay_rounded, size: 17),
                      label: const Text('Request refund'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RefundChip extends StatelessWidget {
  final BuyerRefund refund;
  final String currency;
  const _RefundChip({required this.refund, required this.currency});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (color, label) = _refundStatus(refund.status);
    final meta = [
      '${refund.quantity} unit${refund.quantity == 1 ? '' : 's'}',
      if (refund.amount > 0) formatPrice(refund.amount, currency),
      if (refund.createdAt != null) _date(refund.createdAt),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Pill(label, bg: color.withValues(alpha: 0.12), fg: color),
              Text(meta, style: TextStyle(fontSize: 11.5, color: p.textSecondary)),
            ],
          ),
          if (refund.sellerNote != null && refund.sellerNote!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('Seller: ${refund.sellerNote!.trim()}',
                  style: TextStyle(fontSize: 12, height: 1.4, color: p.textSecondary)),
            ),
        ],
      ),
    );
  }
}

class _RefundSheet extends StatefulWidget {
  final OrderItem item;
  final int maxQty;
  const _RefundSheet({required this.item, required this.maxQty});

  @override
  State<_RefundSheet> createState() => _RefundSheetState();
}

class _RefundSheetState extends State<_RefundSheet> {
  static const _reasonMin = 5;
  static const _reasonMax = 1000;
  static const _methods = [
    ('original', 'Same way I paid'),
    ('cash', 'Cash'),
    ('mobile', 'Mobile wallet'),
    ('bank', 'Bank transfer'),
  ];

  final _reason = TextEditingController();
  late int _qty = widget.maxQty;
  String _method = 'original';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _reason.text.trim();
    if (text.length < _reasonMin) {
      setState(() => _error = 'Tell the seller a little more (at least $_reasonMin characters).');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await MarketService().requestRefund(
        orderItemId: widget.item.id,
        quantity: _qty,
        reason: text,
        method: _method,
      );
      if (!mounted) return;
      Navigator.of(context).pop(created.id != 0
          ? created
          : BuyerRefund(
              id: -DateTime.now().millisecondsSinceEpoch,
              orderId: 0,
              orderItemId: widget.item.id,
              quantity: _qty,
              amount: 0,
              reason: text,
              status: 'requested',
              method: _method,
              createdAt: DateTime.now(),
            ));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send your refund request. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: p.textSecondary)),
        );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Request a refund', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text)),
            const SizedBox(height: 4),
            Text(widget.item.title,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.textSecondary)),
            const SizedBox(height: 16),
            if (widget.maxQty > 1) ...[
              label('How many units?'),
              Row(
                children: [
                  QtyStepper(value: _qty, min: 1, max: widget.maxQty, onChanged: (q) => setState(() => _qty = q)),
                  const SizedBox(width: 10),
                  Text('of ${widget.maxQty}', style: TextStyle(fontSize: 13, color: p.textSecondary)),
                ],
              ),
              const SizedBox(height: 16),
            ],
            label('What went wrong?'),
            TextField(
              controller: _reason,
              minLines: 3,
              maxLines: 5,
              maxLength: _reasonMax,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              style: TextStyle(fontSize: 14, color: p.text),
              decoration: const InputDecoration(hintText: 'For example, the item arrived damaged or is not as described'),
            ),
            const SizedBox(height: 8),
            label('How should we refund you?'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (id, text) in _methods)
                  ChoiceChip(
                    label: Text(text),
                    selected: _method == id,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _method = id),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _method == id ? p.accent : p.text,
                    ),
                    backgroundColor: p.card,
                    selectedColor: p.accentSoft,
                    side: BorderSide(color: _method == id ? p.accent : p.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.danger)),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send request'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  final OrderItem item;
  const _ReviewSheet({required this.item});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Pick a star rating first.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final review = await MarketService().createReview(widget.item.id, _rating, _comment.text);
      if (mounted) Navigator.of(context).pop(review ?? ItemReview(id: 0, rating: _rating, comment: _comment.text.trim()));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't save your review. Try again.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rate this item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text)),
            const SizedBox(height: 4),
            Text(widget.item.title,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.textSecondary)),
            const SizedBox(height: 14),
            Wrap(
              children: List.generate(
                5,
                (i) => IconButton(
                  onPressed: () => setState(() => _rating = i + 1),
                  icon: Icon(
                    i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 34,
                    color: i < _rating ? AppColors.star : p.textTertiary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _comment,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 14, color: p.text),
              decoration: const InputDecoration(hintText: 'Share a few words about it (optional)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.danger)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
