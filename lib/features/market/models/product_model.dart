/// Mirrors the `ApiListing` shape returned by GET /api/public/market/listings
/// and /listing/:id (cloud's market-public.service.ts, a market_listings row)
/// — see frontend/app/lib/marketProduct.ts for the same contract on web.
class ProductModel {
  final int id;
  final String name; // listing.title
  final String? description;
  final double price;
  final double? originalPrice; // compare_price, only when it beats price
  final String? category; // category.name
  final int? categoryId;
  final List<String> images; // thumbnail_url + medias, deduped
  final int quantity;
  final int minOrder;
  final int? maxOrder;
  final String condition; // "new" | "used" | "refurbished"
  final String listingType; // "fixed" | "auction" | "negotiable"
  final List<String> tags;
  final String? city;
  final String? country;
  final bool isFeatured;
  final String currency;
  final int sellerId; // store_profile.id, 0 when none attached
  final String sellerName;
  final String? sellerLogoUrl;
  final String? sellerAccentColor;
  final bool sellerVerified;
  final String? sellerPhone;

  const ProductModel({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.originalPrice,
    this.category,
    this.categoryId,
    this.images = const [],
    this.quantity = 0,
    this.minOrder = 1,
    this.maxOrder,
    this.condition = 'new',
    this.listingType = 'fixed',
    this.tags = const [],
    this.city,
    this.country,
    this.isFeatured = false,
    this.currency = 'USD',
    this.sellerId = 0,
    this.sellerName = 'Aptigen Marketplace',
    this.sellerLogoUrl,
    this.sellerAccentColor,
    this.sellerVerified = false,
    this.sellerPhone,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    List<String> parseImages() {
      final urls = <String>[];
      final thumb = json['thumbnail_url'] as String?;
      if (thumb != null && thumb.isNotEmpty) urls.add(thumb);
      final medias = json['medias'] as List?;
      if (medias != null) {
        for (final m in medias) {
          final url = (m as Map)['url'] as String?;
          if (url != null && url.isNotEmpty && !urls.contains(url)) {
            urls.add(url);
          }
        }
      }
      return urls;
    }

    List<String> parseTags() {
      final raw = json['tags'] as String?;
      if (raw == null || raw.isEmpty) return [];
      return raw.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    }

    final category = json['category'] as Map<String, dynamic>?;
    final store = json['store_profile'] as Map<String, dynamic>?;
    final price = (json['price'] as num?)?.toDouble() ?? 0.0;
    final comparePrice = (json['compare_price'] as num?)?.toDouble();

    return ProductModel(
      id: json['id'] as int? ?? 0,
      name: json['title'] as String? ?? '',
      description: json['description'] as String?,
      price: price,
      originalPrice: (comparePrice != null && comparePrice > price) ? comparePrice : null,
      category: category?['name'] as String?,
      categoryId: category?['id'] as int?,
      images: parseImages(),
      quantity: json['quantity'] as int? ?? 0,
      minOrder: json['min_order'] as int? ?? 1,
      maxOrder: json['max_order'] as int?,
      condition: json['condition'] as String? ?? 'new',
      listingType: json['listing_type'] as String? ?? 'fixed',
      tags: parseTags(),
      city: json['city'] as String?,
      country: json['country'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
      currency: json['currency'] as String? ?? 'USD',
      sellerId: store?['id'] as int? ?? 0,
      sellerName: store?['store_name'] as String? ?? 'Aptigen Marketplace',
      sellerLogoUrl: store?['logo_url'] as String?,
      sellerAccentColor: store?['accent_color'] as String?,
      sellerVerified: store?['is_verified'] as bool? ?? false,
      sellerPhone: store?['phone'] as String?,
    );
  }

  String? get coverImage => images.isNotEmpty ? images.first : null;
  bool get inStock => quantity > 0;

  int? get effectiveDiscount {
    if (originalPrice != null && originalPrice! > price) {
      return ((originalPrice! - price) / originalPrice! * 100).round();
    }
    return null;
  }
}
