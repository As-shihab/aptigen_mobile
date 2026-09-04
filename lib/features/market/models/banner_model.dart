/// A market_banners row, from GET /api/public/market/banners?placement=...
/// `placement` is one of "hero" | "promo_card" | "strip".
class BannerModel {
  final int id;
  final String placement;
  final String title;
  final String? subtitle;
  final String? ctaLabel;
  final String? linkUrl;
  final String? imageUrl;
  final String? tone;

  const BannerModel({
    required this.id,
    required this.placement,
    required this.title,
    this.subtitle,
    this.ctaLabel,
    this.linkUrl,
    this.imageUrl,
    this.tone,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) => BannerModel(
        id: json['id'] as int? ?? 0,
        placement: json['placement'] as String? ?? 'hero',
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String?,
        ctaLabel: json['cta_label'] as String?,
        linkUrl: json['link_url'] as String?,
        imageUrl: json['image_url'] as String?,
        tone: json['tone'] as String?,
      );
}
