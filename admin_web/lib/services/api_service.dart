import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_storage.dart';

class ApiException implements Exception {
  final String message;
  final int status;

  ApiException(this.message, this.status);

  @override
  String toString() => message;
}

/// REST client for the Tiba Safari Django backend.
///
/// Base URL: set the dart-define `API_BASE` at build/run time, e.g.
///   flutter run -d chrome --dart-define=API_BASE=http://localhost:8000/api/v1
///
/// All authenticated requests attach `Authorization: Bearer <access_token>`
/// from [AuthStorage]. The backend wraps successful responses as:
///   `{ "success": true, "message": "...", "data": payload }`
/// DRF list endpoints use pagination:
///   { "count": N, "next": "...", "previous": "...", "results": [...] }
/// [get] unwraps the outer envelope; [list] additionally extracts the results
/// array from paginated responses.
class ApiService {
  static const String _base = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  static Map<String, String> get _headers {
    final token = AuthStorage.accessToken;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ── Unwrap helpers ──────────────────────────────────────────────────────

  /// Strips the `{success, message, data}` Django envelope, if present.
  static dynamic _unwrap(dynamic body) {
    if (body is Map &&
        body.containsKey('success') &&
        body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  /// Extracts list items from a DRF paginated or plain-list response.
  static List<Map<String, dynamic>> _extractList(dynamic body) {
    final raw = _unwrap(body);
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    if (raw is Map) {
      final results = raw['results'];
      if (results is List) {
        return results.whereType<Map<String, dynamic>>().toList();
      }
    }
    return [];
  }

  // ── Public API ──────────────────────────────────────────────────────────

  /// GET a single resource. Unwraps `{success, data}` envelope.
  /// Returns the payload dict (or `{}` on empty / non-dict responses).
  static Future<Map<String, dynamic>> get(String path) async {
    final res = await http.get(
      Uri.parse('$_base$path'),
      headers: _headers,
    );
    final body = _handle(res);
    final unwrapped = _unwrap(body);
    if (unwrapped is Map<String, dynamic>) return unwrapped;
    if (body is Map<String, dynamic>) return body;
    return {};
  }

  /// GET a collection. Handles both DRF paginated `{results: [...]}` and
  /// plain list responses. Returns a flat list of item dicts.
  static Future<List<Map<String, dynamic>>> list(String path) async {
    final res = await http.get(
      Uri.parse('$_base$path'),
      headers: _headers,
    );
    return _extractList(_handle(res));
  }

  /// POST. Unwraps envelope and returns the payload dict.
  static Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final res = await http.post(
      Uri.parse('$_base$path'),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    final parsed = _handle(res);
    final unwrapped = _unwrap(parsed);
    if (unwrapped is Map<String, dynamic>) return unwrapped;
    if (parsed is Map<String, dynamic>) return parsed;
    return {};
  }

  /// PATCH. Unwraps envelope and returns the payload dict.
  static Future<Map<String, dynamic>> patch(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final res = await http.patch(
      Uri.parse('$_base$path'),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    final parsed = _handle(res);
    final unwrapped = _unwrap(parsed);
    if (unwrapped is Map<String, dynamic>) return unwrapped;
    if (parsed is Map<String, dynamic>) return parsed;
    return {};
  }

  /// DELETE.
  static Future<Map<String, dynamic>> delete(String path) async {
    final res = await http.delete(
      Uri.parse('$_base$path'),
      headers: _headers,
    );
    final parsed = _handle(res);
    if (parsed is Map<String, dynamic>) return parsed;
    return {};
  }

  // ── Error handling ──────────────────────────────────────────────────────

  static dynamic _handle(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'Request failed (${res.statusCode})';
      try {
        final j = jsonDecode(res.body);
        if (j is Map) {
          msg = j['detail'] as String? ??
              j['error'] as String? ??
              j['message'] as String? ??
              msg;
        }
      } catch (_) {}
      throw ApiException(msg, res.statusCode);
    }
    if (res.body.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(res.body);
    } on FormatException catch (e) {
      throw ApiException(
        'Server returned invalid JSON. '
        'Check that the API base URL is correct and the backend is running.\n'
        'Detail: ${e.message.length > 100 ? e.message.substring(0, 100) : e.message}',
        res.statusCode,
      );
    }
  }
}
