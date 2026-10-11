import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/bookable_slot.dart';
import '../models/court.dart';
import '../models/court_listing.dart';
import '../models/my_booking.dart';
import '../models/search_filters.dart';
import '../models/sport_category.dart';
import '../models/venue.dart';
import 'api_config.dart';
import 'auth_service.dart';

/// Error with a message that is safe to show in the UI.
class CatalogException implements Exception {
  final String message;
  final int? status;
  final String? code;
  CatalogException(this.message, {this.status, this.code});
  @override
  String toString() => message;
}

class ListingsResult {
  final int count;
  final List<CourtListing> items;
  const ListingsResult(this.count, this.items);
}

/// Everything the CUSTOMER app reads from the backend. All of this data is
/// created by the admin (facilities, courts, sports, slots).
///   GET  /categories          sports chips
///   GET  /courts              dashboard venue cards
///   GET  /listings            search results (only courts with open admin slots)
///   GET  /venues/:id          venue detail + courts
///   GET  /courts/:id/slots    admin slots of one court on one day
///   POST /bookings            book a slot (needs login)
class CatalogApi {
  static const _timeout = Duration(seconds: 15);

  static String ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<dynamic> _req(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool auth = false,
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
    if (auth && !AuthService.isLoggedIn) {
      throw CatalogException('Please log in first.', status: 401);
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (auth) ...AuthService.authHeaders,
    };

    http.Response res;
    try {
      final f = method == 'POST'
          ? http.post(uri, headers: headers, body: jsonEncode(body ?? {}))
          : http.get(uri, headers: headers);
      res = await f.timeout(_timeout);
    } on TimeoutException {
      throw CatalogException('Server did not respond ($base). Check the backend.');
    } catch (e) {
      debugPrint('[CatalogApi] $method $uri failed: $e');
      throw CatalogException(
          "Can't reach the server at $base. Make sure the backend is running.");
    }

    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(res.body);
      } catch (_) {}
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    final m = data is Map ? data['message'] : null;
    final msg = m is List
        ? m.join('\n')
        : (m?.toString() ?? 'Server error (${res.statusCode})');
    debugPrint('[CatalogApi] $method $uri -> ${res.statusCode}: ${res.body}');
    throw CatalogException(msg,
        status: res.statusCode, code: data is Map ? data['code']?.toString() : null);
  }

  static List<Map<String, dynamic>> _list(dynamic d) => (d is List ? d : [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  /* ---------------- reads (no login needed) ---------------- */

  static Future<List<SportCategory>> categories() async =>
      _list(await _req('GET', '/categories')).map(SportCategory.fromJson).toList();

  static Future<List<Court>> courts({String? sport}) async =>
      _list(await _req('GET', '/courts', query: {'sport': sport}))
          .map(Court.fromJson)
          .toList();

  static Future<ListingsResult> listings(
      SearchFilters f, List<DateTime> days) async {
    final d = await _req('GET', '/listings', query: f.toQuery(days));
    final m = d is Map ? d : const {};
    final items = _list(m['items']).map(CourtListing.fromJson).toList();
    return ListingsResult((m['count'] as num?)?.toInt() ?? items.length, items);
  }

  static Future<Venue> venue(String id) async => Venue.fromJson(
      Map<String, dynamic>.from(await _req('GET', '/venues/$id') as Map));

  static Future<CourtSlots> courtSlots(String courtId, DateTime date) async =>
      CourtSlots.fromJson(Map<String, dynamic>.from(await _req(
          'GET', '/courts/$courtId/slots',
          query: {'date': ymd(date)}) as Map));

  /* ---------------- booking / wallet (login needed) ---------------- */

  /// paymentMethod: 'wallet' (needs [otp] from [requestPaymentOtp]) or 'pay_at_venue'.
  /// Returns the booking JSON.
  static Future<Map<String, dynamic>> createBooking({
    required String slotId,
    required String paymentMethod,
    String? otp,
    int maxPlayers = 4,
  }) async {
    final d = await _req('POST', '/bookings',
        auth: true,
        body: {
          'slotId': slotId,
          'paymentMethod': paymentMethod,
          if (otp != null) 'otp': otp,
          'maxPlayers': maxPlayers,
        });
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  /// POST /payments/otp -> a 6-digit code is sent to the user's mobile.
  static Future<PaymentOtp> requestPaymentOtp() async => PaymentOtp.fromJson(
      Map<String, dynamic>.from(
          await _req('POST', '/payments/otp', auth: true) as Map));

  /// status: upcoming | past | all
  static Future<List<MyBooking>> myBookings(String status) async =>
      _list(await _req('GET', '/bookings', query: {'status': status}, auth: true))
          .map(MyBooking.fromJson)
          .toList();

  static Future<void> cancelBooking(String id) async {
    await _req('POST', '/bookings/$id/cancel', auth: true);
  }

  static Future<WalletInfo> wallet() async => WalletInfo.fromJson(
      Map<String, dynamic>.from(await _req('GET', '/wallet', auth: true) as Map));

  /// POST /wallet/topup (needs ALLOW_DEV_TOPUP=true in backend/.env until a payment gateway is added)
  static Future<WalletInfo> topUp(int amount) async => WalletInfo.fromJson(
      Map<String, dynamic>.from(await _req('POST', '/wallet/topup',
          auth: true, body: {'amount': amount}) as Map));
}
