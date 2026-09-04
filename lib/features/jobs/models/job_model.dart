/// A `hiring` row, from GET /api/public/jobs and /public/jobs/:id (cloud's
/// recruitment-public.service.ts) — see frontend/app/(public)/jobs/jobs.client.tsx
/// for the same contract on web.
class JobModel {
  final int id;
  final String? customId;
  final String title;
  final String? department;
  final String? employmentType;
  final int vacancies;
  final double? salaryMin;
  final double? salaryMax;
  final String? location;
  final DateTime? deadline;
  final String? description; // HTML
  final String? requirements; // HTML
  final String status;
  final bool isActive;
  final int viewsCount;
  final DateTime createdAt;
  final int applicationsCount;
  final int? workplaceId;
  final String? workplaceName;

  const JobModel({
    required this.id,
    this.customId,
    required this.title,
    this.department,
    this.employmentType,
    this.vacancies = 1,
    this.salaryMin,
    this.salaryMax,
    this.location,
    this.deadline,
    this.description,
    this.requirements,
    this.status = 'open',
    this.isActive = true,
    this.viewsCount = 0,
    required this.createdAt,
    this.applicationsCount = 0,
    this.workplaceId,
    this.workplaceName,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) {
    final workplace = json['workplace'] as Map<String, dynamic>?;
    return JobModel(
      id: json['id'] as int? ?? 0,
      customId: json['custom_id'] as String?,
      title: json['title'] as String? ?? '',
      department: json['department'] as String?,
      employmentType: json['employment_type'] as String?,
      vacancies: json['vacancies'] as int? ?? 1,
      salaryMin: (json['salary_min'] as num?)?.toDouble(),
      salaryMax: (json['salary_max'] as num?)?.toDouble(),
      location: json['location'] as String?,
      deadline: json['deadline'] != null ? DateTime.tryParse(json['deadline'] as String) : null,
      description: json['description'] as String?,
      requirements: json['requirements'] as String?,
      status: json['status'] as String? ?? 'open',
      isActive: json['is_active'] as bool? ?? true,
      viewsCount: json['views_count'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      applicationsCount: json['applications_count'] as int? ?? 0,
      workplaceId: workplace?['id'] as int?,
      workplaceName: workplace?['name'] as String?,
    );
  }

  /// e.g. "3k – 5k" or "3k" — mirrors formatSalary() in jobs.client.tsx.
  String? get salaryLabel {
    if (salaryMin == null && salaryMax == null) return null;
    String fmt(double n) => n >= 1000 ? '${(n / 1000).round()}k' : n.toStringAsFixed(0);
    if (salaryMin != null && salaryMax != null) return '${fmt(salaryMin!)} – ${fmt(salaryMax!)}';
    return fmt((salaryMin ?? salaryMax)!);
  }

  static String stripHtml(String? html) {
    if (html == null || html.isEmpty) return '';
    return html.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
