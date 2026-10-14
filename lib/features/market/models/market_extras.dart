import 'product_model.dart';

// Models for the market features added after the first port — flash sales,
// the cart quote (promotions / coupon / payment methods), reviews, saved
// addresses and refunds. Same contracts as frontend/app/lib/marketApi.ts.

double _d(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;
int _i(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
int? _iOrNull(dynamic v) => v == null ? null : _i(v);
DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
List<Map<String, dynamic>> _maps(dynamic v) => v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

// ── Flash sales ─────────────────────────────────────────────────────────

/// A listing inside a live flash sale (GET /api/public/market/flash-sales).
class FlashSaleListing {
  final ProductModel product;
  final int soldCount;
  final int? stockLimit;
  const FlashSaleListing(this.product, this.soldCount, this.stockLimit);

  factory FlashSaleListing.fromJson(Map<String, dynamic> json) =>
      FlashSaleListing(ProductModel.fromJson(json), _i(json['sold_count']), _iOrNull(json['stock_limit']));

  /// 0..1 share sold, when the sale caps stock.
  double? get soldRatio => stockLimit == null || stockLimit == 0 ? null : (soldCount / stockLimit!).clamp(0, 1).toDouble();
}

class FlashSale {
  final int id;
  final String name;
  final String? description;
  final DateTime? startsAt;
  final DateTime endsAt;
  final List<FlashSaleListing> items;
  const FlashSale({required this.id, required this.name, this.description, this.startsAt, required this.endsAt, this.items = const []});

  factory FlashSale.fromJson(Map<String, dynamic> json) => FlashSale(
        id: _i(json['id']),
        name: json['name'] as String? ?? 'Flash sale',
        description: json['description'] as String?,
        startsAt: _date(json['starts_at']),
        endsAt: _date(json['ends_at']) ?? DateTime.now(),
        items: _maps(json['items']).map(FlashSaleListing.fromJson).toList(),
      );
}

// ── Cart quote ──────────────────────────────────────────────────────────

class QuoteLine {
  final int listingId;
  final int quantity;
  final double unitPrice;
  final double? originalPrice;
  final int flashUnits;
  final DateTime? flashEndsAt;
  final double lineTotal;
  final double discount;
  const QuoteLine({
    required this.listingId,
    required this.quantity,
    required this.unitPrice,
    this.originalPrice,
    this.flashUnits = 0,
    this.flashEndsAt,
    required this.lineTotal,
    this.discount = 0,
  });

  factory QuoteLine.fromJson(Map<String, dynamic> json) => QuoteLine(
        listingId: _i(json['listing_id']),
        quantity: _i(json['quantity']),
        unitPrice: _d(json['unit_price']),
        originalPrice: json['original_price'] == null ? null : _d(json['original_price']),
        flashUnits: _i(json['flash_units']),
        flashEndsAt: _date(json['flash_ends_at']),
        lineTotal: _d(json['line_total']),
        discount: _d(json['discount']),
      );
}

class QuotePromotion {
  final int promotionId;
  final String? storeName;
  final String name;
  final String? code;
  final String discountType;
  final double discount;
  final bool freeShipping;
  const QuotePromotion({
    required this.promotionId,
    this.storeName,
    required this.name,
    this.code,
    required this.discountType,
    required this.discount,
    this.freeShipping = false,
  });

  factory QuotePromotion.fromJson(Map<String, dynamic> json) => QuotePromotion(
        promotionId: _i(json['promotion_id']),
        storeName: json['store_name'] as String?,
        name: json['name'] as String? ?? 'Offer',
        code: json['code'] as String?,
        discountType: json['discount_type'] as String? ?? 'percent',
        discount: _d(json['discount']),
        freeShipping: json['free_shipping'] == true,
      );
}

/// status: applied | invalid | not_eligible | not_best
class QuoteCoupon {
  final String code;
  final String status;
  final String message;
  const QuoteCoupon(this.code, this.status, this.message);

  bool get applied => status == 'applied';

  static QuoteCoupon? fromJson(dynamic json) => json is Map
      ? QuoteCoupon(json['code'] as String? ?? '', json['status'] as String? ?? 'invalid', json['message'] as String? ?? '')
      : null;
}

class QuoteGateway {
  final String? storeName;
  final String? provider;
  final String? label;
  final String? accountName;
  final String? accountNumber;
  final String? instructions;
  const QuoteGateway({this.storeName, this.provider, this.label, this.accountName, this.accountNumber, this.instructions});

  factory QuoteGateway.fromJson(Map<String, dynamic> json) => QuoteGateway(
        storeName: json['store_name'] as String?,
        provider: json['provider'] as String?,
        label: json['label'] as String?,
        accountName: json['account_name'] as String?,
        accountNumber: json['account_number'] as String?,
        instructions: json['instructions'] as String?,
      );
}

/// method: cash | card | mobile | bank
class QuotePaymentMethod {
  final String method;
  final bool available;
  final List<QuoteGateway> gateways;
  const QuotePaymentMethod(this.method, this.available, this.gateways);

  factory QuotePaymentMethod.fromJson(Map<String, dynamic> json) => QuotePaymentMethod(
        json['method'] as String? ?? 'cash',
        json['available'] == true,
        _maps(json['gateways']).map(QuoteGateway.fromJson).toList(),
      );
}

/// POST /api/public/market/quote — the server's price for a cart: flash
/// prices, promotions / coupon, shipping, tax and accepted payment methods.
class CartQuote {
  final List<QuoteLine> lines;
  final List<int> unavailable;
  final double subtotal;
  final double discount;
  final double shipping;
  final double tax;
  final double total;
  final String currency;
  final List<QuotePromotion> promotions;
  final QuoteCoupon? coupon;
  final List<QuotePaymentMethod> paymentMethods;

  const CartQuote({
    this.lines = const [],
    this.unavailable = const [],
    this.subtotal = 0,
    this.discount = 0,
    this.shipping = 0,
    this.tax = 0,
    this.total = 0,
    this.currency = 'USD',
    this.promotions = const [],
    this.coupon,
    this.paymentMethods = const [],
  });

  factory CartQuote.fromJson(Map<String, dynamic> json) => CartQuote(
        lines: _maps(json['lines']).map(QuoteLine.fromJson).toList(),
        unavailable: json['unavailable'] is List ? (json['unavailable'] as List).map((e) => _i(e)).toList() : const [],
        subtotal: _d(json['subtotal']),
        discount: _d(json['discount']),
        shipping: _d(json['shipping']),
        tax: _d(json['tax']),
        total: _d(json['total']),
        currency: json['currency'] as String? ?? 'USD',
        promotions: _maps(json['promotions']).map(QuotePromotion.fromJson).toList(),
        coupon: QuoteCoupon.fromJson(json['coupon']),
        paymentMethods: _maps(json['payment_methods']).map(QuotePaymentMethod.fromJson).toList(),
      );

  QuoteLine? lineFor(int listingId) {
    for (final l in lines) {
      if (l.listingId == listingId) return l;
    }
    return null;
  }

  QuotePaymentMethod? method(String id) {
    for (final m in paymentMethods) {
      if (m.method == id) return m;
    }
    return null;
  }
}

// ── Reviews ─────────────────────────────────────────────────────────────

class ListingReview {
  final int id;
  final double rating;
  final String? comment;
  final DateTime? createdAt;
  final String reviewer;
  final String? sellerReply;
  final DateTime? sellerRepliedAt;
  const ListingReview({
    required this.id,
    required this.rating,
    this.comment,
    this.createdAt,
    this.reviewer = 'Buyer',
    this.sellerReply,
    this.sellerRepliedAt,
  });

  factory ListingReview.fromJson(Map<String, dynamic> json) => ListingReview(
        id: _i(json['id']),
        rating: _d(json['rating']),
        comment: json['comment'] as String?,
        createdAt: _date(json['created_at']),
        reviewer: json['reviewer'] as String? ?? 'Buyer',
        sellerReply: json['seller_reply'] as String?,
        sellerRepliedAt: _date(json['seller_replied_at']),
      );
}

class ReviewPage {
  final List<ListingReview> items;
  final int total;
  final double? average;
  /// star (1..5) → count
  final Map<int, int> distribution;
  const ReviewPage({this.items = const [], this.total = 0, this.average, this.distribution = const {}});

  factory ReviewPage.fromJson(Map<String, dynamic> json) {
    final dist = <int, int>{for (var s = 1; s <= 5; s++) s: 0};
    final raw = json['distribution'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final star = int.tryParse('$k');
        if (star != null && dist.containsKey(star)) dist[star] = _i(v);
      });
    }
    return ReviewPage(
      items: _maps(json['items']).map(ListingReview.fromJson).toList(),
      total: _i(json['total']),
      average: json['average'] == null ? null : _d(json['average']),
      distribution: dist,
    );
  }
}

// ── Saved addresses ─────────────────────────────────────────────────────

class BuyerAddress {
  final int id;
  final String? label;
  final String fullName;
  final String phone;
  final String address;
  final String city;
  final String? area;
  final String? postcode;
  final bool isDefault;
  const BuyerAddress({
    required this.id,
    this.label,
    required this.fullName,
    required this.phone,
    required this.address,
    required this.city,
    this.area,
    this.postcode,
    this.isDefault = false,
  });

  factory BuyerAddress.fromJson(Map<String, dynamic> json) => BuyerAddress(
        id: _i(json['id']),
        label: json['label'] as String?,
        fullName: json['full_name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        address: json['address'] as String? ?? '',
        city: json['city'] as String? ?? '',
        area: json['area'] as String?,
        postcode: json['postcode'] as String?,
        isDefault: json['is_default'] == true,
      );

  /// One-line address, like `formatAddress` on web.
  String get oneLine =>
      [address, area, city, postcode].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
}

/// Body for create / update.
class AddressInput {
  final String? label;
  final String fullName;
  final String phone;
  final String address;
  final String city;
  final String? area;
  final String? postcode;
  final bool isDefault;
  const AddressInput({
    this.label,
    required this.fullName,
    required this.phone,
    required this.address,
    required this.city,
    this.area,
    this.postcode,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'label': (label?.trim().isEmpty ?? true) ? null : label!.trim(),
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'address': address.trim(),
        'city': city.trim(),
        'area': (area?.trim().isEmpty ?? true) ? null : area!.trim(),
        'postcode': (postcode?.trim().isEmpty ?? true) ? null : postcode!.trim(),
        'is_default': isDefault,
      };
}

// ── Refunds ─────────────────────────────────────────────────────────────

/// status: requested | approved | rejected | refunded
class BuyerRefund {
  final int id;
  final int orderId;
  final int orderItemId;
  final int quantity;
  final double amount;
  final String reason;
  final String status;
  final String? method;
  final String? sellerNote;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  const BuyerRefund({
    required this.id,
    required this.orderId,
    required this.orderItemId,
    required this.quantity,
    required this.amount,
    required this.reason,
    required this.status,
    this.method,
    this.sellerNote,
    this.createdAt,
    this.resolvedAt,
  });

  bool get isOpen => status != 'rejected';

  factory BuyerRefund.fromJson(Map<String, dynamic> json) => BuyerRefund(
        id: _i(json['id']),
        orderId: _i(json['order_id']),
        orderItemId: _i(json['order_item_id']),
        quantity: _i(json['quantity'], 1),
        amount: _d(json['amount']),
        reason: json['reason'] as String? ?? '',
        status: json['status'] as String? ?? 'requested',
        method: json['method'] as String?,
        sellerNote: json['seller_note'] as String?,
        createdAt: _date(json['created_at']),
        resolvedAt: _date(json['resolved_at']),
      );
}
