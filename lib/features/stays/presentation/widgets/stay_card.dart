import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/stay_model.dart';

class StayCard extends StatelessWidget {
  final StayModel stay;
  final VoidCallback? onTap;

  const StayCard({super.key, required this.stay, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : AppColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: isDark ? 0.3 : 0.07),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardImage(stay: stay),
            _CardBody(stay: stay, isDark: isDark),
          ],
        ),
      ),
    );
  }
}

// ─── Card Image ─────────────────────────────────────────────────────────────

class _CardImage extends StatelessWidget {
  final StayModel stay;
  const _CardImage({required this.stay});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover image / fallback
          stay.coverImage != null
              ? Hero(
                  tag: 'stay-${stay.id}',
                  child: CachedNetworkImage(
                    imageUrl: stay.coverImage!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _ImagePlaceholder(stay: stay),
                    errorWidget: (_, __, ___) => _ImagePlaceholder(stay: stay),
                  ),
                )
              : _ImagePlaceholder(stay: stay),

          // Gradient scrim
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppColors.black.withValues(alpha: 0.60),
                  AppColors.black.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),

          // Property type badge — top left
          if (stay.propertyType != null || stay.categoryName != null)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.50),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.2)),
                ),
                child: Text(
                  stay.propertyType ?? stay.categoryName ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),

          // Multi-image indicator — top right
          if (stay.imageUrls.length > 1)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library_outlined,
                        color: AppColors.white, size: 10),
                    const SizedBox(width: 3),
                    Text(
                      '${stay.imageUrls.length}',
                      style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white),
                    ),
                  ],
                ),
              ),
            ),

          // Location + price at bottom
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                if (stay.location.isNotEmpty)
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 11, color: AppColors.white),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            stay.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.white
                                  .withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (stay.pricePerNight != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.blue600,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '\$${stay.pricePerNight!.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card Body ───────────────────────────────────────────────────────────────

class _CardBody extends StatelessWidget {
  final StayModel stay;
  final bool isDark;
  const _CardBody({required this.stay, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final hasRating = stay.averageRating > 0;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              stay.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.white : AppColors.gray900,
              ),
            ),

            const SizedBox(height: 4),

            // Rating row
            if (hasRating)
              Row(
                children: [
                  ...List.generate(5, (i) {
                    return Icon(
                      i < stay.averageRating.floor()
                          ? Icons.star_rounded
                          : (i < stay.averageRating
                              ? Icons.star_half_rounded
                              : Icons.star_outline_rounded),
                      color: AppColors.amber400,
                      size: 11,
                    );
                  }),
                  const SizedBox(width: 4),
                  Text(
                    '${stay.averageRating.toStringAsFixed(1)}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.slate300 : AppColors.slate700,
                    ),
                  ),
                  if (stay.reviewCount > 0) ...[
                    Text(
                      ' (${stay.reviewCount})',
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: AppColors.slate400),
                    ),
                  ],
                ],
              )
            else
              Text(
                'New listing',
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppColors.blue600,
                    fontWeight: FontWeight.w600),
              ),

            const SizedBox(height: 4),

            // Beds + baths quick info
            if (stay.bedroomCount != null || stay.maxGuests != null)
              Row(
                children: [
                  if (stay.bedroomCount != null) ...[
                    const Icon(Icons.bed_rounded,
                        size: 11, color: AppColors.slate400),
                    const SizedBox(width: 3),
                    Text(
                      '${stay.bedroomCount}bd',
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: AppColors.slate500),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (stay.bathroomCount != null) ...[
                    const Icon(Icons.bathtub_outlined,
                        size: 11, color: AppColors.slate400),
                    const SizedBox(width: 3),
                    Text(
                      '${stay.bathroomCount!.toStringAsFixed(stay.bathroomCount! % 1 == 0 ? 0 : 1)}ba',
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: AppColors.slate500),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (stay.maxGuests != null) ...[
                    const Icon(Icons.people_outline_rounded,
                        size: 11, color: AppColors.slate400),
                    const SizedBox(width: 3),
                    Text(
                      '${stay.maxGuests}g',
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: AppColors.slate500),
                    ),
                  ],
                ],
              ),

            const Spacer(),

            // Book button
            Container(
              width: double.infinity,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppGradients.primaryBtn,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.blue600.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'Book Now',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Image placeholder ───────────────────────────────────────────────────────

class _ImagePlaceholder extends StatelessWidget {
  final StayModel stay;
  const _ImagePlaceholder({required this.stay});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
        ),
      ),
      child: Center(
        child: Icon(
          stay.propertyType?.toLowerCase().contains('villa') == true
              ? Icons.villa_rounded
              : stay.propertyType?.toLowerCase().contains('hotel') == true
                  ? Icons.hotel_rounded
                  : Icons.house_rounded,
          color: AppColors.white.withValues(alpha: 0.35),
          size: 44,
        ),
      ),
    );
  }
}
