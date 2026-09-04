import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/http_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/skeleton.dart';
import '../data/jobs_service.dart';
import '../models/job_model.dart';

class JobDetailPage extends StatefulWidget {
  final int jobId;
  const JobDetailPage({super.key, required this.jobId});

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  final _service = JobsService(ApiClient());
  JobModel? _job;
  bool _loading = true;
  bool _notFound = false;
  List<JobModel> _related = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _notFound = false;
    });
    try {
      final job = await _service.getJob(widget.jobId);
      if (!mounted) return;
      if (job == null) {
        setState(() {
          _notFound = true;
          _loading = false;
        });
        return;
      }
      setState(() {
        _job = job;
        _loading = false;
      });
      _service.trackClick(job.id);
      _loadRelated(job);
    } catch (_) {
      if (mounted) {
        setState(() {
          _notFound = true;
          _loading = false;
        });
      }
    }
  }

  List<JobModel> _rankRelated(List<JobModel> jobs, JobModel job) {
    final others = jobs.where((j) => j.id != job.id).toList()
      ..sort((a, b) {
        final aMatch =
            a.department != null && a.department == job.department ? 1 : 0;
        final bMatch =
            b.department != null && b.department == job.department ? 1 : 0;
        if (aMatch != bMatch) return bMatch - aMatch;
        return b.createdAt.compareTo(a.createdAt);
      });
    return others.take(5).toList();
  }

  // Same-workplace openings first (mirrors web's job-detail sidebar); when
  // that comes up empty — a single-role workplace, or no workplace at all —
  // fall back to other open roles platform-wide so this section still shows
  // relevant jobs instead of vanishing.
  Future<void> _loadRelated(JobModel job) async {
    try {
      final sameWorkplace = job.workplaceId != null
          ? await _service.getJobsByWorkplace(job.workplaceId!)
          : <JobModel>[];
      var ranked = _rankRelated(sameWorkplace, job);
      if (ranked.isEmpty) {
        final all = await _service.getJobs();
        ranked = _rankRelated(all, job);
      }
      if (mounted) setState(() => _related = ranked);
    } catch (_) {
      // leave _related empty — section just won't render
    }
  }

  void _openJob(int id) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => JobDetailPage(jobId: id)),
    );
  }

  void _showApplySheet() {
    final job = _job;
    if (job == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApplySheet(job: job, service: _service),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme:
            IconThemeData(color: isDark ? Colors.white : AppColors.slate900),
        title: Text('Job details',
            style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.slate900)),
      ),
      body: _loading
          ? const _JobDetailSkeleton()
          : (_notFound || _job == null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.work_off_outlined,
                            color: AppColors.slate300, size: 56),
                        const SizedBox(height: 12),
                        Text('This role isn\'t open anymore',
                            style: GoogleFonts.poppins(
                                color: AppColors.slate500, fontSize: 15)),
                      ],
                    ),
                  ),
                )
              : _buildContent(context, isDark),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    final job = _job!;
    final salary = job.salaryLabel;
    final description = JobModel.stripHtml(job.description);
    final requirements = JobModel.stripHtml(job.requirements);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.title,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.slate900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            [job.department, job.employmentType]
                .where((e) => e != null && e.isNotEmpty)
                .join(' · '),
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.slate500),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              if (job.workplaceName != null)
                _MetaItem(
                    icon: Icons.apartment_rounded, label: job.workplaceName!),
              if (job.location != null)
                _MetaItem(
                    icon: Icons.location_on_outlined, label: job.location!),
              _MetaItem(
                icon: Icons.people_alt_outlined,
                label:
                    '${job.vacancies} vacanc${job.vacancies != 1 ? 'ies' : 'y'}',
              ),
              if (salary != null)
                _MetaItem(icon: Icons.payments_outlined, label: salary),
              if (job.deadline != null)
                _MetaItem(
                  icon: Icons.event_outlined,
                  label:
                      'Apply by ${job.deadline!.day}/${job.deadline!.month}/${job.deadline!.year}',
                ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                  gradient: AppGradients.primaryBtn,
                  borderRadius: BorderRadius.circular(16)),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _showApplySheet,
                  child: Center(
                    child: Text(
                      'Apply Now',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('About the role',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.slate900)),
            const SizedBox(height: 8),
            Text(description,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.slate500, height: 1.6)),
          ],
          if (requirements.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Requirements',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.slate900)),
            const SizedBox(height: 8),
            Text(requirements,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.slate500, height: 1.6)),
          ],
          if (_related.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('Relevant jobs',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.slate400)),
            const SizedBox(height: 10),
            ..._related.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => _openJob(r.id),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate800 : AppColors.slate50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isDark
                                ? AppColors.slate700
                                : AppColors.slate100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title,
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.slate900)),
                          const SizedBox(height: 3),
                          Text(
                            [r.department, r.employmentType]
                                .where((e) => e != null && e.isNotEmpty)
                                .join(' · '),
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _JobDetailSkeleton extends StatelessWidget {
  const _JobDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(height: 22, width: 220),
          const SizedBox(height: 10),
          Skeleton(height: 13, width: 140),
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: List.generate(4, (_) => Skeleton(height: 12, width: 90)),
          ),
          const SizedBox(height: 26),
          Skeleton(
              height: 52,
              width: double.infinity,
              borderRadius: BorderRadius.circular(16)),
          const SizedBox(height: 28),
          Skeleton(height: 14, width: 120),
          const SizedBox(height: 10),
          Skeleton(height: 10, width: double.infinity),
          const SizedBox(height: 6),
          Skeleton(height: 10, width: double.infinity),
          const SizedBox(height: 6),
          Skeleton(height: 10, width: 180),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.slate400),
        const SizedBox(width: 5),
        Text(label,
            style:
                GoogleFonts.poppins(fontSize: 12, color: AppColors.slate600)),
      ],
    );
  }
}

// ─── Apply Sheet ─────────────────────────────────────────────────────────

class _ApplySheet extends StatefulWidget {
  final JobModel job;
  final JobsService service;
  const _ApplySheet({required this.job, required this.service});

  @override
  State<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<_ApplySheet> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _experience = TextEditingController();
  final _company = TextEditingController();
  final _position = TextEditingController();
  final _coverLetter = TextEditingController();

  File? _photo;
  File? _cv;
  String? _cvName;

  bool _submitting = false;
  bool _done = false;
  String? _error;

  bool get _canSubmit =>
      _firstName.text.trim().isNotEmpty &&
      _email.text.trim().isNotEmpty &&
      _phone.text.trim().isNotEmpty &&
      _photo != null &&
      _cv != null &&
      !_submitting;

  @override
  void initState() {
    super.initState();
    // These three gate _canSubmit — rebuild as the user types so the submit
    // button's enabled state stays in sync (picking a photo/CV already
    // triggers setState on its own).
    for (final c in [_firstName, _email, _phone]) {
      c.addListener(_onRequiredFieldChanged);
    }
  }

  void _onRequiredFieldChanged() => setState(() {});

  @override
  void dispose() {
    for (final c in [_firstName, _email, _phone]) {
      c.removeListener(_onRequiredFieldChanged);
    }
    for (final c in [
      _firstName,
      _lastName,
      _email,
      _phone,
      _experience,
      _company,
      _position,
      _coverLetter
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _photo = File(picked.path);
      _error = null;
    });
  }

  Future<void> _pickCv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      _cv = File(path);
      _cvName = result!.files.single.name;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await widget.service.apply(
      jobId: widget.job.id,
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      experienceYears: _experience.text.trim(),
      currentCompany: _company.text.trim(),
      currentPosition: _position.text.trim(),
      coverLetter: _coverLetter.text.trim(),
      photo: _photo!,
      cv: _cv!,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (result.ok) {
        _done = true;
      } else {
        _error = result.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.slate900 : AppColors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      expand: false,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28))),
          child: _done
              ? _buildDone(isDark)
              : _buildForm(context, isDark, controller),
        );
      },
    );
  }

  Widget _buildDone(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: AppColors.emerald500.withValues(alpha: 0.12),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.emerald500, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Application submitted',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.slate900)),
            const SizedBox(height: 8),
            Text(
              'Thanks for applying to ${widget.job.title} — we\'ll be in touch if you\'re a good fit.',
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.poppins(fontSize: 13, color: AppColors.slate500),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                    color: isDark ? Colors.white : AppColors.slate900,
                    borderRadius: BorderRadius.circular(14)),
                child: Text('Done',
                    style: GoogleFonts.poppins(
                        color: isDark ? AppColors.slate900 : Colors.white,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(
      BuildContext context, bool isDark, ScrollController controller) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: isDark ? AppColors.slate700 : AppColors.slate200,
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Text('Apply for this role',
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.slate900)),
        Text(widget.job.title,
            style:
                GoogleFonts.poppins(fontSize: 13, color: AppColors.slate500)),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: _pickPhoto,
            child: Container(
              width: 88,
              height: 88,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.slate800 : AppColors.slate50,
                border: Border.all(
                    color: isDark ? AppColors.slate700 : AppColors.slate200,
                    width: 2),
              ),
              child: _photo != null
                  ? Image.file(_photo!, fit: BoxFit.cover)
                  : Icon(Icons.person_outline_rounded,
                      size: 36, color: AppColors.slate300),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text('Profile photo *',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate500)),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
                child: _Field(
                    label: 'First name *', ctrl: _firstName, isDark: isDark)),
            const SizedBox(width: 10),
            Expanded(
                child: _Field(
                    label: 'Last name', ctrl: _lastName, isDark: isDark)),
          ],
        ),
        const SizedBox(height: 12),
        _Field(
            label: 'Email *',
            ctrl: _email,
            isDark: isDark,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),
        _Field(
            label: 'Mobile number *',
            ctrl: _phone,
            isDark: isDark,
            keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _Field(
                    label: 'Experience (yrs)',
                    ctrl: _experience,
                    isDark: isDark,
                    keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(
                flex: 2,
                child: _Field(
                    label: 'Current company', ctrl: _company, isDark: isDark)),
          ],
        ),
        const SizedBox(height: 12),
        _Field(label: 'Current position', ctrl: _position, isDark: isDark),
        const SizedBox(height: 16),
        Text('CV / Resume *',
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.slate500)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickCv,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isDark ? AppColors.slate700 : AppColors.slate200,
                  style: BorderStyle.solid),
              color: isDark
                  ? AppColors.slate800.withValues(alpha: 0.4)
                  : AppColors.slate50,
            ),
            child: Column(
              children: [
                Icon(
                    _cv != null
                        ? Icons.description_rounded
                        : Icons.upload_file_rounded,
                    size: 22,
                    color: AppColors.slate400),
                const SizedBox(height: 6),
                Text(
                  _cvName ?? 'Tap to choose your CV',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.slate700),
                ),
                const SizedBox(height: 2),
                Text('PDF or Word, up to 10MB',
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: AppColors.slate400)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Cover letter (optional)',
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.slate500)),
        const SizedBox(height: 6),
        TextField(
          controller: _coverLetter,
          maxLines: 3,
          style: GoogleFonts.poppins(
              fontSize: 13, color: isDark ? Colors.white : AppColors.slate800),
          decoration: InputDecoration(
            hintText: 'A few words on why you\'re a good fit…',
            hintStyle:
                GoogleFonts.poppins(fontSize: 13, color: AppColors.slate400),
            filled: true,
            fillColor: isDark
                ? AppColors.slate800.withValues(alpha: 0.4)
                : AppColors.slate50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.rose500.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Text(_error!,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.rose500)),
          ),
        ],
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _canSubmit ? _submit : null,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: _canSubmit ? AppGradients.primaryBtn : null,
              color: _canSubmit ? null : AppColors.slate300,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text('Submit application',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool isDark;
  final TextInputType? keyboardType;
  const _Field(
      {required this.label,
      required this.ctrl,
      required this.isDark,
      this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.slate500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(
              fontSize: 13, color: isDark ? Colors.white : AppColors.slate800),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark
                ? AppColors.slate800.withValues(alpha: 0.4)
                : AppColors.slate50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
