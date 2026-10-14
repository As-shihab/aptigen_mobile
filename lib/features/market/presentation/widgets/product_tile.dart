import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency.dart';
import '../../data/cart_store.dart';
import '../../data/wishlist_store.dart';
import '../../models/product_model.dart';
import '../market_nav.dart';
import 'common.dart';
import 'countdown.dart';
import 'rating_stars.dart';

/// Product tile — port of the web market's ProductTile.tsx: no card box,
/// a rounded photo with a discount/featured badge and frosted wishlist
/// heart, then name, location, price and a stock hint, with a round
/// quick-add button that flashes green when tapped.
class ProductTile extends StatelessWidget {
  final ProductModel product;
  const ProductTile(this.product, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final stock = product.stock;
    final out = product.outOfStock;
    final flash = product.liveFlash;

    // Discount wins over any other badge — it's the more useful fact.
    final (String, Color)? badge = flash != null
        ? (product.discountPercent > 0 ? 'Flash sale -${product.discountPercent}%' : 'Flash sale', AppColors.danger)
        : product.onSale
            ? ('-${product.discountPercent}%', AppColors.danger)
            : product.isFeatured
                ? ('Featured', AppColors.warning)
                : null;

    final (String, Color)? stockHint = stock == null
        ? null
        : out
            ? ('Out of stock', AppColors.danger)
            : stock <= 5
                ? ('Only $stock left', AppColors.warning)
                : ('In stock', AppColors.success);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openProduct(context, product.id, preview: product),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(opacity: out ? 0.6 : 1, child: NetImage(product.coverUrl)),
                  if (badge != null)
                    // Kept clear of the heart; shrinks on the narrowest tiles.
                    Positioned(
                      left: 8,
                      top: 8,
                      right: 48,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: badge.$2, borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              badge.$1,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, height: 1.3, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(right: 8, top: 8, child: WishlistHeart(product.id, size: 34)),
                ],
              ),
            ),
          ),
          SizedBox(
            height: kTileInfoHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, height: 1.35, color: p.text),
                  ),
                  if (product.ratingCount > 0) ...[
                    const SizedBox(height: 4),
                    RatingStars(value: product.ratingAvg, count: product.ratingCount, size: 12),
                  ],
                  if (product.location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 12, color: p.textSecondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            product.location!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, height: 1.3, color: p.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.end,
                              spacing: 5,
                              children: [
                                Text(
                                  formatPrice(product.effectivePrice, product.currency),
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.2,
                                    fontWeight: FontWeight.w600,
                                    color: flash != null ? AppColors.danger : p.text,
                                  ),
                                ),
                                if (product.strikePrice != null)
                                  Text(
                                    formatPrice(product.strikePrice!, product.currency),
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.5,
                                      color: p.textTertiary,
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: p.textTertiary,
                                    ),
                                  ),
                              ],
                            ),
                            if (flash != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: FlashLeftLine(flash: flash),
                              )
                            else if (stockHint != null || product.minOrder > 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text.rich(
                                  TextSpan(children: [
                                    if (stockHint != null)
                                      TextSpan(text: stockHint.$1, style: TextStyle(color: stockHint.$2)),
                                    if (stockHint != null && product.minOrder > 1)
                                      TextSpan(text: ' · ', style: TextStyle(color: p.textTertiary)),
                                    if (product.minOrder > 1)
                                      TextSpan(
                                          text: 'Min order ${product.minOrder}',
                                          style: TextStyle(color: p.textSecondary)),
                                  ]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10.5, height: 1.3, fontWeight: FontWeight.w500),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      QuickAddButton(product: product, color: badge?.$2 ?? p.accent),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "N left · ends in 3h 12m" under a flash-sale price.
class FlashLeftLine extends StatelessWidget {
  final FlashPrice flash;
  final double fontSize;
  const FlashLeftLine({super.key, required this.flash, this.fontSize = 10.5});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: fontSize, height: 1.3, fontWeight: FontWeight.w500, color: AppColors.danger);
    return Row(
      children: [
        Icon(Icons.bolt_rounded, size: fontSize + 2, color: AppColors.danger),
        const SizedBox(width: 2),
        Expanded(
          child: Countdown(
            endsAt: flash.endsAt,
            format: CountdownFormat.short,
            prefix: flash.remaining != null ? '${flash.remaining} left · ends in ' : 'Ends in ',
            endedLabel: 'Sale ended',
            style: style,
          ),
        ),
      ],
    );
  }
}

/// Round add-to-cart button; tone follows the tile's badge (sale = red,
/// featured = amber) like the web, and flashes green with a check on add.
class QuickAddButton extends StatefulWidget {
  final ProductModel product;
  final Color color;
  const QuickAddButton({super.key, required this.product, required this.color});

  @override
  State<QuickAddButton> createState() => _QuickAddButtonState();
}

class _QuickAddButtonState extends State<QuickAddButton> {
  bool _added = false;

  void _add() {
    CartStore.instance.addProduct(widget.product);
    setState(() => _added = true);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _added = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final disabled = widget.product.outOfStock;
    return Semantics(
      button: true,
      label: _added ? '${widget.product.title} added to cart' : 'Add ${widget.product.title} to cart',
      child: GestureDetector(
        onTap: disabled ? null : _add,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: disabled ? p.fill : (_added ? AppColors.success : widget.color),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Icon(
              _added ? Icons.check_rounded : Icons.add_shopping_cart_rounded,
              key: ValueKey(_added),
              size: 18,
              color: disabled ? p.textTertiary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted heart over product photos. Guests are sent to sign in first.
class WishlistHeart extends StatelessWidget {
  final int listingId;
  final double size;
  const WishlistHeart(this.listingId, {super.key, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<int>>(
      valueListenable: WishlistStore.instance,
      builder: (context, ids, _) {
        final liked = ids.contains(listingId);
        return GestureDetector(
          onTap: () async {
            if (!await ensureSignedIn(context, reason: 'Sign in to save items')) return;
            await WishlistStore.instance.toggle(listingId);
          },
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            ),
            child: Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: size * 0.52,
              color: liked ? AppColors.danger : const Color(0xFF1F2937),
            ),
          ),
        );
      },
    );
  }
}

/// Horizontal scrolling row of product tiles.
class ProductRow extends StatelessWidget {
  final List<ProductModel> products;
  const ProductRow(this.products, {super.key});

  @override
  Widget build(BuildContext context) {
    const width = 160.0;
    return SizedBox(
      height: width + kTileInfoHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(width: width, child: ProductTile(products[i])),
      ),
    );
  }
}
