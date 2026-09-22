import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thrown when the backend rejects a request. [message] is already
/// human-readable (the backend's `auth.service.js` writes it that way), so
/// UI code can show it directly.
class AuthApiException implements Exception {
  final String code;
  final String message;

  const AuthApiException(this.code, this.message);

  @override
  String toString() => message;
}

/// Talks to the backend's `/auth` routes (backend/src/routes/auth.routes.js).
///
/// No accounts are stored on the device by this class -- it only makes
/// requests and returns/throws. Session persistence is [AuthController]'s job.
class AuthApiClient {
  /// The backend's base URL.
  ///
  /// Defaults to `localhost:3000` for local development. That works
  /// directly on web/desktop/iOS simulator, and on a real Android phone
  /// connected over USB *if* you've run `adb reverse tcp:3000 tcp:3000`
  /// once (forwards the phone's `localhost:3000` to this machine's, over
  /// the cable -- no need to find a LAN IP).
  ///
  /// Two situations need an override instead, set before any call is made:
  /// - **Android emulator** (not a real device): `10.0.2.2` is how it
  ///   reaches the host's `localhost` --
  ///   `AuthApiClient.baseUrl = 'http://10.0.2.2:3000';`
  /// - **Real device over Wi-Fi**, without `adb reverse`: use this
  ///   machine's actual LAN IP --
  ///   `AuthApiClient.baseUrl = 'http://192.168.1.23:3000';`
  static String baseUrl = _defaultBaseUrl();

  static String _defaultBaseUrl() {
    return 'http://localhost:3000';
  }

  Future<Map<String, dynamic>> signup({
    required String name,
    required String emailOrPhone,
    required String country,
    required String password,
  }) {
    return _post('/auth/signup', {
      'name': name,
      'emailOrPhone': emailOrPhone,
      'country': country,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> login({
    required String emailOrPhone,
    required String password,
  }) {
    return _post('/auth/login', {
      'emailOrPhone': emailOrPhone,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> continueAsGuest({String? name}) {
    return _post('/auth/guest', {'name': ?name});
  }

  Future<Map<String, dynamic>> me(String token) {
    return _get('/auth/me', token);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (_) {
      throw const AuthApiException(
        'NETWORK_ERROR',
        "Couldn't reach the server. Check your connection and try again.",
      );
    }
    return _decode(response);
  }

  Future<Map<String, dynamic>> _get(String path, String token) async {
    final http.Response response;
    try {
      response = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {
      throw const AuthApiException(
        'NETWORK_ERROR',
        "Couldn't reach the server. Check your connection and try again.",
      );
    }
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AuthApiException('BAD_RESPONSE', 'The server sent back something unexpected.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }

    throw AuthApiException(
      json['error'] as String? ?? 'UNKNOWN_ERROR',
      json['message'] as String? ?? 'Something went wrong. Please try again.',
    );
  }
}
