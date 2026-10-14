import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/http_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../account/address_form.dart';
import '../../auth/data/auth_service.dart';
import '../data/cart_store.dart';
import '../data/local_lists.dart';
import '../data/market_service.dart';
import '../models/market_extras.dart';
import '../models/order_model.dart';
import 'cart_pricing.dart';
import 'orders_page.dart';
import 'widgets/common.dart';

/// Checkout — port of market/payment/page.tsx: delivery → payment → review.
/// Prices, accepted payment methods and store payment details all come from
/// the server quote; needs a signed-in buyer.
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _Method {
  final String id;
  final IconData icon;
  final String label;
  final String desc;
  final int tone;
  const _Method(this.id, this.icon, this.label, this.desc, this.tone);
}

const _methods = <_Method>[
  _Method('cash', Icons.payments_outlined, 'Cash on delivery', 'Pay the courier when your order arrives', 3),
  _Method('mobile', Icons.phone_iphone_rounded, 'Mobile wallet',
      'Send the payment from your wallet, then enter the transaction id', 2),
  _Method('bank', Icons.account_balance_outlined, 'Bank transfer',
      'Transfer to the store account, then enter the transaction id', 5),
  _Method('card', Icons.credit_card_rounded, 'Credit or debit card', 'Pay now with your card', 4),
];

String methodLabel(String id) => switch (id) {
      'cash' => 'Cash on delivery',
      'mobile' => 'Mobile wallet',
      'bank' => 'Bank transfer',
      'card' => 'Card',
      _ => id,
    };

const _unavailableReason = 'Not accepted by every store in your cart';
const _referenceMax = 100;
const _noteMax = 300;

class _Delivery {
  final String fullName;
  final String phone;
  final String line;
  const _Delivery(this.fullName, this.phone, this.line);
}

class _Confirmed {
  final PlacedOrder order;
  final String method;
  final _Delivery delivery;
  const _Confirmed(this.order, this.method, this.delivery);
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _api = MarketService();
  final _quote = CartQuoteController();

  int _step = 1;

  // Delivery
  List<BuyerAddress> _addresses = const [];
  bool _addressesLoading = true;
  int? _selectedId; // null → new address
  final _draft = AddressDraft();
  Map<String, String> _draftErrors = const {};
  bool _saveAddress = true;
  bool _savingAddress = false;
  String? _deliveryError;
  final _note = TextEditingController();

  // Payment
  String _chosenMethod = 'cash';
  final _reference = TextEditingController();
  String? _paymentError;

  // Submit
  bool _submitting = false;
  String? _error;
  _Confirmed? _confirmed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!Session.isSignedIn) {
        final ok = await ensureSignedIn(context, reason: 'Sign in to check out');
        if (!ok) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
      }
      _loadAddresses();
    });
  }

  @override
  void dispose() {
    _quote.dispose();
    _draft.dispose();
    _note.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    try {
      final list = await _api.getAddresses();
      if (!mounted) return;
      final def = list.where((a) => a.isDefault).firstOrNull ?? list.firstOrNull;
      setState(() {
        _addresses = list;
        _selectedId = def?.id;
      });
    } catch (_) {
      // Not fatal — the buyer can still type an address.
    } finally {
      if (mounted) setState(() => _addressesLoading = false);
    }
  }

  BuyerAddress? get _selectedAddress =>
      _selectedId == null ? null : _addresses.where((a) => a.id == _selectedId).firstOrNull;

  _Delivery? get _delivery {
    final a = _selectedAddress;
    if (a != null) return _Delivery(a.fullName, a.phone, a.oneLine);
    if (_selectedId == null && _draft.validate().isEmpty) {
      return _Delivery(_draft.fullName.text.trim(), _draft.phone.text.trim(), _draft.oneLine);
    }
    return null;
  }

  // ── Payment helpers ─────────────────────────────────────────────────

  QuotePaymentMethod? _info(String id) => _quote.failed ? null : _quote.quote?.method(id);
  bool _available(String id) => _info(id)?.available ?? false;
  bool get _hasQuote => !_quote.failed && _quote.quote != null;

  /// Falls back to the first accepted method when the chosen one stops
  /// being available (e.g. the cart changed).
  String get _method {
    if (!_hasQuote || _available(_chosenMethod)) return _chosenMethod;
    return _methods.where((m) => _available(m.id)).firstOrNull?.id ?? _chosenMethod;
  }

  List<QuoteGateway> get _gateways => _info(_method)?.gateways ?? const [];
  bool get _isTransfer => _method == 'mobile' || _method == 'bank';
  bool get _needsReference => _isTransfer && _gateways.isNotEmpty;
  bool get _noMethod => _hasQuote && !_methods.any((m) => _available(m.id));

  /// Only send a coupon the server actually applied.
  String? get _appliedCoupon {
    final c = _hasQuote ? _quote.quote!.coupon : null;
    return c != null && c.applied ? c.code : null;
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _error = null;
    });
  }

  Future<void> _continueFromDelivery() async {
    setState(() => _deliveryError = null);
    if (_selectedId == null) {
      final errs = _draft.validate();
      setState(() => _draftErrors = errs);
      if (errs.isNotEmpty) {
        setState(() => _deliveryError = 'Please fix the highlighted fields.');
        return;
      }
      if (_saveAddress) {
        setState(() => _savingAddress = true);
        try {
          final created = await _api.createAddress(_draft.toInput(isDefault: _addresses.isEmpty));
          if (created.id != 0 && mounted) {
            setState(() {
              _addresses = [..._addresses, created];
              _selectedId = created.id;
            });
          }
        } on ApiException catch (e) {
          if (e.statusCode == 401) {
            await Session.expire();
            if (mounted) {
              setState(() {
                _savingAddress = false;
                _deliveryError = 'Your session expired. Sign in again to continue.';
              });
            }
            return;
          }
          // Not fatal — the address still goes with the order as a one-off.
          if (mounted) setState(() => _saveAddress = false);
        } catch (_) {
          if (mounted) setState(() => _saveAddress = false);
        } finally {
          if (mounted) setState(() => _savingAddress = false);
        }
      }
    } else if (_selectedAddress == null) {
      setState(() => _deliveryError = 'Choose a delivery address.');
      return;
    }
    if (_note.text.length > _noteMax) {
      setState(() => _deliveryError = 'Delivery note can be at most $_noteMax characters.');
      return;
    }
    if (mounted) _goTo(2);
  }

  void _continueFromPayment() {
    setState(() => _paymentError = null);
    String? err;
    if (!_hasQuote) {
      err = _quote.failed
          ? 'We could not price your cart right now. Try again.'
          : 'Still pricing your cart. Please wait a moment.';
    } else if (!_available(_method)) {
      err = 'Choose a payment method every store in your cart accepts.';
    } else if (_needsReference && _reference.text.trim().isEmpty) {
      err = 'Enter the transaction id from your payment.';
    } else if (_reference.text.trim().length > _referenceMax) {
      err = 'Transaction id can be at most $_referenceMax characters.';
    }
    if (err != null) {
      setState(() => _paymentError = err);
      return;
    }
    _goTo(3);
  }

  Future<void> _place() async {
    final items = CartStore.instance.value;
    final delivery = _delivery;
    if (items.isEmpty || _submitting || delivery == null || !_hasQuote) return;
    if (_needsReference && _reference.text.trim().isEmpty) {
      _goTo(2);
      setState(() => _paymentError = 'Enter the transaction id from your payment.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final method = _method;
    try {
      final address = _selectedAddress;
      final order = await _api.checkout(
        items.map((i) => {'listing_id': i.id, 'quantity': i.quantity}).toList(),
        method,
        addressId: address?.id,
        shipping: address == null ? _draft.toShipping() : null,
        deliveryNote: _note.text,
        couponCode: _appliedCoupon,
        paymentReference: _isTransfer ? _reference.text : null,
      );
      CartStore.instance.clear();
      CouponStore.instance.clear();
      if (mounted) setState(() => _confirmed = _Confirmed(order, method, delivery));
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await Session.expire();
        if (mounted) setState(() => _error = 'Your session expired. Sign in again to place the order.');
      } else {
        if (mounted) setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong placing your order. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    if (_confirmed != null) return _Success(confirmed: _confirmed!);

    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: CartStore.instance,
      builder: (context, items, _) => ListenableBuilder(
        listenable: _quote,
        builder: (context, _) {
          if (items.isEmpty) {
            return Scaffold(
              appBar: AppBar(backgroundColor: p.bg, title: const Text('Checkout')),
              body: Center(
                child: EmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Your cart is empty',
                  message: 'Add something to your cart before checking out.',
                  actionLabel: 'Start shopping',
                  onAction: () => Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              ),
            );
          }
          final unavailable = _quote.unavailable(items);
          final currency = _hasQuote ? _quote.quote!.currency : CartStore.instance.currency;

          final Widget body = switch (_step) {
            1 => _deliveryStep(p),
            2 => _paymentStep(p),
            _ => _reviewStep(p, items, unavailable),
          };

          final (String label, VoidCallback? onTap, bool busy) = switch (_step) {
            1 => (_savingAddress ? 'Saving address' : 'Continue to payment', _continueFromDelivery, _savingAddress),
            2 => ('Review order', _continueFromPayment, false),
            _ => (
                _hasQuote ? 'Place order · ${formatPrice(_quote.quote!.total, currency)}' : 'Pricing your cart',
                (_delivery == null || !_hasQuote || _quote.loading || unavailable.isNotEmpty || _noMethod)
                    ? null
                    : _place,
                _submitting,
              ),
          };

          return PopScope(
            canPop: _step == 1,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && !_submitting) _goTo(_step - 1);
            },
            child: Scaffold(
              appBar: AppBar(backgroundColor: p.bg, title: const Text('Checkout')),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: _StepIndicator(step: _step, onGo: _submitting ? null : _goTo),
                  ),
                  Expanded(
                    child: ListView(
                      key: ValueKey('step-$_step'),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [body],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: Container(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
                decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.border))),
                child: Row(
                  children: [
                    if (_step > 1) ...[
                      OutlinedButton(
                        onPressed: busy ? null : () => _goTo(_step - 1),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18)),
                        child: const Text('Back'),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: busy ? null : onTap,
                        child: busy
                            ? const SizedBox(
                                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Step 1: delivery ────────────────────────────────────────────────

  Widget _deliveryStep(Palette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle('Delivery address'),
        if (_addressesLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else ...[
          for (final a in _addresses)
            _ChoiceCard(
              selected: _selectedId == a.id,
              onTap: () => setState(() {
                _selectedId = a.id;
                _deliveryError = null;
              }),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          (a.label?.trim().isNotEmpty ?? false) ? a.label! : a.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text),
                        ),
                      ),
                      if (a.isDefault) ...[
                        const SizedBox(width: 8),
                        Pill('Default', bg: p.accentSoft, fg: p.accent),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${a.fullName} · ${a.phone}', style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                  Text(a.oneLine, style: TextStyle(fontSize: 12.5, height: 1.4, color: p.textSecondary)),
                ],
              ),
            ),
          if (_addresses.isNotEmpty)
            _ChoiceCard(
              selected: _selectedId == null,
              onTap: () => setState(() {
                _selectedId = null;
                _deliveryError = null;
              }),
              child: Row(
                children: [
                  Icon(Icons.add_location_alt_outlined, size: 18, color: p.accent),
                  const SizedBox(width: 8),
                  Text('Use a new address',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text)),
                ],
              ),
            ),
          if (_selectedId == null) ...[
            const SizedBox(height: 6),
            AddressFields(
              draft: _draft,
              errors: _draftErrors,
              showLabel: false,
              onEdited: (k) {
                if (_draftErrors.containsKey(k)) setState(() => _draftErrors = Map.of(_draftErrors)..remove(k));
              },
            ),
            CheckboxListTile(
              value: _saveAddress,
              onChanged: (v) => setState(() => _saveAddress = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              activeColor: p.accent,
              title: Text('Save this address for next time', style: TextStyle(fontSize: 13.5, color: p.text)),
            ),
          ],
        ],
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Delivery note'),
            TextSpan(text: ' (optional)', style: TextStyle(color: p.textTertiary)),
          ]),
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: p.textSecondary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _note,
          maxLines: 3,
          minLines: 2,
          maxLength: _noteMax,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(fontSize: 14, color: p.text),
          decoration: const InputDecoration(hintText: 'Landmark, gate code or the best time to deliver'),
        ),
        if (_deliveryError != null) _ErrorBox(_deliveryError!),
      ],
    );
  }

  // ── Step 2: payment ─────────────────────────────────────────────────

  Widget _paymentStep(Palette p) {
    final method = _method;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle('Payment method'),
        if (!_hasQuote)
          _quote.failed
              ? _ErrorBox('We could not price your cart right now.', onRetry: _quote.refresh)
              : Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8)),
                      const SizedBox(width: 10),
                      Text('Checking which payment methods the stores accept',
                          style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                    ],
                  ),
                ),
        for (final m in _methods)
          _MethodTile(
            icon: m.icon,
            tone: p.tone(m.tone),
            title: m.label,
            subtitle: _hasQuote && !_available(m.id) ? _unavailableReason : m.desc,
            selected: method == m.id,
            disabled: !_hasQuote || !_available(m.id),
            onTap: () => setState(() {
              _chosenMethod = m.id;
              _paymentError = null;
            }),
          ),
        if (_noMethod)
          const _ErrorBox(
              'No payment method is accepted by every store in your cart. Try checking out items from each store separately.'),
        if (_isTransfer && _hasQuote && _available(method)) ...[
          const SizedBox(height: 6),
          if (_gateways.isNotEmpty) ...[
            Text(
              '${method == 'bank' ? 'Transfer the amount to the account below' : 'Send the payment to the number below'}'
              '${_gateways.map((g) => g.storeName).toSet().length > 1 ? ' for each store in your order.' : '.'}',
              style: TextStyle(fontSize: 13, color: p.textSecondary),
            ),
            const SizedBox(height: 10),
            for (final g in _gateways) _GatewayCard(gateway: g, method: method),
          ],
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Transaction id'),
              if (!_needsReference) TextSpan(text: ' (optional)', style: TextStyle(color: p.textTertiary)),
            ]),
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: p.textSecondary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _reference,
            autocorrect: false,
            inputFormatters: [LengthLimitingTextInputFormatter(_referenceMax)],
            onChanged: (_) {
              if (_paymentError != null) setState(() => _paymentError = null);
            },
            style: TextStyle(fontSize: 14, color: p.text),
            decoration: const InputDecoration(hintText: 'From your payment receipt'),
          ),
        ],
        if (method == 'cash' && _hasQuote && _available('cash'))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Pay in cash when your order arrives. Please have the exact amount ready for the courier.',
              style: TextStyle(fontSize: 12.5, height: 1.45, color: p.textSecondary),
            ),
          ),
        if (_paymentError != null) _ErrorBox(_paymentError!),
      ],
    );
  }

  // ── Step 3: review ──────────────────────────────────────────────────

  Widget _reviewStep(Palette p, List<CartItem> items, List<CartItem> unavailable) {
    final delivery = _delivery;
    final quote = _hasQuote ? _quote.quote : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryBlock(
          title: 'Deliver to',
          onEdit: () => _goTo(1),
          child: delivery == null
              ? Text('Add a delivery address', style: TextStyle(fontSize: 13, color: AppColors.danger))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(delivery.fullName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text)),
                    Text(delivery.phone, style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                    Text(delivery.line, style: TextStyle(fontSize: 12.5, height: 1.4, color: p.textSecondary)),
                    if (_note.text.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Note: ${_note.text.trim()}',
                            style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        _SummaryBlock(
          title: 'Payment',
          onEdit: () => _goTo(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(methodLabel(_method), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text)),
              if (_isTransfer && _reference.text.trim().isNotEmpty)
                Text('Transaction id ${_reference.text.trim()}',
                    style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (unavailable.isNotEmpty) ...[
          UnavailableNotice(items: unavailable),
          const SizedBox(height: 12),
        ],
        _SectionTitle('Items (${items.length})'),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 48, height: 48, child: NetImage(i.image, iconSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: p.text)),
                      Text('Qty ${i.quantity}', style: TextStyle(fontSize: 12, color: p.textSecondary)),
                      QuoteLinePrice(line: quote?.lineFor(i.id), item: i, fontSize: 11.5),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(formatPrice(quote?.lineFor(i.id)?.lineTotal ?? i.lineTotal, i.currency),
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.text)),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Order summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text)),
              const SizedBox(height: 12),
              CouponField(controller: _quote),
              const SizedBox(height: 12),
              QuoteTotals(controller: _quote, items: items),
            ],
          ),
        ),
        if (_error != null) _ErrorBox(_error!),
      ],
    );
  }
}

// ── Pieces ────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int step;
  final ValueChanged<int>? onGo;
  const _StepIndicator({required this.step, required this.onGo});

  static const _labels = ['Delivery', 'Payment', 'Review'];

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final children = <Widget>[];
    for (var i = 0; i < _labels.length; i++) {
      final id = i + 1;
      final done = id < step;
      final active = id == step;
      children.add(GestureDetector(
        onTap: done && onGo != null ? () => onGo!(id) : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: done || active ? p.accent : p.fill, shape: BoxShape.circle),
              child: done
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : Text('$id',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600, color: active ? Colors.white : p.textSecondary)),
            ),
            const SizedBox(width: 6),
            Text(
              _labels[i],
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? p.text : (done ? p.accent : p.textSecondary),
              ),
            ),
          ],
        ),
      ));
      if (i < _labels.length - 1) {
        children.add(Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: done ? p.accent : p.border,
          ),
        ));
      }
    }
    return Row(children: children);
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.of(context).text)),
      );
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _ErrorBox(this.message, {this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        padding: EdgeInsets.fromLTRB(12, onRetry == null ? 12 : 4, onRetry == null ? 12 : 4, onRetry == null ? 12 : 4),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13, color: AppColors.danger))),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Retry'),
              ),
          ],
        ),
      );
}

class _ChoiceCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  const _ChoiceCard({required this.selected, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? p.accent : p.border, width: selected ? 1.6 : 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: child),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? p.accent : p.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  final String title;
  final VoidCallback onEdit;
  final Widget child;
  const _SummaryBlock({required this.title, required this.onEdit, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 12),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: TextStyle(fontSize: 12.5, color: p.textSecondary))),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: const Text('Change'),
              ),
            ],
          ),
          Padding(padding: const EdgeInsets.only(right: 10), child: child),
        ],
      ),
    );
  }
}

class _GatewayCard extends StatelessWidget {
  final QuoteGateway gateway;
  final String method;
  const _GatewayCard({required this.gateway, required this.method});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final g = gateway;
    final title = [g.provider, g.label].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');
    Widget kv(String k, Widget v) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 112, child: Text(k, style: TextStyle(fontSize: 12.5, color: p.textSecondary))),
              Expanded(child: v),
            ],
          ),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (g.storeName != null) Text(g.storeName!, style: TextStyle(fontSize: 12, color: p.textSecondary)),
          Text(title.isEmpty ? methodLabel(method) : title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text)),
          if (g.accountName != null && g.accountName!.isNotEmpty)
            kv('Account name', Text(g.accountName!, style: TextStyle(fontSize: 13, color: p.text))),
          if (g.accountNumber != null && g.accountNumber!.isNotEmpty)
            kv(
              method == 'bank' ? 'Account number' : 'Number',
              Row(
                children: [
                  Flexible(
                    child: SelectableText(g.accountNumber!,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.text)),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      color: p.accent,
                      tooltip: 'Copy',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: g.accountNumber!));
                        if (context.mounted) showToast(context, 'Copied');
                      },
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ),
                ],
              ),
            ),
          if (g.instructions != null && g.instructions!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(g.instructions!, style: TextStyle(fontSize: 12, height: 1.45, color: p.textSecondary)),
            ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final String title;
  final String subtitle;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  const _MethodTile({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.selected,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final active = selected && !disabled;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? p.accent : p.border, width: active ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: tone.fg, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text)),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                active ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: active ? p.accent : p.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Success extends StatelessWidget {
  final _Confirmed confirmed;
  const _Success({required this.confirmed});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final order = confirmed.order;
    final paymentNote = order.status != 'pending'
        ? 'Payment received'
        : confirmed.method == 'cash'
            ? 'Pay when your order arrives'
            : 'The seller will confirm your payment';
    Widget row(String k, List<String> v) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(k, style: TextStyle(fontSize: 13, color: p.textSecondary)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < v.length; i++)
                      Text(
                        v[i],
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: i == 0 ? 13.5 : 12,
                          fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400,
                          color: i == 0 ? p.text : p.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).popUntil((r) => r.isFirst);
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: AppColors.success, size: 34),
                ),
              ),
              const SizedBox(height: 18),
              Text('Thank you, your order is placed',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.text)),
              const SizedBox(height: 6),
              Text(
                'We have sent it to the seller. You can follow its progress from your orders.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, height: 1.45, color: p.textSecondary),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                    color: p.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border)),
                child: Column(
                  children: [
                    row('Order number', [order.orderNo]),
                    Divider(height: 1, color: p.border),
                    row('Total', [formatPrice(order.total, order.currency)]),
                    Divider(height: 1, color: p.border),
                    row('Payment', [methodLabel(confirmed.method), paymentNote]),
                    Divider(height: 1, color: p.border),
                    row('Deliver to',
                        [confirmed.delivery.fullName, confirmed.delivery.phone, confirmed.delivery.line]),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () {
                  final nav = Navigator.of(context);
                  nav.popUntil((r) => r.isFirst);
                  nav.push(MaterialPageRoute(builder: (_) => const OrdersPage()));
                },
                child: const Text('View my orders'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Continue shopping'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
