double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

class ItemReview {
  final int id;
  final int rating;
  final String? comment;
  const ItemReview({required this.id, required this.rating, this.comment});

  static ItemReview? fromJson(dynamic json) {
    if (json is! Map) return null;
    return ItemReview(
      id: _i(json['id']),
      rating: _i(json['rating']),
      comment: json['comment'] as String?,
    );
  }
}

class OrderItem {
  final int id;
  final int listingId;
  final String title;
  final double price;
  final int quantity;
  final double lineTotal;
  final String? thumbnailUrl;
  final ItemReview? review;
  /// List price before a flash sale (null when none applied).
  final double? originalPrice;
  /// This line's share of the order's promotion discount.
  final double discount;

  const OrderItem({
    required this.id,
    required this.listingId,
    required this.title,
    required this.price,
    required this.quantity,
    required this.lineTotal,
    this.thumbnailUrl,
    this.review,
    this.originalPrice,
    this.discount = 0,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: _i(json['id']),
        listingId: _i(json['listing_id']),
        title: json['title'] as String? ?? '',
        price: _d(json['price']),
        quantity: _i(json['quantity']),
        lineTotal: _d(json['line_total']),
        thumbnailUrl: (json['listing'] as Map?)?['thumbnail_url'] as String?,
        review: ItemReview.fromJson(json['review']),
        originalPrice: json['original_price'] == null ? null : _d(json['original_price']),
        discount: _d(json['discount']),
      );

  OrderItem withReview(ItemReview r) => OrderItem(
        id: id,
        listingId: listingId,
        title: title,
        price: price,
        quantity: quantity,
        lineTotal: lineTotal,
        thumbnailUrl: thumbnailUrl,
        review: r,
        originalPrice: originalPrice,
        discount: discount,
      );
}

/// A `market_orders` row with its items, from GET /api/market/orders.
class OrderModel {
  final int id;
  final String orderNo;
  final String status; // pending | paid | packaged | delivered | cancelled
  final String paymentMethod;
  final String currency;
  final double subtotal;
  final double shipping;
  final double tax;
  final double total;
  final double discount;
  final String? couponCode;
  final String? paymentReference;
  final String? shippingName;
  final String? shippingPhone;
  final String? shippingAddress;
  final String? shippingCity;
  final String? shippingArea;
  final String? shippingPostcode;
  final String? deliveryNote;
  final DateTime? createdAt;
  final List<OrderItem> items;

  const OrderModel({
    required this.id,
    required this.orderNo,
    required this.status,
    required this.paymentMethod,
    required this.currency,
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.total,
    this.discount = 0,
    this.couponCode,
    this.paymentReference,
    this.shippingName,
    this.shippingPhone,
    this.shippingAddress,
    this.shippingCity,
    this.shippingArea,
    this.shippingPostcode,
    this.deliveryNote,
    this.createdAt,
    this.items = const [],
  });

  /// Delivery address on one line, or null when the order has none.
  String? get deliveryLine {
    final parts = [shippingAddress, shippingArea, shippingCity, shippingPostcode]
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// A refund can be asked for once the order is paid or delivered.
  bool get refundable => status == 'paid' || status == 'packaged' || status == 'delivered';

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        id: _i(json['id']),
        orderNo: json['order_no'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        paymentMethod: json['payment_method'] as String? ?? 'cash',
        currency: json['currency'] as String? ?? 'USD',
        subtotal: _d(json['subtotal']),
        shipping: _d(json['shipping']),
        tax: _d(json['tax']),
        total: _d(json['total']),
        discount: _d(json['discount']),
        couponCode: json['coupon_code'] as String?,
        paymentReference: json['payment_reference'] as String?,
        shippingName: json['shipping_name'] as String?,
        shippingPhone: json['shipping_phone'] as String?,
        shippingAddress: json['shipping_address'] as String?,
        shippingCity: json['shipping_city'] as String?,
        shippingArea: json['shipping_area'] as String?,
        shippingPostcode: json['shipping_postcode'] as String?,
        deliveryNote: json['delivery_note'] as String?,
        createdAt: json['created_at'] is String ? DateTime.tryParse(json['created_at'] as String) : null,
        items: ((json['items'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(OrderItem.fromJson)
            .toList(),
      );
}

/// POST /api/market/checkout response.
class PlacedOrder {
  final String orderNo;
  final double total;
  final String status;
  final String? currency;
  final double discount;
  const PlacedOrder({required this.orderNo, required this.total, required this.status, this.currency, this.discount = 0});

  factory PlacedOrder.fromJson(Map<String, dynamic> json) => PlacedOrder(
        orderNo: json['order_no'] as String? ?? '',
        total: _d(json['total']),
        status: json['status'] as String? ?? 'pending',
        currency: json['currency'] as String?,
        discount: _d(json['discount']),
      );
}
