/// A "top vendor" row, from GET /api/public/market/vendors — ranked by
/// active listing count, identity sourced from the workplace's
/// creator_profiles row (see cloud's market-public.service.ts findVendors()).
class VendorModel {
  final int storeId;
  final String storeName;
  final String? avatarUrl;
  final String? tagline;
  final bool isVerified;
  final int listingCount;

  const VendorModel({
    required this.storeId,
    required this.storeName,
    this.avatarUrl,
    this.tagline,
    this.isVerified = false,
    this.listingCount = 0,
  });

  factory VendorModel.fromJson(Map<String, dynamic> json) => VendorModel(
        storeId: json['store_id'] as int? ?? 0,
        storeName: json['store_name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        tagline: json['tagline'] as String?,
        isVerified: json['is_verified'] as bool? ?? false,
        listingCount: json['listing_count'] as int? ?? 0,
      );
}
