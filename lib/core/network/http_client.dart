import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../storage/app_storage.dart';

class ApiClient {
  Future<Map<String, String>> _headers() async {
    final token = await AppStorage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'authorization': token,
    };
  }

  Uri _uri(String endpoint, {bool isV8 = true}) {
    final base = isV8 ? AppConfig.v8Base : AppConfig.apiPrefix;
    return Uri.parse('$base$endpoint');
  }

  Future<dynamic> get(String endpoint, {bool isV8 = true}) async {
    final res = await http
        .get(_uri(endpoint, isV8: isV8), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _parse(res);
  }

  Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool isV8 = false,
  }) async {
    final res = await http
        .post(
          _uri(endpoint, isV8: isV8),
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    return _parse(res);
  }

  dynamic _parse(http.Response res) {
    if (res.statusCode == 401) throw ApiException(401, 'Unauthorized');
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, 'Request failed (${res.statusCode})');
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
