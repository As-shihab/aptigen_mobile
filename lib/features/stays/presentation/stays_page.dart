import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/http_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/aptigen_app_bar.dart';
import '../data/stays_service.dart';
import '../models/stay_model.dart';
import 'stay_detail_page.dart';
import 'widgets/stay_card.dart';

class StaysPage extends StatefulWidget {
  const StaysPage({super.key});

  @override
  State<StaysPage> createState() => _StaysPageState();
}

class _StaysPageState extends State<StaysPage> {
  final _service = StaysService(ApiClient());
  List<StayModel> _all = [];
  List<StayModel> _filtered = [];
  bool _loading = true;
  String? _error;
  bool _searchVisible = false;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _activeFilter = 'All';

  static const _filters = ['All', 'Villa', 'Hotel', 'Apartment', 'Resort'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searchVisible = !_searchVisible);
    if (_searchVisible) {
      Future.microtask(() => _searchFocus.requestFocus());
    } else {
      _searchCtrl.clear();
      _applySearch('');
      _searchFocus.unfocus();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stays = await _service.getPublicStays();
      if (!mounted) return;
      setState(() {
        _all = stays;
        _filtered = stays;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load stays. Pull to retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySearch(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filtered = _all.where((s) {
        if (_activeFilter != 'All') {
          final pt = (s.propertyType ?? '').toLowerCase();
          final cat = (s.categoryName ?? '').toLowerCase();
          final filter = _activeFilter.toLowerCase();
          if (pt != filter && cat != filter) return false;
        }
        if (q.isEmpty) return true;
        return s.title.toLowerCase().contains(q) ||
            s.location.toLowerCase().contains(q) ||
            (s.propertyType ?? '').toLowerCase().contains(q);
      }).toList();
    });
  }

  void _setFilter(String f) {
    setState(() => _activeFilter = f);
    _applySearch(_searchCtrl.text);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Fixed header — animates to full-width search ─────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOut,
                  padding: _searchVisible
                      ? EdgeInsets.zero
                      : const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.97, end: 1.0).animate(
                          CurvedAnimation(
                              parent: anim, curve: Curves.easeOut),
                        ),
                        child: child,
                      ),
                    ),
                    child: _searchVisible
                        ? _SearchHeader(
                            key: const ValueKey('search'),
                            ctrl: _searchCtrl,
                            focusNode: _searchFocus,
                            onChanged: _applySearch,
                            onClose: _toggleSearch,
                            isDark: isDark,
                          )
                        : AptigenAppBar(
                            key: const ValueKey('header'),
                            isDark: isDark,
                            onSearch: _toggleSearch,
                          ),
                  ),
                ),
                // ── Scrollable body ──────────────────────────────────────
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.blue600,
                    child: CustomScrollView(
                      slivers: [
                        // "Stays that feel curated" — collapses when searching
                        SliverToBoxAdapter(
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            child: _searchVisible
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 16, 16, 0),
                                    child: RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.poppins(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          height: 1.3,
                                          color: isDark
                                              ? AppColors.white
                                              : AppColors.gray900,
                                        ),
                                        children: [
                                          const TextSpan(
                                              text: 'Stays that feel '),
                                          TextSpan(
                                            text: 'curated',
                                            style: const TextStyle(
                                                color: AppColors.blue600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        // Filter chips + count badge
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _FilterChips(
                                    filters: _filters,
                                    active: _activeFilter,
                                    onSelect: _setFilter,
                                    isDark: isDark,
                                  ),
                                ),
                                if (!_loading && _error == null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.blue600
                                          .withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${_filtered.length}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.blue600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(
                            child: SizedBox(height: 12)),
                        if (_loading)
                          const SliverPadding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: _SkeletonGrid(),
                          )
                        else if (_error != null)
                          SliverFillRemaining(
                              child: _ErrorState(
                                  error: _error!, onRetry: _load))
                        else if (_filtered.isEmpty)
                          const SliverFillRemaining(child: _EmptyState())
                        else
                          SliverPadding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.62,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => StayCard(
                                  stay: _filtered[i],
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StayDetailPage(
                                          stay: _filtered[i]),
                                    ),
                                  ),
                                ),
                                childCount: _filtered.length,
                              ),
                            ),
                          ),
                        const SliverToBoxAdapter(
                            child: SizedBox(height: 24)),
                      ],
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

// ─── Search header — full-width frosted glass, same style as AptigenAppBar ───

class _SearchHeader extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  final bool isDark;

  const _SearchHeader({
    super.key,
    required this.ctrl,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.slate900.withValues(alpha: 0.92)
                : AppColors.white.withValues(alpha: 0.88),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? AppColors.slate800.withValues(alpha: 0.6)
                    : AppColors.slate200.withValues(alpha: 0.7),
              ),
            ),
          ),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: ctrl,
            builder: (_, val, __) => Row(
              children: [
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.slate800
                          : AppColors.slate100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: 17,
                      color: isDark
                          ? AppColors.slate300
                          : AppColors.slate600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDark ? AppColors.darkFg : AppColors.lightFg,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.transparent,
                      hintText: 'Search destinations…',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.slate500
                            : AppColors.slate400,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (val.text.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      ctrl.clear();
                      onChanged('');
                    },
                    child: Icon(
                      Icons.clear_rounded,
                      size: 18,
                      color: isDark
                          ? AppColors.slate400
                          : AppColors.slate500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Filter chips ─────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final List<String> filters;
  final String active;
  final ValueChanged<String> onSelect;
  final bool isDark;
  const _FilterChips({
    required this.filters,
    required this.active,
    required this.onSelect,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = filters[i];
          final selected = f == active;
          return GestureDetector(
            onTap: () => onSelect(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.blue600
                    : isDark
                        ? AppColors.slate800
                        : AppColors.slate100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                f,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.white
                      : isDark
                          ? AppColors.slate400
                          : AppColors.slate600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Error / empty states ─────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: AppColors.slate500, size: 48),
            const SizedBox(height: 16),
            Text(error,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    color: AppColors.slate600, fontSize: 14)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppGradients.primaryBtn,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Retry',
                    style: GoogleFonts.poppins(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded,
              color: AppColors.slate300, size: 56),
          const SizedBox(height: 12),
          Text('No stays found',
              style: GoogleFonts.poppins(
                  color: AppColors.slate500,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Try a different search',
              style: GoogleFonts.poppins(
                  color: AppColors.slate400, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Skeleton loader ──────────────────────────────────────────────────────────

class _SkeletonGrid extends StatefulWidget {
  const _SkeletonGrid();

  @override
  State<_SkeletonGrid> createState() => _SkeletonGridState();
}

class _SkeletonGridState extends State<_SkeletonGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.70,
      ),
      delegate: SliverChildBuilderDelegate(
        (_, __) => _StaySkeletonCard(anim: _anim),
        childCount: 6,
      ),
    );
  }
}

class _StaySkeletonCard extends StatelessWidget {
  final Animation<double> anim;
  const _StaySkeletonCard({required this.anim});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.slate800 : AppColors.slate100;
    final highlight = isDark ? AppColors.slate700 : AppColors.slate200;

    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final color = Color.lerp(base, highlight, anim.value)!;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : AppColors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.black
                    .withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 160, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 13,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: 80,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 32,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
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
