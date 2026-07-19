import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../models/stay_model.dart';

class StayDetailPage extends StatefulWidget {
  final StayModel stay;
  const StayDetailPage({super.key, required this.stay});

  @override
  State<StayDetailPage> createState() => _StayDetailPageState();
}

class _StayDetailPageState extends State<StayDetailPage> {
  bool _descExpanded = false;

  @override
  Widget build(BuildContext context) {
    final stay = widget.stay;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Hero image gallery ──────────────────────────────────────
              SliverAppBar(
                expandedHeight: 360,
                pinned: true,
                backgroundColor: bg,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: _CircleBtn(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                actions: [
                  _CircleBtn(icon: Icons.favorite_border_rounded, onTap: () {}),
                  _CircleBtn(icon: Icons.share_outlined, onTap: () {}),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _ImageGallery(stay: stay),
                ),
              ),

              // ── Content ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges
                      _BadgesRow(stay: stay),
                      const SizedBox(height: 12),

                      // Title
                      Text(
                        stay.title,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.slate900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Rating row
                      if (stay.reviewCount > 0 || stay.averageRating > 0)
                        _RatingRow(stay: stay, isDark: isDark),

                      const SizedBox(height: 16),

                      // Location card
                      if (stay.location.isNotEmpty || stay.address != null)
                        _LocationCard(stay: stay, isDark: isDark),

                      const SizedBox(height: 20),

                      // Stats grid
                      _StatsGrid(stay: stay, isDark: isDark),

                      const SizedBox(height: 24),
                      _Divider(isDark: isDark),
                      const SizedBox(height: 20),

                      // About
                      if (stay.description != null &&
                          stay.description!.isNotEmpty) ...[
                        _SectionTitle('About this place', isDark: isDark),
                        const SizedBox(height: 10),
                        _ExpandableText(
                          text: stay.description!,
                          expanded: _descExpanded,
                          onToggle: () =>
                              setState(() => _descExpanded = !_descExpanded),
                          isDark: isDark,
                        ),
                        const SizedBox(height: 24),
                        _Divider(isDark: isDark),
                        const SizedBox(height: 20),
                      ],

                      // Amenities
                      if (stay.amenities.isNotEmpty) ...[
                        _SectionTitle('What this place offers', isDark: isDark),
                        const SizedBox(height: 14),
                        _AmenitiesGrid(
                            amenities: stay.amenities, isDark: isDark),
                        const SizedBox(height: 24),
                        _Divider(isDark: isDark),
                        const SizedBox(height: 20),
                      ],

                      // Reviews
                      if (stay.reviews.isNotEmpty) ...[
                        _ReviewsSection(stay: stay, isDark: isDark),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Sticky bottom CTA ──────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomBar(stay: stay, isDark: isDark),
          ),
        ],
      ),
    );
  }
}

// ─── Image Gallery ──────────────────────────────────────────────────────────

class _ImageGallery extends StatefulWidget {
  final StayModel stay;
  const _ImageGallery({required this.stay});

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  final _pageCtrl = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.stay.imageUrls;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Image(s)
        images.isEmpty
            ? _NoImage(stay: widget.stay)
            : images.length == 1
                ? Hero(
                    tag: 'stay-${widget.stay.id}',
                    child: CachedNetworkImage(
                        imageUrl: images.first, fit: BoxFit.cover),
                  )
                : PageView.builder(
                    controller: _pageCtrl,
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _current = i),
                    itemBuilder: (_, i) => i == 0
                        ? Hero(
                            tag: 'stay-${widget.stay.id}',
                            child: CachedNetworkImage(
                                imageUrl: images[i], fit: BoxFit.cover),
                          )
                        : CachedNetworkImage(
                            imageUrl: images[i], fit: BoxFit.cover),
                  ),

        // Gradient scrim
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
        ),

        // Page dots
        if (images.length > 1)
          Positioned(
            bottom: 20,
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: Colors.black.withValues(alpha: 0.35),
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
            ),
          ),
      ],
    );
  }
}

class _NoImage extends StatelessWidget {
  final StayModel stay;
  const _NoImage({required this.stay});

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
        child: Icon(Icons.hotel_rounded,
            size: 80, color: Colors.white.withValues(alpha: 0.3)),
      ),
    );
  }
}

// ─── Badges Row ─────────────────────────────────────────────────────────────

class _BadgesRow extends StatelessWidget {
  final StayModel stay;
  const _BadgesRow({required this.stay});

  @override
  Widget build(BuildContext context) {
    final badges = <String>[
      if (stay.categoryName != null) stay.categoryName!,
      if (stay.propertyType != null) stay.propertyType!,
      if (stay.roomType != null) stay.roomType!,
    ];
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      children: badges
          .map((b) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.blue600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  b,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blue600,
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ─── Rating Row ─────────────────────────────────────────────────────────────

class _RatingRow extends StatelessWidget {
  final StayModel stay;
  final bool isDark;
  const _RatingRow({required this.stay, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final avg = stay.averageRating;
    return Row(
      children: [
        ...List.generate(5, (i) {
          return Icon(
            i < avg.floor()
                ? Icons.star_rounded
                : (i < avg ? Icons.star_half_rounded : Icons.star_outline_rounded),
            color: AppColors.amber400,
            size: 18,
          );
        }),
        const SizedBox(width: 8),
        Text(
          avg.toStringAsFixed(1),
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.slate800,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '· ${stay.reviewCount} review${stay.reviewCount == 1 ? '' : 's'}',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.slate500,
            decoration: TextDecoration.underline,
          ),
        ),
      ],
    );
  }
}

// ─── Location Card ──────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final StayModel stay;
  final bool isDark;
  const _LocationCard({required this.stay, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.slate100),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.blue600.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.location_on_rounded,
                color: AppColors.blue600, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stay.location.isNotEmpty ? stay.location : 'Location',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
                if (stay.address != null && stay.address!.isNotEmpty)
                  Text(
                    stay.address!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.slate500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.blue600,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Map',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Grid ─────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final StayModel stay;
  final bool isDark;
  const _StatsGrid({required this.stay, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final tiles = <_StatData>[
      if (stay.maxGuests != null)
        _StatData(Icons.people_outline_rounded, '${stay.maxGuests}', 'Guests'),
      if (stay.bedroomCount != null)
        _StatData(Icons.bed_rounded, '${stay.bedroomCount}', 'Bedrooms'),
      if (stay.bathroomCount != null)
        _StatData(
          Icons.bathtub_outlined,
          stay.bathroomCount! % 1 == 0
              ? '${stay.bathroomCount!.toInt()}'
              : '${stay.bathroomCount}',
          'Bathrooms',
        ),
      if (stay.bedCount != null)
        _StatData(Icons.single_bed_rounded, '${stay.bedCount}', 'Beds'),
    ];

    if (tiles.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.8,
      ),
      itemCount: tiles.length,
      itemBuilder: (_, i) => _StatTile(data: tiles[i], isDark: isDark),
    );
  }
}

class _StatData {
  final IconData icon;
  final String value;
  final String label;
  const _StatData(this.icon, this.value, this.label);
}

class _StatTile extends StatelessWidget {
  final _StatData data;
  final bool isDark;
  const _StatTile({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.slate100),
      ),
      child: Row(
        children: [
          Icon(data.icon, size: 20, color: AppColors.blue600),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                data.value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.slate900,
                  height: 1,
                ),
              ),
              Text(
                data.label,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.slate500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Expandable Description ─────────────────────────────────────────────────

class _ExpandableText extends StatelessWidget {
  final String text;
  final bool expanded;
  final VoidCallback onToggle;
  final bool isDark;
  const _ExpandableText({
    required this.text,
    required this.expanded,
    required this.onToggle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: expanded ? null : 4,
          overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isDark ? AppColors.slate400 : AppColors.slate600,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onToggle,
          child: Text(
            expanded ? 'Show less ↑' : 'Show more ↓',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.blue600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Amenities Grid ─────────────────────────────────────────────────────────

class _AmenitiesGrid extends StatelessWidget {
  final List<AmenityModel> amenities;
  final bool isDark;
  const _AmenitiesGrid({required this.amenities, required this.isDark});

  static const _iconMap = <String, IconData>{
    'wifi': Icons.wifi_rounded,
    'pool': Icons.pool_rounded,
    'parking': Icons.local_parking_rounded,
    'gym': Icons.fitness_center_rounded,
    'kitchen': Icons.kitchen_rounded,
    'ac': Icons.ac_unit_rounded,
    'tv': Icons.tv_rounded,
    'washer': Icons.local_laundry_service_rounded,
    'dryer': Icons.dry_cleaning_rounded,
    'heating': Icons.wb_sunny_outlined,
    'balcony': Icons.deck_rounded,
    'spa': Icons.spa_rounded,
    'beach': Icons.beach_access_rounded,
    'pet': Icons.pets_rounded,
    'breakfast': Icons.breakfast_dining_rounded,
  };

  IconData _iconFor(AmenityModel a) {
    final k = a.key.toLowerCase();
    for (final entry in _iconMap.entries) {
      if (k.contains(entry.key)) return entry.value;
    }
    return Icons.check_circle_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 3.2,
      ),
      itemCount: amenities.length,
      itemBuilder: (_, i) {
        final a = amenities[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate800 : AppColors.slate50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark ? AppColors.slate700 : AppColors.slate100),
          ),
          child: Row(
            children: [
              Icon(_iconFor(a), size: 18, color: AppColors.blue600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.slate300 : AppColors.slate700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Reviews Section ─────────────────────────────────────────────────────────

class _ReviewsSection extends StatefulWidget {
  final StayModel stay;
  final bool isDark;
  const _ReviewsSection({required this.stay, required this.isDark});

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final reviews = widget.stay.reviews;
    final shown = _showAll ? reviews : reviews.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            _SectionTitle(
                '${reviews.length} Review${reviews.length == 1 ? '' : 's'}',
                isDark: widget.isDark),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.star_rounded,
                    color: AppColors.amber400, size: 16),
                const SizedBox(width: 4),
                Text(
                  widget.stay.averageRating.toStringAsFixed(1),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...shown.map((r) => _ReviewCard(review: r, isDark: widget.isDark)),
        if (reviews.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: GestureDetector(
              onTap: () => setState(() => _showAll = !_showAll),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: widget.isDark
                          ? AppColors.slate700
                          : AppColors.slate200),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    _showAll
                        ? 'Show less'
                        : 'Show all ${reviews.length} reviews',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blue600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  final bool isDark;
  const _ReviewCard({required this.review, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isDark ? AppColors.slate700 : AppColors.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reviewer info
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.blue600, AppColors.indigo600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    review.initials,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                    ),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < review.rating.floor()
                                ? Icons.star_rounded
                                : (i < review.rating
                                    ? Icons.star_half_rounded
                                    : Icons.star_outline_rounded),
                            color: AppColors.amber400,
                            size: 13,
                          ),
                        ),
                        if (review.timeAgo.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            review.timeAgo,
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppColors.slate500),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: isDark ? AppColors.slate400 : AppColors.slate600,
                height: 1.55,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Bottom Bar ──────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final StayModel stay;
  final bool isDark;
  const _BottomBar({required this.stay, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 14, 20, bottom + 14),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.slate900.withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.88),
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.slate800 : AppColors.slate100,
              ),
            ),
          ),
          child: Row(
            children: [
              // Price
              if (stay.pricePerNight != null)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${stay.pricePerNight!.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            ' / night',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppColors.slate500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (stay.cleaningFee != null && stay.cleaningFee! > 0)
                      Text(
                        '+\$${stay.cleaningFee!.toStringAsFixed(0)} cleaning',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppColors.slate500),
                      ),
                  ],
                ),
              const Spacer(),
              // Book button
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.blue600, AppColors.indigo600],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.blue600.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    'Book Now',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared helpers ──────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionTitle(this.title, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : AppColors.slate900,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
        height: 1,
        color: isDark ? AppColors.slate800 : AppColors.slate100);
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
