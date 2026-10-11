import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

class PartnerApiException implements Exception {
  final String message;
  final int? status;
  PartnerApiException(this.message, {this.status});
  @override
  String toString() => message;
}

/// Client for the backend's /partners/* endpoints (match beacons, friends, clubs).
/// Uses the normal customer login token.
class PartnerApi {
  static const _timeout = Duration(seconds: 20);

  static Future<dynamic> _req(String method, String path,
      {Map<String, Object?>? query, Object? body}) async {
    var uri = Uri.parse('${ApiConfig.baseUrl}$path');
    if (query != null) {
      final q = <String, String>{};
      query.forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) q[k] = v.toString();
      });
      if (q.isNotEmpty) uri = uri.replace(queryParameters: q);
    }
    final headers = {
      'Content-Type': 'application/json',
      ...AuthService.authHeaders,
    };

    http.Response res;
    try {
      final f = switch (method) {
        'POST' => http.post(uri, headers: headers, body: jsonEncode(body ?? {})),
        'PUT' => http.put(uri, headers: headers, body: jsonEncode(body ?? {})),
        'DELETE' => http.delete(uri, headers: headers),
        _ => http.get(uri, headers: headers),
      };
      res = await f.timeout(_timeout);
    } on TimeoutException {
      throw PartnerApiException('Server did not respond. Check the backend.');
    } catch (_) {
      throw PartnerApiException(
          "Can't reach the server at ${ApiConfig.baseUrl}. Is the backend running?");
    }

    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(res.body);
      } catch (_) {}
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    var msg = 'Server error (${res.statusCode})';
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      msg = m is List ? m.join('\n') : m.toString();
    }
    throw PartnerApiException(msg, status: res.statusCode);
  }

  static Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  static List<Map<String, dynamic>> _items(dynamic v) {
    final l = v is Map ? v['items'] : v;
    return l is List
        ? l.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
  }

  /* ---------------- match beacons ---------------- */
  /// body: sport, date (YYYY-MM-DD), startTime (HH:mm), spots, format (singles|doubles|any),
  /// skillLevel (beginner|intermediate|advanced|all), style (casual|competitive),
  /// feeSplit (split|host_pays|bring_gear), verifiedOnly, note, bookingId
  static Future<Map<String, dynamic>> createBeacon(Map<String, dynamic> body) async =>
      _map(await _req('POST', '/partners/beacons', body: body));

  static Future<List<Map<String, dynamic>>> openBeacons(
          {String? sport, String? skillLevel, String? format, String? date}) async =>
      _items(await _req('GET', '/partners/beacons', query: {
        'sport': sport, 'skillLevel': skillLevel, 'format': format, 'date': date,
      }));

  static Future<List<Map<String, dynamic>>> myBeacons({String? status}) async =>
      _items(await _req('GET', '/partners/beacons/mine', query: {'status': status}));

  static Future<List<Map<String, dynamic>>> joinedBeacons() async =>
      _items(await _req('GET', '/partners/beacons/joined'));

  static Future<Map<String, dynamic>> beacon(String id) async =>
      _map(await _req('GET', '/partners/beacons/$id'));

  static Future<Map<String, dynamic>> updateBeacon(
          String id, Map<String, dynamic> body) async =>
      _map(await _req('PUT', '/partners/beacons/$id', body: body));

  static Future<void> deleteBeacon(String id) =>
      _req('DELETE', '/partners/beacons/$id');

  static Future<Map<String, dynamic>> joinBeacon(String id) async =>
      _map(await _req('POST', '/partners/beacons/$id/join'));

  static Future<Map<String, dynamic>> leaveBeacon(String id) async =>
      _map(await _req('POST', '/partners/beacons/$id/leave'));

  /* ---------------- friends ---------------- */
  static Future<List<Map<String, dynamic>>> friends({String? q}) async =>
      _items(await _req('GET', '/partners/friends', query: {'q': q}));

  /// Pass one of: userId, phone, email
  static Future<Map<String, dynamic>> addFriend(Map<String, dynamic> body) async =>
      _map(await _req('POST', '/partners/friends', body: body));

  static Future<void> removeFriend(String id) =>
      _req('DELETE', '/partners/friends/$id');

  /* ---------------- clubs ---------------- */
  static Future<List<Map<String, dynamic>>> clubs(
          {String? sport, String? q, bool mine = false}) async =>
      _items(await _req('GET', '/partners/clubs', query: {
        'sport': sport, 'q': q, 'mine': mine ? 'true' : null,
      }));

  static Future<Map<String, dynamic>> club(String id) async =>
      _map(await _req('GET', '/partners/clubs/$id'));

  static Future<Map<String, dynamic>> createClub(Map<String, dynamic> body) async =>
      _map(await _req('POST', '/partners/clubs', body: body));

  static Future<Map<String, dynamic>> updateClub(
          String id, Map<String, dynamic> body) async =>
      _map(await _req('PUT', '/partners/clubs/$id', body: body));

  static Future<void> deleteClub(String id) =>
      _req('DELETE', '/partners/clubs/$id');

  static Future<Map<String, dynamic>> joinClub(String id) async =>
      _map(await _req('POST', '/partners/clubs/$id/join'));

  static Future<Map<String, dynamic>> leaveClub(String id) async =>
      _map(await _req('POST', '/partners/clubs/$id/leave'));
}
