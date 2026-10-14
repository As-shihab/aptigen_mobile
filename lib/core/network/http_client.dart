import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../storage/app_storage.dart';

/// Thin HTTP client over the same backend the web market uses
/// (frontend/app/connection/http.connection.ts). Every market route the app
/// talks to is a custom `/api/...` route, so `isV8` defaults to false here.
class ApiClient {
  static const _timeout = Duration(seconds: 15);

  Future<Map<String, String>> _headers() async {
    final token = await AppStorage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'authorization': token,
    };
  }

  Uri _uri(String endpoint, {bool isV8 = false}) {
    final base = isV8 ? AppConfig.v8Base : AppConfig.apiPrefix;
    return Uri.parse('$base$endpoint');
  }

  Future<dynamic> get(String endpoint, {bool isV8 = false}) async {
    final res = await http
        .get(_uri(endpoint, isV8: isV8), headers: await _headers())
        .timeout(_timeout);
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
        .timeout(_timeout);
    return _parse(res);
  }

  /// Mirrors the web client's `put(endpoint, id, data, false)` →
  /// `endpoint/id` for non-OData routes.
  Future<dynamic> put(
    String endpoint,
    Object id,
    Map<String, dynamic> body, {
    bool isV8 = false,
  }) async {
    final path = isV8 ? '$endpoint($id)' : '$endpoint/$id';
    final res = await http
        .put(
          _uri(path, isV8: isV8),
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _parse(res);
  }

  Future<dynamic> delete(String endpoint, Object id, {bool isV8 = false}) async {
    final path = isV8 ? '$endpoint($id)' : '$endpoint/$id';
    final res = await http
        .delete(_uri(path, isV8: isV8), headers: await _headers())
        .timeout(_timeout);
    return _parse(res);
  }

  dynamic _parse(http.Response res) {
    if (res.statusCode == 401) throw const ApiException(401, 'Unauthorized');
    if (res.statusCode >= 400) {
      throw ApiException(
        res.statusCode,
        _messageFrom(res.body) ?? 'Request failed (${res.statusCode})',
      );
    }
    if (res.body.isEmpty) return null;
    try {
      return jsonDecode(res.body);
    } catch (_) {
      return res.body;
    }
  }

  /// Nest's HttpException body is `{ message: string | string[] }` — surface
  /// it so business-rule rejections (out of stock, etc.) reach the user.
  String? _messageFrom(String body) {
    try {
      final json = jsonDecode(body);
      final msg = json is Map ? json['message'] : null;
      if (msg is String && msg.isNotEmpty) return msg;
      if (msg is List && msg.isNotEmpty) return msg.join(', ');
    } catch (_) {}
    return null;
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
