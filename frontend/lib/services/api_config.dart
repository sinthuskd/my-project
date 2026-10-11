import 'package:flutter/foundation.dart';

/// Backend base URL (NestJS, see /backend).
///
/// Defaults:
///   Chrome / Windows / iOS simulator -> http://127.0.0.1:3000
///   Android emulator                 -> http://10.0.2.2:3000
///
/// Real phone (same Wi-Fi as your PC): the backend prints a "Network:" URL
/// when it starts. Run the app with that URL:
///   flutter run --dart-define=API_URL=http://192.168.1.5:3000
class ApiConfig {
  static const _override = String.fromEnvironment('API_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    // 127.0.0.1 instead of "localhost" avoids IPv6 (::1) problems on Windows.
    return 'http://127.0.0.1:3000';
  }
}
