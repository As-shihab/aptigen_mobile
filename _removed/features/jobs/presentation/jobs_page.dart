import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/http_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/aptigen_app_bar.dart';
import '../../../shared/skeleton.dart';
import '../data/jobs_service.dart';
import '../models/job_model.dart';
import 'job_detail_page.dart';

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final _service = JobsService(ApiClient());
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<JobModel> _jobs = [];
  bool _loading = true;
  String? _error;
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jobs = await _service.getJobs(search: _searchCtrl.text.trim());
      if (!mounted) return;
      setState(() => _jobs = jobs);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Failed to load open roles. Pull to retry.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  void _openJob(JobModel job) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => JobDetailPage(jobId: job.id),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
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
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppColors.blue600,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: AptigenAppBar(
                        isDark: isDark,
                        onSearch: () =>
                            setState(() => _searchOpen = !_searchOpen),
                      ),
                    ),
                  ),
                  if (_searchOpen)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SearchBar(
                                ctrl: _searchCtrl,
                                onChanged: _onSearchChanged,
                                isDark: isDark,
                                autofocus: true),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  if (_loading)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, __) => const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: _JobCardSkeleton(),
                          ),
                          childCount: 4,
                        ),
                      ),
                    )
                  else if (_error != null)
                    SliverToBoxAdapter(
                        child: _ErrorState(error: _error!, onRetry: _load))
                  else if (_jobs.isEmpty)
                    const SliverToBoxAdapter(child: _EmptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _JobCard(
                                job: _jobs[i],
                                isDark: isDark,
                                onTap: () => _openJob(_jobs[i])),
                          ),
                          childCount: _jobs.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Job Card ────────────────────────────────────────────────────────────

class _JobCardSkeleton extends StatelessWidget {
  const _JobCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: isDark ? AppColors.slate700 : AppColors.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 15, width: 160),
                    const SizedBox(height: 8),
                    Skeleton(height: 11, width: 100),
                  ],
                ),
              ),
              Skeleton(
                  width: 64,
                  height: 20,
                  borderRadius: BorderRadius.circular(20)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Skeleton(width: 70, height: 10),
              const SizedBox(width: 14),
              Skeleton(width: 60, height: 10),
              const SizedBox(width: 14),
              Skeleton(width: 50, height: 10),
            ],
          ),
          const SizedBox(height: 12),
          Skeleton(height: 10, width: double.infinity),
          const SizedBox(height: 6),
          Skeleton(height: 10, width: 200),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final JobModel job;
  final bool isDark;
  final VoidCallback onTap;
  const _JobCard(
      {required this.job, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final salary = job.salaryLabel;
    final desc = JobModel.stripHtml(job.description);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
                      blurRadius: 14,
                      offset: const Offset(0, 4))
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [job.department, job.employmentType]
                            .where((e) => e != null && e.isNotEmpty)
                            .join(' · '),
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.slate500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : AppColors.slate900,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'View role',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: isDark ? AppColors.slate900 : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                if (job.workplaceName != null)
                  _MetaChip(
                      icon: Icons.apartment_rounded, label: job.workplaceName!),
                if (job.location != null)
                  _MetaChip(
                      icon: Icons.location_on_outlined, label: job.location!),
                _MetaChip(
                  icon: Icons.people_alt_outlined,
                  label:
                      '${job.vacancies} vacanc${job.vacancies != 1 ? 'ies' : 'y'}',
                ),
                if (salary != null)
                  _MetaChip(icon: Icons.payments_outlined, label: salary),
                if (job.deadline != null)
                  _MetaChip(
                    icon: Icons.event_outlined,
                    label:
                        'Apply by ${job.deadline!.day}/${job.deadline!.month}/${job.deadline!.year}',
                  ),
              ],
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.slate500, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.slate400),
        const SizedBox(width: 4),
        Text(label,
            style:
                GoogleFonts.poppins(fontSize: 11, color: AppColors.slate500)),
      ],
    );
  }
}

// ─── Search Bar ────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final ValueChanged<String> onChanged;
  final bool isDark;
  final bool autofocus;
  const _SearchBar(
      {required this.ctrl,
      required this.onChanged,
      required this.isDark,
      this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : AppColors.slate100,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
      ),
      child: TextField(
        controller: ctrl,
        autofocus: autofocus,
        onChanged: onChanged,
        style: GoogleFonts.poppins(
            fontSize: 14, color: isDark ? AppColors.darkFg : AppColors.lightFg),
        decoration: InputDecoration(
          hintText: 'Search by title, company, location…',
          hintStyle: GoogleFonts.poppins(
              fontSize: 14,
              color: isDark ? AppColors.slate600 : AppColors.slate400),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 18, color: AppColors.slate400),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ─── Error / Empty States ──────────────────────────────────────────────────

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                    gradient: AppGradients.primaryBtn,
                    borderRadius: BorderRadius.circular(12)),
                child: Text('Retry',
                    style: GoogleFonts.poppins(
                        color: AppColors.white, fontWeight: FontWeight.w600)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.work_outline_rounded,
                color: AppColors.slate300, size: 56),
            const SizedBox(height: 12),
            Text('No open roles right now',
                style: GoogleFonts.poppins(
                    color: AppColors.slate500,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('Check back soon, or try a different search',
                style: GoogleFonts.poppins(
                    color: AppColors.slate400, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
