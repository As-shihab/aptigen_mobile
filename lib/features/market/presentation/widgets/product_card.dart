import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/http_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../data/cart_store.dart';
import '../../data/market_service.dart';
import '../../models/product_model.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final bool isDark;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.isDark,
  });

  static const _catColors = {
    'Electronics': [Color(0xFF2563EB), Color(0xFF4F46E5)],
    'Audio': [Color(0xFF7C3AED), Color(0xFF9333EA)],
    'Wearables': [Color(0xFF059669), Color(0xFF0D9488)],
    'Fashion': [Color(0xFFDB2777), Color(0xFFBE185D)],
    'Photography': [Color(0xFFDB2777), Color(0xFF9333EA)],
    'Home & Living': [Color(0xFFD97706), Color(0xFFEA580C)],
    'Beauty & Health': [Color(0xFFEC4899), Color(0xFFDB2777)],
    'Sports & Outdoors': [Color(0xFF16A34A), Color(0xFF15803D)],
    'Groceries': [Color(0xFF65A30D), Color(0xFF4D7C0F)],
    'Books & Media': [Color(0xFF0284C7), Color(0xFF0369A1)],
  };

  @override
  Widget build(BuildContext context) {
    final discount = product.effectiveDiscount;
    final colors = _catColors[product.category] ??
        [AppColors.slate600, AppColors.slate700];
    final coverImage = MediaUrl.resolve(product.coverImage, view: 'small');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.slate100,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Hero(
                    tag: 'product-image-${product.id}',
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20)),
                      child: coverImage != null
                          ? CachedNetworkImage(
                              imageUrl: coverImage,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  _Placeholder(colors: colors, category: product.category),
                              errorWidget: (_, __, ___) =>
                                  _Placeholder(colors: colors, category: product.category),
                            )
                          : _Placeholder(colors: colors, category: product.category),
                    ),
                  ),
                  // Discount badge
                  if (discount != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.rose500,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '-$discount%',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  // Category badge
                  if (product.category != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.category!,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.slate900,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      product.inStock ? '${product.quantity} in stock' : 'Out of stock',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: product.inStock ? AppColors.emerald500 : AppColors.rose500,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '\$${product.price.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.blue600,
                              ),
                            ),
                            if (product.originalPrice != null)
                              Text(
                                '\$${product.originalPrice!.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: AppColors.slate400,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                        ValueListenableBuilder<List<CartItem>>(
                          valueListenable: CartStore.instance,
                          builder: (context, items, _) {
                            final inCart = items.any(
                                (e) => e.product.id == product.id);
                            return GestureDetector(
                              onTap: !product.inStock
                                  ? null
                                  : () {
                                      CartStore.instance.add(product);
                                      MarketService(ApiClient())
                                          .trackEvent(product.id, 'cart_add');
                                      ScaffoldMessenger.of(context)
                                          .clearSnackBars();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${product.name} added to cart',
                                            style: GoogleFonts.poppins(
                                                fontSize: 13),
                                          ),
                                          duration: const Duration(seconds: 1),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          backgroundColor: AppColors.slate800,
                                        ),
                                      );
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  gradient: inCart
                                      ? AppGradients.primaryBtn
                                      : null,
                                  color: inCart
                                      ? null
                                      : (isDark
                                          ? AppColors.slate700
                                          : AppColors.slate100),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Icon(
                                  inCart
                                      ? Icons.check_rounded
                                      : Icons.add_rounded,
                                  size: 16,
                                  color: !product.inStock
                                      ? AppColors.slate400
                                      : (inCart
                                          ? Colors.white
                                          : AppColors.blue600),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final List<Color> colors;
  final String? category;

  const _Placeholder({required this.colors, this.category});

  static const _catIcons = {
    'Electronics': Icons.laptop_mac_rounded,
    'Audio': Icons.headphones_rounded,
    'Wearables': Icons.watch_rounded,
    'Fashion': Icons.checkroom_rounded,
    'Photography': Icons.camera_alt_rounded,
    'Home & Living': Icons.chair_rounded,
    'Beauty & Health': Icons.auto_awesome_rounded,
    'Sports & Outdoors': Icons.fitness_center_rounded,
    'Groceries': Icons.shopping_basket_rounded,
    'Books & Media': Icons.menu_book_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(
          _catIcons[category] ?? Icons.inventory_2_rounded,
          color: Colors.white.withValues(alpha: 0.6),
          size: 36,
        ),
      ),
    );
  }
}
