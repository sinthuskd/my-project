import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../screens/login_screen.dart';
import '../utils/routes.dart';
import 'api_config.dart';
import 'auth_service.dart';

/// Error with a message that is safe to show to the admin.
class AdminApiException implements Exception {
  final String message;
  final int? status;
  AdminApiException(this.message, {this.status});
  @override
  String toString() => message;
}

/// Client for the backend's /admin/* endpoints (same token as the customer login,
/// the backend checks that the account has the admin role).
class AdminApi {
  static const _timeout = Duration(seconds: 20);

  static Future<http.Response> _do(
      String method, Uri uri, Map<String, String> headers, Object? body) {
    switch (method) {
      case 'POST':
        return http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
      case 'PUT':
        return http.put(uri, headers: headers, body: jsonEncode(body ?? {}));
      case 'DELETE':
        return http.delete(uri, headers: headers);
      default:
        return http.get(uri, headers: headers);
    }
  }

  static Future<dynamic> _req(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
  }) async {
    final base = ApiConfig.baseUrl;
    var uri = Uri.parse('$base$path');
    if (query != null) {
      final q = <String, String>{};
      query.forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) q[k] = v.toString();
      });
      if (q.isNotEmpty) uri = uri.replace(queryParameters: q);
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...AuthService.authHeaders,
    };

    http.Response res;
    try {
      res = await _do(method, uri, headers, body).timeout(_timeout);
    } on TimeoutException {
      throw AdminApiException('Server did not respond ($base). Check the backend.');
    } catch (e) {
      debugPrint('[AdminApi] $method $uri failed: $e');
      throw AdminApiException(
          "Can't reach the server at $base. Make sure the backend is running.");
    }

    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(res.body);
      } catch (_) {}
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    // Token expired / not an admin any more -> back to the login screen.
    if (res.statusCode == 401 || res.statusCode == 403) {
      await AuthService.logout();
      rootNavKey.currentState?.pushAndRemoveUntil(
          fadeRoute(const LoginScreen()), (r) => false);
    }

    String msg = 'Server error (${res.statusCode})';
    if (data is Map) {
      final m = data['message'];
      if (m is List) {
        msg = m.join('\n');
      } else if (m != null) {
        msg = m.toString();
      }
    }
    debugPrint('[AdminApi] $method $uri -> ${res.statusCode}: ${res.body}');
    throw AdminApiException(msg, status: res.statusCode);
  }

  static Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  static List<Map<String, dynamic>> _list(dynamic v) => v is List
      ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      : <Map<String, dynamic>>[];

  /* ---------------- dashboard ---------------- */
  static Future<Map<String, dynamic>> dashboard() async =>
      _map(await _req('GET', '/admin/dashboard'));

  /* ---------------- sports ---------------- */
  static Future<List<Map<String, dynamic>>> sports() async =>
      _list(await _req('GET', '/admin/sports'));
  static Future<void> createSport(String name, String icon) =>
      _req('POST', '/admin/sports', body: {'name': name, 'icon': icon});
  static Future<void> updateSport(String name, Map<String, dynamic> body) =>
      _req('PUT', '/admin/sports/${Uri.encodeComponent(name)}', body: body);
  static Future<void> deleteSport(String name) =>
      _req('DELETE', '/admin/sports/${Uri.encodeComponent(name)}');

  /* ---------------- facilities (venues) ---------------- */
  static Future<List<Map<String, dynamic>>> venues({String? q}) async =>
      _list(await _req('GET', '/admin/venues', query: {'q': q}));
  static Future<Map<String, dynamic>> venue(String id) async =>
      _map(await _req('GET', '/admin/venues/$id'));
  static Future<Map<String, dynamic>> createVenue(Map<String, dynamic> b) async =>
      _map(await _req('POST', '/admin/venues', body: b));
  static Future<Map<String, dynamic>> updateVenue(
          String id, Map<String, dynamic> b) async =>
      _map(await _req('PUT', '/admin/venues/$id', body: b));
  static Future<void> deleteVenue(String id) =>
      _req('DELETE', '/admin/venues/$id');

  /* ---------------- courts ---------------- */
  static Future<List<Map<String, dynamic>>> courts({String? venueId}) async =>
      _list(await _req('GET', '/admin/courts', query: {'venueId': venueId}));
  static Future<void> createCourt(String venueId, Map<String, dynamic> b) =>
      _req('POST', '/admin/venues/$venueId/courts', body: b);
  static Future<void> updateCourt(String id, Map<String, dynamic> b) =>
      _req('PUT', '/admin/courts/$id', body: b);
  static Future<void> deleteCourt(String id) =>
      _req('DELETE', '/admin/courts/$id');

  /* ---------------- slots ---------------- */
  static Future<List<Map<String, dynamic>>> slots({
    String? courtId,
    String? venueId,
    String? date,
    String? from,
    String? to,
    String? status,
    int limit = 300,
  }) async {
    final r = _map(await _req('GET', '/admin/slots', query: {
      'courtId': courtId,
      'venueId': venueId,
      'date': date,
      'from': from,
      'to': to,
      'status': status,
      'limit': limit,
    }));
    return _list(r['items']);
  }

  static Future<void> createSlot(String courtId, Map<String, dynamic> b) =>
      _req('POST', '/admin/courts/$courtId/slots', body: b);
  static Future<Map<String, dynamic>> bulkSlots(
          String courtId, Map<String, dynamic> b) async =>
      _map(await _req('POST', '/admin/courts/$courtId/slots/bulk', body: b));
  static Future<void> updateSlot(String id, Map<String, dynamic> b) =>
      _req('PUT', '/admin/slots/$id', body: b);
  static Future<Map<String, dynamic>> deleteSlot(String id) async =>
      _map(await _req('DELETE', '/admin/slots/$id'));

  /* ---------------- bookings ---------------- */
  static Future<Map<String, dynamic>> bookings({
    String? status,
    String? q,
    String? date,
    int limit = 30,
    int offset = 0,
  }) async =>
      _map(await _req('GET', '/admin/bookings', query: {
        'status': status,
        'q': q,
        'date': date,
        'limit': limit,
        'offset': offset,
      }));
  static Future<Map<String, dynamic>> booking(String id) async =>
      _map(await _req('GET', '/admin/bookings/$id'));
  static Future<void> cancelBooking(String id) =>
      _req('POST', '/admin/bookings/$id/cancel');

  /* ---------------- customers ---------------- */
  static Future<Map<String, dynamic>> users(
          {String? q, int limit = 30, int offset = 0}) async =>
      _map(await _req('GET', '/admin/users',
          query: {'q': q, 'limit': limit, 'offset': offset}));
}
