import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../../core/network/http_client.dart';
import '../models/job_model.dart';

class JobApplicationResult {
  final bool ok;
  final String? error;
  const JobApplicationResult({required this.ok, this.error});
}

/// Talks to the real, unauthenticated jobs board API — cloud's
/// recruitment-public.controller.ts, mounted at /api/public/jobs — the same
/// backend frontend/app/(public)/jobs/jobs.client.tsx consumes.
class JobsService {
  final ApiClient _client;
  JobsService(this._client);

  static const _base = 'public/jobs';

  Future<List<JobModel>> getJobs({String? search}) async {
    final params = <String, String>{
      'status': 'open',
      'is_active': 'true',
      if (search != null && search.isNotEmpty) 'q': search,
    };
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    final data = await _client.get('$_base?$query', isV8: false);
    return ((data as List?) ?? []).map((e) => JobModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<JobModel>> getJobsByWorkplace(int workplaceId) async {
    final data = await _client.get('$_base?workplace=$workplaceId&status=open&is_active=true', isV8: false);
    return ((data as List?) ?? []).map((e) => JobModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<JobModel?> getJob(int id) async {
    final data = await _client.get('$_base/$id?status=open&is_active=true', isV8: false);
    if (data is! Map<String, dynamic>) return null;
    return JobModel.fromJson(data);
  }

  Future<void> trackClick(int id) async {
    try {
      await _client.post('$_base/$id/click', const {}, isV8: false);
    } catch (_) {
      // best-effort
    }
  }

  Future<JobApplicationResult> apply({
    required int jobId,
    required String firstName,
    String? lastName,
    String? email,
    String? phone,
    String? experienceYears,
    String? currentCompany,
    String? currentPosition,
    String? coverLetter,
    required File photo,
    required File cv,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.apiPrefix}$_base/$jobId/apply');
      final request = http.MultipartRequest('POST', uri)
        ..fields['first_name'] = firstName
        ..fields.addAll({
          if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
          if (email != null && email.isNotEmpty) 'email': email,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (experienceYears != null && experienceYears.isNotEmpty) 'experience_years': experienceYears,
          if (currentCompany != null && currentCompany.isNotEmpty) 'current_company': currentCompany,
          if (currentPosition != null && currentPosition.isNotEmpty) 'current_position': currentPosition,
          if (coverLetter != null && coverLetter.isNotEmpty) 'cover_letter': coverLetter,
        })
        ..files.add(await http.MultipartFile.fromPath('photo', photo.path))
        ..files.add(await http.MultipartFile.fromPath('cv', cv.path));

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return const JobApplicationResult(ok: true);
      }
      String message = 'Could not submit your application. Please try again.';
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body['message'] is String) message = body['message'] as String;
      } catch (_) {}
      return JobApplicationResult(ok: false, error: message);
    } catch (_) {
      return const JobApplicationResult(
          ok: false, error: 'Could not submit your application. Please check your connection and try again.');
    }
  }
}
