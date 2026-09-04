import 'package:flutter/material.dart';

/// market_categories.icon is seeded as a PascalCase lucide-react export name
/// (see cloud/src/seed/market-categories.ts) — mapped here to the closest
/// Material icon instead of a lucide package dependency.
IconData resolveMarketCategoryIcon(String? name) {
  switch (name) {
    case 'Laptop':
      return Icons.laptop_mac_rounded;
    case 'Headphones':
      return Icons.headphones_rounded;
    case 'Watch':
      return Icons.watch_rounded;
    case 'Shirt':
      return Icons.checkroom_rounded;
    case 'Camera':
      return Icons.camera_alt_rounded;
    case 'Home':
      return Icons.chair_rounded;
    case 'Sparkles':
      return Icons.auto_awesome_rounded;
    case 'Dumbbell':
      return Icons.fitness_center_rounded;
    case 'ShoppingBasket':
      return Icons.shopping_basket_rounded;
    case 'BookOpen':
      return Icons.menu_book_rounded;
    default:
      return Icons.shopping_bag_rounded;
  }
}

/// Same rotating palette idea as frontend/app/lib/marketIcons.ts
/// `categoryTint` — stable by list position, not tied to a specific name.
const List<Color> marketCategoryTints = [
  Color(0xFF2563EB),
  Color(0xFFE11D48),
  Color(0xFFD97706),
  Color(0xFFEA580C),
  Color(0xFF65A30D),
  Color(0xFFDC2626),
  Color(0xFFDB2777),
  Color(0xFF0284C7),
  Color(0xFFCA8A04),
  Color(0xFF7C3AED),
];

Color marketCategoryTint(int index) =>
    marketCategoryTints[index % marketCategoryTints.length];
