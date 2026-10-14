import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency.dart';
import '../../models/market_extras.dart';
import '../market_nav.dart';
import 'common.dart';
import 'countdown.dart';
import 'product_tile.dart';

/// Text block under the square photo on a [FlashSaleCard].
const double kFlashInfoHeight = 126;

/// Units still available at the sale price, or null when the sale has no cap.
int? flashRemaining(FlashSaleListing item) {
  final r = item.product.flashSale?.remaining;
  if (r != null) return r < 0 ? 0 : r;
  if (item.stockLimit != null) {
    final left = item.stockLimit! - item.soldCount;
    return left < 0 ? 0 : left;
  }
  return null;
}

/// One flash-sale product — port of `FlashSaleCard` in FlashSaleStrip.tsx:
/// photo with % off, sale price over the struck original, quick add and,
/// when the seller capped the sale's stock, a sold bar with units left.
class FlashSaleCard extends StatelessWidget {
  final FlashSaleListing item;
  const FlashSaleCard(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final l = item.product;
    final remaining = flashRemaining(item);
    final soldOut = remaining == 0;
    final strike = l.strikePrice;
    final pct = l.discountPercent;
    final ratio = item.soldRatio;
    final barBg = p.isDark ? AppColors.danger.withValues(alpha: 0.18) : const Color(0xFFFEE2E2);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openProduct(context, l.id, preview: l),
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
                  Opacity(opacity: soldOut ? 0.6 : 1, child: NetImage(l.coverUrl)),
                  if (pct > 0)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Pill('-$pct%', bg: AppColors.danger, fg: Colors.white),
                    ),
                  Positioned(right: 8, top: 8, child: WishlistHeart(l.id, size: 34)),
                ],
              ),
            ),
          ),
          SizedBox(
            height: kFlashInfoHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, height: 1.35, color: p.text),
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.end,
                          spacing: 5,
                          children: [
                            Text(
                              formatPrice(l.effectivePrice, l.currency),
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                                color: AppColors.danger,
                              ),
                            ),
                            if (strike != null)
                              Text(
                                formatPrice(strike, l.currency),
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
                      ),
                      const SizedBox(width: 6),
                      IgnorePointer(
                        ignoring: soldOut,
                        child: Opacity(
                          opacity: soldOut ? 0.4 : 1,
                          child: QuickAddButton(product: l, color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                  if (item.stockLimit != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio ?? 0,
                        minHeight: 5,
                        backgroundColor: barBg,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      soldOut ? 'Sold out at this price' : '$remaining left · ${item.soldCount} sold',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: soldOut ? p.textTertiary : const Color(0xFFB91C1C),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 23),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Ends in 01:22:09" on a soft red chip.
class SaleCountdownChip extends StatelessWidget {
  final DateTime endsAt;
  final bool showLabel;
  const SaleCountdownChip({super.key, required this.endsAt, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final fg = p.isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: p.isDark ? AppColors.danger.withValues(alpha: 0.16) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 14, color: fg),
          const SizedBox(width: 4),
          Countdown(
            endsAt: endsAt,
            prefix: showLabel ? 'Ends in ' : '',
            endedLabel: 'Ended',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}

/// Horizontal row of [FlashSaleCard]s.
class FlashSaleRow extends StatelessWidget {
  final List<FlashSaleListing> items;
  const FlashSaleRow(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    const width = 150.0;
    return SizedBox(
      height: width + kFlashInfoHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(width: width, child: FlashSaleCard(items[i])),
      ),
    );
  }
}

/// Grid delegate for [FlashSaleCard]s — square photo plus fixed info block.
SliverGridDelegate flashGridDelegate(BuildContext context, {double horizontalPadding = 32}) {
  final width = MediaQuery.sizeOf(context).width;
  final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
  const spacing = 12.0;
  final tileWidth = (width - horizontalPadding - spacing * (columns - 1)) / columns;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    crossAxisSpacing: spacing,
    mainAxisSpacing: 16,
    mainAxisExtent: tileWidth + kFlashInfoHeight,
  );
}
