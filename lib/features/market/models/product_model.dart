class ProductModel {
  final int id;
  final String name;
  final String? description;
  final double price;
  final double? originalPrice;
  final String? category;
  final double rating;
  final int reviewCount;
  final List<String> images;
  final String? brand;
  final bool inStock;
  final int? discountPercent;
  final bool isFeatured;
  final int sellerId;
  final String sellerName;

  const ProductModel({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.originalPrice,
    this.category,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.images = const [],
    this.brand,
    this.inStock = true,
    this.discountPercent,
    this.isFeatured = false,
    this.sellerId = 0,
    this.sellerName = 'Aptigen Store',
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    List<String> parseImages(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String && raw.isNotEmpty) return [raw];
      return [];
    }

    return ProductModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      category: json['category'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['review_count'] as int? ?? 0,
      images: parseImages(json['images']),
      brand: json['brand'] as String?,
      inStock: json['in_stock'] as bool? ?? true,
      discountPercent: json['discount_percent'] as int?,
      isFeatured: json['is_featured'] as bool? ?? false,
      sellerId: json['seller_id'] as int? ?? 0,
      sellerName: json['seller_name'] as String? ?? 'Aptigen Store',
    );
  }

  String? get coverImage => images.isNotEmpty ? images.first : null;

  int? get effectiveDiscount {
    if (originalPrice != null && originalPrice! > price) {
      return ((originalPrice! - price) / originalPrice! * 100).round();
    }
    return discountPercent;
  }
}
