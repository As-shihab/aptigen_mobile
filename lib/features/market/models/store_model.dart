import 'package:flutter/material.dart';
import 'product_model.dart';

/// A market_store_profiles row, from GET /api/public/market/store/:id
/// (cloud's market-public.service.ts findStore()) — see
/// frontend/app/(public)/market/store/store.client.tsx for the same shape.
class StoreModel {
  final int id;
  final String storeName;
  final String? slug;
  final String? tagline;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final String? accentColor;
  final String? email;
  final String? phone;
  final String? city;
  final String? country;
  final bool isVerified;
  final String currency;
  final DateTime? createdAt;

  const StoreModel({
    required this.id,
    required this.storeName,
    this.slug,
    this.tagline,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    this.accentColor,
    this.email,
    this.phone,
    this.city,
    this.country,
    this.isVerified = false,
    this.currency = 'USD',
    this.createdAt,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) => StoreModel(
        id: json['id'] as int? ?? 0,
        storeName: json['store_name'] as String? ?? 'Store',
        slug: json['slug'] as String?,
        tagline: json['tagline'] as String?,
        description: json['description'] as String?,
        logoUrl: json['logo_url'] as String?,
        bannerUrl: json['banner_url'] as String?,
        accentColor: json['accent_color'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        city: json['city'] as String?,
        country: json['country'] as String?,
        isVerified: json['is_verified'] as bool? ?? false,
        currency: json['currency'] as String? ?? 'USD',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  Color get accentColorValue {
    final hex = accentColor?.replaceAll('#', '');
    if (hex == null || (hex.length != 6 && hex.length != 8)) {
      return const Color(0xFF2563EB);
    }
    final full = hex.length == 6 ? 'FF$hex' : hex;
    return Color(int.tryParse(full, radix: 16) ?? 0xFF2563EB);
  }

  /// Store cards render a two-stop gradient; real data only carries one
  /// accent color, so the second stop is a slightly darker shade of it.
  List<Color> get gradient {
    final base = accentColorValue;
    final hsl = HSLColor.fromColor(base);
    final darker = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    return [base, darker];
  }

  String get initials {
    final words = storeName.trim().split(RegExp(r'\s+'));
    if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return storeName.substring(0, storeName.length >= 2 ? 2 : 1).toUpperCase();
  }

  int get joinedYear => createdAt?.year ?? DateTime.now().year;
}

/// GET /api/public/market/store/:id's full payload — the store profile plus
/// its active listings and follower count.
class StorePageData {
  final StoreModel store;
  final List<ProductModel> listings;
  final int followerCount;

  const StorePageData({
    required this.store,
    required this.listings,
    required this.followerCount,
  });

  factory StorePageData.fromJson(Map<String, dynamic> json) => StorePageData(
        store: StoreModel.fromJson(json['store'] as Map<String, dynamic>),
        listings: ((json['listings'] as List?) ?? [])
            .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        followerCount: json['followerCount'] as int? ?? 0,
      );
}
