/// One photo or video attached to a listing.
class ListingMedia {
  final String url;
  final bool isVideo;
  const ListingMedia(this.url, this.isVideo);
}

final _videoExt = RegExp(r'\.(mp4|webm|mov|m4v|ogv|ogg|mkv)(\?|#|$)', caseSensitive: false);

bool _isVideo(String url, String? type) => type == 'video' || _videoExt.hasMatch(url);

/// Compact seller identity carried on a listing (`store_profile`).
class StoreSummary {
  final int id;
  final String name;
  final String? avatarUrl;
  final String? accentColor;
  final bool isVerified;
  final String? phone;

  const StoreSummary({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.accentColor,
    this.isVerified = false,
    this.phone,
  });

  static StoreSummary? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return StoreSummary(
      id: _int(json['id']),
      name: json['store_name'] as String? ?? 'Store',
      avatarUrl: json['avatar_url'] as String?,
      accentColor: json['accent_color'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      phone: json['phone'] as String?,
    );
  }
}

int _int(dynamic v, [int fallback = 0]) =>
    v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
double _double(dynamic v, [double fallback = 0]) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;

/// Live flash sale price on a listing (`flash_sale` on the public listing
/// endpoints). `price` on the listing stays the normal list price.
class FlashPrice {
  final int flashSaleItemId;
  final String saleName;
  final double salePrice;
  final double originalPrice;
  final DateTime endsAt;
  /// Units left at the sale price; null = no cap.
  final int? remaining;
  final int? perOrderLimit;

  const FlashPrice({
    required this.flashSaleItemId,
    required this.saleName,
    required this.salePrice,
    required this.originalPrice,
    required this.endsAt,
    this.remaining,
    this.perOrderLimit,
  });

  static FlashPrice? fromJson(dynamic json) {
    if (json is! Map) return null;
    final ends = json['ends_at'] is String ? DateTime.tryParse(json['ends_at'] as String)?.toLocal() : null;
    if (ends == null) return null;
    return FlashPrice(
      flashSaleItemId: _int(json['flash_sale_item_id']),
      saleName: json['sale_name'] as String? ?? 'Flash sale',
      salePrice: _double(json['sale_price']),
      originalPrice: _double(json['original_price']),
      endsAt: ends,
      remaining: json['remaining'] == null ? null : _int(json['remaining']),
      perOrderLimit: json['per_order_limit'] == null ? null : _int(json['per_order_limit']),
    );
  }

  /// Still running and not sold out (checked on the device clock).
  bool get isLive => endsAt.isAfter(DateTime.now()) && (remaining == null || remaining! > 0);

  int get percentOff => originalPrice <= 0 ? 0 : ((1 - salePrice / originalPrice) * 100).round();
}

/// A `market_listings` row as returned by GET /api/public/market/listings and
/// /listing/:id — same contract as `ApiListing` in
/// frontend/app/lib/marketProduct.ts.
class ProductModel {
  final int id;
  final String title;
  final String? description;
  final double price;
  final double? comparePrice;
  final String currency;
  final int quantity;
  final int minOrder;
  final int? maxOrder;
  final String? condition;
  final String? listingType;
  final bool isFeatured;
  final List<String> tags;
  final String? city;
  final String? country;
  final String? thumbnailUrl;
  final int? categoryId;
  final String? categoryName;
  final List<ListingMedia> medias;
  final StoreSummary? store;
  final FlashPrice? flashSale;
  final double? ratingAvg;
  final int ratingCount;

  // Linked catalog product's live stock counters.
  final bool hasProduct;
  final int? productStock;
  final bool trackStock;
  final bool allowBackorder;

  const ProductModel({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    this.comparePrice,
    this.currency = 'USD',
    this.quantity = 0,
    this.minOrder = 1,
    this.maxOrder,
    this.condition,
    this.listingType,
    this.isFeatured = false,
    this.tags = const [],
    this.city,
    this.country,
    this.thumbnailUrl,
    this.categoryId,
    this.categoryName,
    this.medias = const [],
    this.store,
    this.flashSale,
    this.ratingAvg,
    this.ratingCount = 0,
    this.hasProduct = false,
    this.productStock,
    this.trackStock = false,
    this.allowBackorder = false,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    final product = json['product'] as Map<String, dynamic>?;
    final rawTags = json['tags'] as String?;
    return ProductModel(
      id: _int(json['id']),
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      price: _double(json['price']),
      comparePrice: json['compare_price'] == null ? null : _double(json['compare_price']),
      currency: json['currency'] as String? ?? 'USD',
      quantity: _int(json['quantity']),
      minOrder: _int(json['min_order'], 1).clamp(1, 1 << 30),
      maxOrder: json['max_order'] == null ? null : _int(json['max_order']),
      condition: json['condition'] as String?,
      listingType: json['listing_type'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
      tags: rawTags == null
          ? const []
          : rawTags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
      city: json['city'] as String?,
      country: json['country'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      categoryId: category == null ? null : _int(category['id']),
      categoryName: category?['name'] as String?,
      medias: ((json['medias'] as List?) ?? [])
          .whereType<Map>()
          .where((m) => (m['url'] as String?)?.isNotEmpty ?? false)
          .map((m) => ListingMedia(m['url'] as String, _isVideo(m['url'] as String, m['type'] as String?)))
          .toList(),
      store: StoreSummary.fromJson(json['store_profile'] as Map<String, dynamic>?),
      flashSale: FlashPrice.fromJson(json['flash_sale']),
      ratingAvg: json['rating_avg'] == null ? null : _double(json['rating_avg']),
      ratingCount: _int(json['rating_count']),
      hasProduct: product != null,
      productStock: product?['stock_qty'] == null ? null : _int(product!['stock_qty']),
      trackStock: product?['track_stock'] as bool? ?? false,
      allowBackorder: product?['allow_backorder'] as bool? ?? false,
    );
  }

  /// Cover photo — thumbnail, else first photo; never a video
  /// (`listingCoverUrl` on web).
  String? get coverUrl {
    final videos = medias.where((m) => m.isVideo).map((m) => m.url).toSet();
    final thumb = thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty && !videos.contains(thumb) && !_videoExt.hasMatch(thumb)) {
      return thumb;
    }
    for (final m in medias) {
      if (!m.isVideo) return m.url;
    }
    return null;
  }

  /// Photos and videos in the seller's order, cover first.
  List<ListingMedia> get gallery {
    final items = [...medias];
    final cover = coverUrl;
    if (cover != null && !items.any((m) => m.url == cover)) {
      items.insert(0, ListingMedia(cover, false));
    }
    return items;
  }

  /// Available stock — the linked product's live counter, `null` = unlimited
  /// (`listingStock` on web).
  int? get stock {
    if (!hasProduct) return quantity;
    if (!trackStock || allowBackorder) return null;
    return productStock ?? 0;
  }

  bool get outOfStock => stock != null && stock! <= 0;
  bool get lowStock => stock != null && stock! > 0 && stock! <= 5;

  /// Live flash sale, if any (ignores one that has ended on the device clock).
  FlashPrice? get liveFlash => flashSale != null && flashSale!.isLive ? flashSale : null;

  /// What the buyer pays per unit right now — the flash price while a sale
  /// is live, else the list price. Display only; the server quote is final.
  double get effectivePrice => liveFlash?.salePrice ?? price;

  /// Price to show struck through: list price during a flash sale, else the
  /// seller's compare-at price.
  double? get strikePrice {
    if (liveFlash != null) return price;
    return comparePrice != null && comparePrice! > price ? comparePrice : null;
  }

  bool get onSale => strikePrice != null;

  int get discountPercent => onSale ? ((1 - effectivePrice / strikePrice!) * 100).round() : 0;

  String? get location {
    final parts = [city, country].whereType<String>().where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Most a buyer can put in the cart at once.
  int get maxQty {
    var max = 1 << 30;
    if (maxOrder != null && maxOrder! > 0) max = maxOrder!;
    final s = stock;
    if (s != null && s < max) max = s;
    return max;
  }
}
