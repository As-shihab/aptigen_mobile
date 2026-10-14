import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/http_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/media_url.dart';
import '../data/cart_store.dart';
import '../data/market_service.dart';
import '../models/product_model.dart';
import 'store_profile_page.dart';

class ProductDetailPage extends StatefulWidget {
  final ProductModel product;
  /// Must match the `heroTagPrefix` of whichever `ProductCard` was tapped to
  /// get here — see `ProductCard.heroTagPrefix` for why this needs to vary.
  final String? heroTagPrefix;
  const ProductDetailPage({super.key, required this.product, this.heroTagPrefix});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage>
    with TickerProviderStateMixin {
  final _service = MarketService(ApiClient());
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

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

  static const _conditionLabels = {
    'new': 'New',
    'used': 'Used',
    'refurbished': 'Refurbished',
  };

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeAnim =
        Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _slideCtrl,
      curve: const Interval(0, 0.7, curve: Curves.easeOut),
    ));
    _slideCtrl.forward();
    _service.trackEvent(widget.product.id, 'view');
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final discount = product.effectiveDiscount;
    final colors = _catColors[product.category] ??
        [AppColors.slate600, AppColors.slate700];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.white,
      body: Stack(
        children: [
          // Image gallery
          SizedBox(
            height: size.height * 0.46,
            width: double.infinity,
            child: _ProductImageGallery(product: product, colors: colors, heroTagPrefix: widget.heroTagPrefix),
          ),
          // Gradient fade bottom of image
          Positioned(
            left: 0,
            right: 0,
            top: size.height * 0.28,
            height: size.height * 0.18,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    (isDark ? AppColors.darkBg : AppColors.white)
                        .withValues(alpha: 0.95),
                  ],
                ),
              ),
            ),
          ),
          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: _CircleBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              isDark: isDark,
              onTap: () => Navigator.pop(context),
            ),
          ),
          // Wishlist button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: _CircleBtn(
              icon: Icons.favorite_border_rounded,
              isDark: isDark,
              onTap: () {},
            ),
          ),
          // Scrollable content card
          DraggableScrollableSheet(
            initialChildSize: 0.58,
            minChildSize: 0.58,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [0.58, 0.92],
            builder: (_, controller) {
              return FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate900 : AppColors.white,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 32,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    child: ListView(
                      controller: controller,
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).padding.bottom + 100),
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 12, bottom: 20),
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.slate700
                                  : AppColors.slate200,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category + condition row
                              Row(
                                children: [
                                  if (product.category != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.slate800
                                            : AppColors.slate100,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        product.category!,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: isDark
                                              ? AppColors.slate400
                                              : AppColors.slate600,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.slate800
                                          : AppColors.slate100,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _conditionLabels[product.condition] ??
                                          product.condition,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.slate400
                                            : AppColors.slate600,
                                      ),
                                    ),
                                  ),
                                  if (discount != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.rose500
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '-$discount% OFF',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.rose500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Product name
                              Text(
                                product.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.slate900,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Price
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${product.price.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.blue600,
                                    ),
                                  ),
                                  if (product.originalPrice != null) ...[
                                    const SizedBox(width: 10),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        '\$${product.originalPrice!.toStringAsFixed(2)}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          color: AppColors.slate400,
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Stock badge
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: product.inStock
                                          ? AppColors.emerald500
                                          : AppColors.rose500,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    product.inStock
                                        ? '${product.quantity} in stock'
                                        : 'Out of Stock',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: product.inStock
                                          ? AppColors.emerald500
                                          : AppColors.rose500,
                                    ),
                                  ),
                                ],
                              ),
                              if (product.city != null || product.country != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 14, color: AppColors.slate400),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Ships from ${[product.city, product.country].where((e) => e != null && e.isNotEmpty).join(', ')}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppColors.slate500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 20),
                              // Divider
                              Divider(
                                color: isDark
                                    ? AppColors.slate800
                                    : AppColors.slate100,
                              ),
                              const SizedBox(height: 16),
                              // Description
                              if (product.description != null) ...[
                                Text(
                                  'About this product',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.slate900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  product.description!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppColors.slate500,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              // Product details — only rows with real data render
                              _ProductDetailsSection(product: product, isDark: isDark),
                              const SizedBox(height: 20),
                              // Sold by
                              _StoreSection(
                                  product: product, isDark: isDark),
                              const SizedBox(height: 20),
                              // Highlights
                              _HighlightRow(isDark: isDark),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Bottom CTA bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomBar(product: product, isDark: isDark),
          ),
        ],
      ),
    );
  }
}

// ─── Image Gallery ──────────────────────────────────────────────────────────

class _ProductImageGallery extends StatefulWidget {
  final ProductModel product;
  final List<Color> colors;
  final String? heroTagPrefix;
  const _ProductImageGallery({required this.product, required this.colors, this.heroTagPrefix});

  @override
  State<_ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<_ProductImageGallery> {
  final _pageCtrl = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.product.images;
    final placeholder = _PlaceholderBg(
      colors: widget.colors,
      category: widget.product.category,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        images.isEmpty
            ? Hero(
                tag: 'product-image-${widget.heroTagPrefix ?? ''}${widget.product.id}',
                child: placeholder,
              )
            : PageView.builder(
                controller: _pageCtrl,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) {
                  final url = MediaUrl.resolve(images[i], view: 'large') ?? images[i];
                  final image = CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => placeholder,
                    errorWidget: (_, __, ___) => placeholder,
                  );
                  return i == 0
                      ? Hero(
                          tag: 'product-image-${widget.heroTagPrefix ?? ''}${widget.product.id}',
                          child: image,
                        )
                      : image;
                },
              ),

        // Page dots
        if (images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(images.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _current ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _current
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ),

        // Image count badge
        if (images.length > 1)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_current + 1} / ${images.length}',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Bottom CTA ────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final ProductModel product;
  final bool isDark;
  const _BottomBar({required this.product, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return ClipRect(
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 14, 20, bottom + 14),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.slate900.withValues(alpha: 0.95)
              : AppColors.white.withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(
              color:
                  isDark ? AppColors.slate800 : AppColors.slate100,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Wishlist
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : AppColors.slate100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isDark
                        ? AppColors.slate700
                        : AppColors.slate200),
              ),
              child: const Icon(Icons.favorite_border_rounded,
                  color: AppColors.rose500, size: 22),
            ),
            const SizedBox(width: 12),
            // Add to cart
            Expanded(
              child: ValueListenableBuilder<List<CartItem>>(
                valueListenable: CartStore.instance,
                builder: (context, items, _) {
                  final inCart =
                      items.any((e) => e.product.id == product.id);
                  final qty = inCart
                      ? items
                          .firstWhere((e) => e.product.id == product.id)
                          .qty
                      : 0;
                  return GestureDetector(
                    onTap: !product.inStock
                        ? null
                        : () {
                            CartStore.instance.add(product);
                            MarketService(ApiClient())
                                .trackEvent(product.id, 'cart_add');
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added to cart',
                                    style: GoogleFonts.poppins(fontSize: 13)),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                backgroundColor: AppColors.slate800,
                              ),
                            );
                          },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: product.inStock ? AppGradients.primaryBtn : null,
                        color: product.inStock ? null : AppColors.slate300,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          !product.inStock
                              ? 'Out of Stock'
                              : (inCart ? 'Add More ($qty)' : 'Add to Cart'),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Highlight Row ──────────────────────────────────────────────────────────

class _HighlightRow extends StatelessWidget {
  final bool isDark;
  const _HighlightRow({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final highlights = [
      (Icons.verified_rounded, 'Genuine', 'Verified products'),
      (Icons.local_shipping_rounded, 'Fast Ship', 'Next-day delivery'),
      (Icons.assignment_return_rounded, 'Returns', '30-day returns'),
    ];
    return Row(
      children: highlights.map((h) {
        final (icon, title, sub) = h;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : AppColors.slate50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.slate700 : AppColors.slate100,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: AppColors.blue600, size: 20),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.slate800,
                  ),
                ),
                Text(
                  sub,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: AppColors.slate400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Product Details ────────────────────────────────────────────────────────

class _ProductDetailsSection extends StatelessWidget {
  final ProductModel product;
  final bool isDark;
  const _ProductDetailsSection({required this.product, required this.isDark});

  static const _conditionLabels = {
    'new': 'New',
    'used': 'Used',
    'refurbished': 'Refurbished',
  };
  static const _listingTypeLabels = {
    'fixed': 'Fixed price',
    'auction': 'Auction',
    'negotiable': 'Negotiable',
  };

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if (product.category != null) ('Category', product.category!),
      ('Condition', _conditionLabels[product.condition] ?? product.condition),
      ('Listing type', _listingTypeLabels[product.listingType] ?? product.listingType),
      if (product.minOrder > 1) ('Minimum order', '${product.minOrder} units'),
      if (product.maxOrder != null) ('Maximum order', '${product.maxOrder} units'),
      if (product.city != null || product.country != null)
        ('Location', [product.city, product.country].where((e) => e != null && e.isNotEmpty).join(', ')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product details',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.slate900,
          ),
        ),
        const SizedBox(height: 10),
        ...rows.map((r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(r.$1,
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.slate500)),
                  Text(r.$2,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.slate800,
                      )),
                ],
              ),
            )),
        if (product.tags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: product.tags
                .map((tag) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.blue600.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.blue600,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

// ─── Store Section ─────────────────────────────────────────────────────────

// Compact "sold by" card — matches the web view.client.tsx inline seller
// card: logo/initials, name, verified badge and a visit-store link. No
// rating/follower stat here since the listing payload doesn't carry one
// (that lives on the full store profile fetched by StoreProfilePage).
class _StoreSection extends StatelessWidget {
  final ProductModel product;
  final bool isDark;
  const _StoreSection({required this.product, required this.isDark});

  void _goToStore(BuildContext context) {
    if (product.sellerId == 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreProfilePage(storeId: product.sellerId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logoUrl = MediaUrl.resolve(product.sellerLogoUrl, view: 'small');
    final accent = product.sellerAccentColor;
    final accentColor = accent != null && RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(accent)
        ? Color(int.parse('FF${accent.replaceAll('#', '')}', radix: 16))
        : AppColors.slate600;

    return GestureDetector(
      onTap: () => _goToStore(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : AppColors.slate50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate100),
        ),
        child: Row(
          children: [
            // Avatar circle
            Container(
              width: 46,
              height: 46,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
              child: logoUrl != null
                  ? Image.network(logoUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              product.sellerName
                                  .substring(0, product.sellerName.length >= 2 ? 2 : 1)
                                  .toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ))
                  : Center(
                      child: Text(
                        product.sellerName
                            .substring(0, product.sellerName.length >= 2 ? 2 : 1)
                            .toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            // Store info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sold by',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.slate500)),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          product.sellerName,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (product.sellerVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded,
                            size: 14, color: AppColors.blue600),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (product.sellerId != 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate700 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark ? AppColors.slate600 : AppColors.slate200),
                ),
                child: Text(
                  'Visit Store',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.slate800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ───────────────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  const _CircleBtn(
      {required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.slate900.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
            ),
          ],
        ),
        child: Icon(icon,
            size: 18,
            color: isDark ? AppColors.slate300 : AppColors.slate700),
      ),
    );
  }
}

class _PlaceholderBg extends StatelessWidget {
  final List<Color> colors;
  final String? category;
  const _PlaceholderBg({required this.colors, this.category});

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
          color: Colors.white.withValues(alpha: 0.4),
          size: 80,
        ),
      ),
    );
  }
}
