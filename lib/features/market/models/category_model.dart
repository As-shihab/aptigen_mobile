/// A market_categories row, from GET /api/public/market/categories.
class CategoryModel {
  final int id;
  final String name;
  final String slug;
  final String? icon;
  final int count;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.count = 0,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        icon: json['icon'] as String?,
        count: json['count'] as int? ?? 0,
      );
}
