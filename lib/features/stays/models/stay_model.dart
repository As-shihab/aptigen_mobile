class MediaModel {
  final String url;
  final String? type;
  final int? position;

  const MediaModel({required this.url, this.type, this.position});

  factory MediaModel.fromJson(Map<String, dynamic> json) => MediaModel(
        url: json['url'] as String? ?? '',
        type: json['type'] as String?,
        position: json['position'] as int?,
      );
}

class AmenityModel {
  final int id;
  final String key;
  final String label;
  final String? icon;

  const AmenityModel({
    required this.id,
    required this.key,
    required this.label,
    this.icon,
  });

  factory AmenityModel.fromJson(Map<String, dynamic> json) {
    final a = json['amenity'] as Map<String, dynamic>? ?? json;
    return AmenityModel(
      id: a['id'] as int? ?? 0,
      key: a['key'] as String? ?? '',
      label: a['label'] as String? ?? '',
      icon: a['icon'] as String?,
    );
  }
}

class ReviewModel {
  final int id;
  final double rating;
  final String? comment;
  final String userName;
  final String? createdAt;

  const ReviewModel({
    required this.id,
    required this.rating,
    this.comment,
    this.userName = 'Guest',
    this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final name = user?['name'] as String? ??
        user?['first_name'] as String? ??
        'Guest';
    return ReviewModel(
      id: json['id'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      comment: json['comment'] as String?,
      userName: name,
      createdAt: json['created_at'] as String?,
    );
  }

  String get initials {
    final parts = userName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return userName.substring(0, userName.length >= 2 ? 2 : 1).toUpperCase();
  }

  String get timeAgo {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt!);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
      if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      return 'Today';
    } catch (_) {
      return '';
    }
  }
}

class StayModel {
  final int id;
  final String title;
  final String? address;
  final String? city;
  final String? country;
  final double? pricePerNight;
  final double? cleaningFee;
  final int? maxGuests;
  final String? description;
  final String? propertyType;
  final String? roomType;
  final int? bedroomCount;
  final double? bathroomCount;
  final int? bedCount;
  final String? categoryName;
  final List<MediaModel> medias;
  final List<AmenityModel> amenities;
  final List<ReviewModel> reviews;

  const StayModel({
    required this.id,
    required this.title,
    this.address,
    this.city,
    this.country,
    this.pricePerNight,
    this.cleaningFee,
    this.maxGuests,
    this.description,
    this.propertyType,
    this.roomType,
    this.bedroomCount,
    this.bathroomCount,
    this.bedCount,
    this.categoryName,
    this.medias = const [],
    this.amenities = const [],
    this.reviews = const [],
  });

  factory StayModel.fromJson(Map<String, dynamic> json) {
    final cat = json['category'] as Map<String, dynamic>?;
    return StayModel(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      address: json['address'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      pricePerNight: (json['price_per_night'] as num?)?.toDouble(),
      cleaningFee: (json['cleaning_fee'] as num?)?.toDouble(),
      maxGuests: json['max_guests'] as int?,
      description: json['description'] as String?,
      propertyType: json['property_type'] as String?,
      roomType: json['room_type'] as String?,
      bedroomCount: json['bedroom_count'] as int?,
      bathroomCount: (json['bathroom_count'] as num?)?.toDouble(),
      bedCount: json['bed_count'] as int?,
      categoryName: cat?['name'] as String?,
      medias: (json['medias'] as List<dynamic>?)
              ?.map((m) => MediaModel.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      amenities: (json['amenities'] as List<dynamic>?)
              ?.map((a) => AmenityModel.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      reviews: (json['reviews'] as List<dynamic>?)
              ?.map((r) => ReviewModel.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  String get location =>
      [city, country].where((s) => s != null && s.isNotEmpty).join(', ');

  String get fullLocation =>
      [address, city, country].where((s) => s != null && s.isNotEmpty).join(', ');

  String? get coverImage => medias.isNotEmpty ? medias.first.url : null;

  List<String> get imageUrls =>
      medias.map((m) => m.url).where((u) => u.isNotEmpty).toList();

  double get averageRating {
    if (reviews.isEmpty) return 0.0;
    final sum = reviews.map((r) => r.rating).reduce((a, b) => a + b);
    return sum / reviews.length;
  }

  int get reviewCount => reviews.length;
}
