import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import 'api_config.dart';

/// Error with a message that is safe to show in a SnackBar.
class AuthException implements Exception {
  final String message;
  final int? status;
  final String? code;
  final Map<String, dynamic> data;
  AuthException(this.message,
      {this.status, this.code, this.data = const <String, dynamic>{}});
  @override
  String toString() => message;
}

/// Returned by register / resend-otp. The OTP screen is built from this.
class OtpChallenge {
  /// 9-digit national number, e.g. 771234567
  final String phone;
  final int expiresInSeconds;
  final int resendInSeconds;

  /// Only present when the backend runs with OTP_DEV_MODE=true.
  final String? devOtp;

  const OtpChallenge({
    required this.phone,
    required this.expiresInSeconds,
    required this.resendInSeconds,
    this.devOtp,
  });

  factory OtpChallenge.fromJson(Map<String, dynamic> j) => OtpChallenge(
        phone: (j['phone'] ?? '').toString(),
        expiresInSeconds: (j['expiresInSeconds'] as num?)?.toInt() ?? 300,
        resendInSeconds: (j['resendInSeconds'] as num?)?.toInt() ?? 30,
        devOtp: j['devOtp']?.toString(),
      );
}

/// Login worked, but the mobile number was never verified.
class NotVerifiedException implements Exception {
  final OtpChallenge challenge;
  NotVerifiedException(this.challenge);
}

class AuthService {
  static const _tokenKey = 'access_token';
  static const _userKey = 'current_user';
  static const _timeout = Duration(seconds: 15);

  static String? _token;

  /// The logged-in user (null = guest). Widgets can listen to this.
  static final ValueNotifier<AppUser?> user = ValueNotifier<AppUser?>(null);

  static bool get isLoggedIn => _token != null;

  /// Call once in main() before runApp().
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
      final raw = prefs.getString(_userKey);
      if (_token != null && raw != null) {
        user.value = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[Auth] could not restore session: $e');
      _token = null;
      user.value = null;
    }
    if (_token != null) unawaited(refreshProfile());
  }

  /* ---------------- API calls ---------------- */

  /// POST /auth/register -> OTP is sent to the phone.
  static Future<OtpChallenge> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required List<String> sports,
  }) async {
    final data = await _send('POST', '/auth/register', body: {
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'password': password,
      'sports': sports,
    });
    return OtpChallenge.fromJson(data);
  }

  /// POST /auth/verify-otp -> logs the user in.
  static Future<void> verifyOtp(
      {required String phone, required String code}) async {
    final data = await _send('POST', '/auth/verify-otp',
        body: {'phone': phone, 'code': code});
    await _saveSession(data);
  }

  /// POST /auth/resend-otp
  static Future<OtpChallenge> resendOtp(String phone) async {
    final data = await _send('POST', '/auth/resend-otp', body: {'phone': phone});
    return OtpChallenge.fromJson(data);
  }

  /// POST /auth/login. Throws [NotVerifiedException] if OTP was never completed.
  static Future<void> login(
      {required String identifier, required String password}) async {
    try {
      final data = await _send('POST', '/auth/login',
          body: {'identifier': identifier, 'password': password});
      await _saveSession(data);
    } on AuthException catch (e) {
      if (e.code == 'PHONE_NOT_VERIFIED') {
        throw NotVerifiedException(OtpChallenge.fromJson(e.data));
      }
      rethrow;
    }
  }

  /// GET /auth/me -> updates [user]. Logs out if the token is no longer valid.
  static Future<AppUser?> refreshProfile() async {
    if (_token == null) return null;
    try {
      final data = await _send('GET', '/auth/me', auth: true);
      await _storeUser(data);
    } on AuthException catch (e) {
      if (e.status == 401) await logout();
    }
    return user.value;
  }

  static Future<void> logout() async {
    _token = null;
    user.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } catch (_) {}
  }

  /// Headers for other authenticated calls later (bookings, wallet ...).
  static Map<String, String> get authHeaders =>
      {if (_token != null) 'Authorization': 'Bearer $_token'};

  /* ---------------- internals ---------------- */

  static Future<void> _saveSession(Map<String, dynamic> data) async {
    final token = data['accessToken'];
    final userJson = data['user'];
    if (token is! String || userJson is! Map) {
      throw AuthException('Unexpected response from server');
    }
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await _storeUser(Map<String, dynamic>.from(userJson));
  }

  static Future<void> _storeUser(Map<String, dynamic> userJson) async {
    user.value = AppUser.fromJson(userJson);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(userJson));
  }

  static Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final base = ApiConfig.baseUrl;
    final uri = Uri.parse('$base$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (auth && _token != null) 'Authorization': 'Bearer $_token',
    };

    http.Response res;
    try {
      final future = method == 'GET'
          ? http.get(uri, headers: headers)
          : http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
      res = await future.timeout(_timeout);
    } on TimeoutException {
      throw AuthException('Server did not respond ($base). Check the backend.');
    } catch (e) {
      debugPrint('[API] $method $uri failed: $e');
      throw AuthException(
          "Can't reach the server at $base. Make sure the backend is running (see backend/README.md).");
    }

    var data = <String, dynamic>{};
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } catch (_) {}

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    // NestJS errors: { statusCode, message: String | List<String>, ... }
    final m = data['message'];
    final msg = m is List
        ? m.join('\n')
        : (m?.toString() ?? 'Server error (${res.statusCode})');
    debugPrint('[API] $method $uri -> ${res.statusCode}: ${res.body}');
    throw AuthException(msg,
        status: res.statusCode, code: data['code']?.toString(), data: data);
  }
}
