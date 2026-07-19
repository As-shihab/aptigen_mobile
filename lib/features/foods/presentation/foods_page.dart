import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/aptigen_app_bar.dart';

class FoodsPage extends StatefulWidget {
  const FoodsPage({super.key});

  @override
  State<FoodsPage> createState() => _FoodsPageState();
}

class _FoodsPageState extends State<FoodsPage> {
  String _activeCategory = 'All';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  static const _categories = [
    _FoodCategory('All', '🍽️', null),
    _FoodCategory('Fast Food', '🍔', 'Fast Food'),
    _FoodCategory('Restaurant', '🍜', 'Restaurant'),
    _FoodCategory('Cafe', '☕', 'Cafe'),
    _FoodCategory('Desserts', '🍰', 'Desserts'),
    _FoodCategory('Healthy', '🥗', 'Healthy'),
  ];

  static const _restaurants = [
    _Restaurant('The Grand Bistro', 'Italian • 25–35 min', 4.8, 2.5,
        'Restaurant', '🍝', Color(0xFFEF4444), Color(0xFFDC2626),
        'Pasta, Risotto, Tiramisu'),
    _Restaurant('Sakura Garden', 'Japanese • 30–40 min', 4.6, 1.8,
        'Restaurant', '🍣', Color(0xFF8B5CF6), Color(0xFF7C3AED),
        'Sushi, Ramen, Tempura'),
    _Restaurant('The Burger Lab', 'American • 15–25 min', 4.5, 0.99,
        'Fast Food', '🍔', Color(0xFFF97316), Color(0xFFEA580C),
        'Burgers, Fries, Milkshakes'),
    _Restaurant('Spice Route', 'Indian • 35–45 min', 4.7, 2.0,
        'Restaurant', '🍛', Color(0xFFF59E0B), Color(0xFFD97706),
        'Curry, Biryani, Naan'),
    _Restaurant('Green Bowl', 'Healthy • 20–30 min', 4.9, 1.5,
        'Healthy', '🥗', Color(0xFF10B981), Color(0xFF059669),
        'Salads, Wraps, Smoothies'),
    _Restaurant('Cafe Noir', 'Cafe • 10–20 min', 4.4, 1.2,
        'Cafe', '☕', Color(0xFF6B7280), Color(0xFF4B5563),
        'Coffee, Pastries, Sandwiches'),
    _Restaurant('Sweet Tooth', 'Bakery • 15–25 min', 4.7, 0.0,
        'Desserts', '🍰', Color(0xFFEC4899), Color(0xFFDB2777),
        'Cakes, Waffles, Ice Cream'),
    _Restaurant('Pizza Palace', 'Italian • 20–30 min', 4.5, 1.9,
        'Fast Food', '🍕', Color(0xFFEF4444), Color(0xFFDC2626),
        'Pizza, Calzone, Wings'),
  ];

  List<_Restaurant> get _filtered {
    return _restaurants.where((r) {
      if (_activeCategory != 'All' && r.category != _activeCategory) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      return r.name.toLowerCase().contains(_searchQuery) ||
          r.cuisine.toLowerCase().contains(_searchQuery) ||
          r.tags.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.white;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const BackgroundOrbs(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: AptigenAppBar(isDark: isDark),
                  ),
                ),
                // Hero text
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FOOD & DRINKS',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.5,
                            color: AppColors.orange500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'What are you\ncraving today?',
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                            color: isDark ? AppColors.white : AppColors.gray900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Search bar
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.slate900
                                : AppColors.slate100,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: isDark
                                    ? AppColors.slate800
                                    : AppColors.slate200),
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) =>
                                setState(() => _searchQuery = v.toLowerCase()),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: isDark
                                  ? AppColors.darkFg
                                  : AppColors.lightFg,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search restaurants, cuisines…',
                              hintStyle: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDark
                                      ? AppColors.slate600
                                      : AppColors.slate400),
                              prefixIcon: const Icon(Icons.search_rounded,
                                  size: 18, color: AppColors.slate400),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Category chips
                        SizedBox(
                          height: 80,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (_, i) {
                              final cat = _categories[i];
                              final sel = cat.name == _activeCategory;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _activeCategory = cat.name),
                                child: Column(
                                  children: [
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      curve: Curves.easeOut,
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        gradient: sel
                                            ? AppGradients.primaryBtn
                                            : null,
                                        color: sel
                                            ? null
                                            : (isDark
                                                ? AppColors.slate800
                                                : Colors.white),
                                        shape: BoxShape.circle,
                                        border: sel
                                            ? null
                                            : Border.all(
                                                color: isDark
                                                    ? AppColors.slate700
                                                    : AppColors.slate200),
                                        boxShadow: sel
                                            ? null
                                            : [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.05),
                                                  blurRadius: 8,
                                                )
                                              ],
                                      ),
                                      child: Center(
                                        child: Text(cat.emoji,
                                            style: const TextStyle(
                                                fontSize: 22)),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    AnimatedDefaultTextStyle(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: sel
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: sel
                                            ? AppColors.blue600
                                            : (isDark
                                                ? AppColors.slate400
                                                : AppColors.slate600),
                                      ),
                                      child: Text(cat.name == 'Restaurant'
                                          ? 'Dine-in'
                                          : cat.name),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                // Promo banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: _PromoBanner(),
                  ),
                ),
                // Section header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _activeCategory == 'All'
                              ? 'Popular Near You'
                              : _activeCategory,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? Colors.white : AppColors.slate900,
                          ),
                        ),
                        Text(
                          '${_filtered.length} places',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppColors.blue600,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                // Restaurant list
                if (_filtered.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.no_food_rounded,
                              color: AppColors.slate300, size: 56),
                          SizedBox(height: 12),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _RestaurantTile(
                          restaurant: _filtered[i], isDark: isDark),
                      childCount: _filtered.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Promo Banner ──────────────────────────────────────────────────────────

class _PromoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEF4444), Color(0xFFEC4899)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'TODAY ONLY',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Free delivery\non your first order',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const Text('🛵', style: TextStyle(fontSize: 52)),
        ],
      ),
    );
  }
}

// ─── Restaurant Tile ───────────────────────────────────────────────────────

class _RestaurantTile extends StatelessWidget {
  final _Restaurant restaurant;
  final bool isDark;
  const _RestaurantTile(
      {required this.restaurant, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.slate100),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showDetail(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Emoji icon
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [restaurant.color1, restaurant.color2],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(restaurant.emoji,
                        style: const TextStyle(fontSize: 30)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              restaurant.name,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.slate900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.amber400
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: AppColors.amber400, size: 12),
                                const SizedBox(width: 2),
                                Text(
                                  restaurant.rating.toString(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.amber400
                                        : const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        restaurant.cuisine,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.slate500),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _InfoPill(
                            icon: Icons.access_time_rounded,
                            label: restaurant.cuisine
                                .split('• ')
                                .last,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _InfoPill(
                            icon: Icons.delivery_dining_rounded,
                            label: restaurant.deliveryFee == 0
                                ? 'Free'
                                : '\$${restaurant.deliveryFee.toStringAsFixed(2)}',
                            isDark: isDark,
                            highlight: restaurant.deliveryFee == 0,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RestaurantSheet(
          restaurant: restaurant,
          isDark: Theme.of(context).brightness == Brightness.dark),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final bool highlight;
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.isDark,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.emerald500.withValues(alpha: 0.1)
            : (isDark ? AppColors.slate700 : AppColors.slate100),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 11,
              color:
                  highlight ? AppColors.emerald500 : AppColors.slate400),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: highlight
                  ? AppColors.emerald500
                  : (isDark ? AppColors.slate400 : AppColors.slate600),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Restaurant Detail Sheet ───────────────────────────────────────────────

class _RestaurantSheet extends StatelessWidget {
  final _Restaurant restaurant;
  final bool isDark;
  const _RestaurantSheet(
      {required this.restaurant, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.slate900 : AppColors.white;
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.slate700 : AppColors.slate200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [restaurant.color1, restaurant.color2],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(restaurant.emoji,
                        style: const TextStyle(fontSize: 64)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            restaurant.name,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark ? Colors.white : AppColors.slate900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.amber400.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: AppColors.amber400, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                restaurant.rating.toString(),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFB45309),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      restaurant.cuisine,
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: AppColors.slate500),
                    ),
                    const SizedBox(height: 16),
                    // Stats row
                    Row(
                      children: [
                        _StatCard(
                          icon: Icons.access_time_rounded,
                          value: restaurant.cuisine.split('• ').last,
                          label: 'Delivery',
                          isDark: isDark,
                        ),
                        const SizedBox(width: 10),
                        _StatCard(
                          icon: Icons.delivery_dining_rounded,
                          value: restaurant.deliveryFee == 0
                              ? 'Free'
                              : '\$${restaurant.deliveryFee.toStringAsFixed(2)}',
                          label: 'Delivery fee',
                          isDark: isDark,
                          highlight: restaurant.deliveryFee == 0,
                        ),
                        const SizedBox(width: 10),
                        _StatCard(
                          icon: Icons.star_rounded,
                          value: restaurant.rating.toString(),
                          label: 'Rating',
                          isDark: isDark,
                          highlight: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Divider(
                        color: isDark
                            ? AppColors.slate800
                            : AppColors.slate100),
                    const SizedBox(height: 16),
                    Text(
                      'Popular Items',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...restaurant.tags.split(', ').map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.slate800
                                    : AppColors.slate50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: isDark
                                        ? AppColors.slate700
                                        : AppColors.slate100),
                              ),
                              child: Row(
                                children: [
                                  Text(restaurant.emoji,
                                      style:
                                          const TextStyle(fontSize: 20)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.trim(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.slate800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '\$${(8 + item.length % 12).toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.blue600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    const SizedBox(height: 20),
                    // Order button
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppGradients.primaryBtn,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.pop(context),
                          child: Center(
                            child: Text(
                              'Start Order',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool isDark;
  final bool highlight;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.isDark,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlight
              ? AppColors.blue600.withValues(alpha: 0.08)
              : (isDark ? AppColors.slate800 : AppColors.slate50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlight
                ? AppColors.blue600.withValues(alpha: 0.2)
                : (isDark ? AppColors.slate700 : AppColors.slate100),
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 18,
                color:
                    highlight ? AppColors.blue600 : AppColors.slate400),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: highlight
                    ? AppColors.blue600
                    : (isDark ? Colors.white : AppColors.slate800),
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                  fontSize: 10, color: AppColors.slate400),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data classes ──────────────────────────────────────────────────────────

class _FoodCategory {
  final String name;
  final String emoji;
  final String? filter;
  const _FoodCategory(this.name, this.emoji, this.filter);
}

class _Restaurant {
  final String name;
  final String cuisine;
  final double rating;
  final double deliveryFee;
  final String category;
  final String emoji;
  final Color color1;
  final Color color2;
  final String tags;
  const _Restaurant(this.name, this.cuisine, this.rating, this.deliveryFee,
      this.category, this.emoji, this.color1, this.color2, this.tags);
}
