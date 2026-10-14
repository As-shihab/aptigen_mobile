import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'product_model.dart';

Color parseHexColor(String? hex, [Color fallback = AppColors.accent]) {
  final clean = hex?.replaceAll('#', '').trim();
  if (clean == null || (clean.length != 6 && clean.length != 8)) return fallback;
  final full = clean.length == 6 ? 'FF$clean' : clean;
  final value = int.tryParse(full, radix: 16);
  return value == null ? fallback : Color(value);
}

String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words[0].substring(0, words[0].length >= 2 ? 2 : 1).toUpperCase();
  return '${words[0][0]}${words[1][0]}'.toUpperCase();
}

/// A storefront (`creator_profiles` row) from GET /api/public/market/store/:id.
class StoreModel {
  final int id;
  final String storeName;
  final String? tagline;
  final String? bio;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? accentColor;
  final String? email;
  final String? phone;
  final String? city;
  final String? country;
  final bool isVerified;
  final DateTime? createdAt;

  const StoreModel({
    required this.id,
    required this.storeName,
    this.tagline,
    this.bio,
    this.avatarUrl,
    this.bannerUrl,
    this.accentColor,
    this.email,
    this.phone,
    this.city,
    this.country,
    this.isVerified = false,
    this.createdAt,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) => StoreModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        storeName: json['store_name'] as String? ?? 'Store',
        tagline: json['tagline'] as String?,
        bio: json['bio'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        bannerUrl: json['banner_url'] as String?,
        accentColor: json['accent_color'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        city: json['city'] as String?,
        country: json['country'] as String?,
        isVerified: json['is_verified'] as bool? ?? false,
        createdAt: json['created_at'] is String ? DateTime.tryParse(json['created_at'] as String) : null,
      );

  Color get accent => parseHexColor(accentColor);

  String get initials => initialsOf(storeName);

  String? get location {
    final parts = [city, country].whereType<String>().where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }
}

/// GET /api/public/market/store/:id — profile + one page of its listings.
class StorePageData {
  final StoreModel store;
  final List<ProductModel> listings;
  final int total;
  final int followerCount;

  const StorePageData({
    required this.store,
    required this.listings,
    required this.total,
    required this.followerCount,
  });

  factory StorePageData.fromJson(Map<String, dynamic> json) {
    final listings = ((json['listings'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ProductModel.fromJson)
        .toList();
    return StorePageData(
      store: StoreModel.fromJson(json['store'] as Map<String, dynamic>),
      listings: listings,
      total: (json['total'] as num?)?.toInt() ?? listings.length,
      followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
    );
  }
}
