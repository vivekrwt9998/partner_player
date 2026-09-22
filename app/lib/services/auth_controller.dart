import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import 'auth_api_client.dart';

enum AuthStatus {
  /// Restoring a previously saved session from disk, on app startup.
  loading,
  authenticated,
  unauthenticated,
}

/// App-wide session state: who's logged in (if anyone) and the token that
/// proves it. A single shared instance ([instance]) rather than a package
/// like `provider`, matching how the rest of this app keeps its
/// controllers local and dependency-free (AGENTS.md §54).
class AuthController extends ChangeNotifier {
  AuthController._();

  static final AuthController instance = AuthController._();

  static const _tokenKey = 'auth_token';

  final AuthApiClient _api = AuthApiClient();

  AuthStatus status = AuthStatus.loading;
  AppUser? user;
  String? _token;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// The current session token, for authenticated calls to other backend
  /// endpoints as they're added. `null` when signed out.
  String? get token => _token;

  /// Restores a saved session (if any) on app startup. Safe to call once;
  /// [MainShell]/the auth gate should wait for this before deciding what to
  /// show.
  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_tokenKey);
    if (savedToken == null) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      final response = await _api.me(savedToken);
      _token = savedToken;
      user = AppUser.fromJson(response['user'] as Map<String, dynamic>);
      status = AuthStatus.authenticated;
    } catch (_) {
      // Saved token is no longer valid (expired, or the guest account was
      // cleaned up server-side) -- fall back to signed-out rather than
      // getting stuck.
      await prefs.remove(_tokenKey);
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> signup({
    required String name,
    required String emailOrPhone,
    required String country,
    required String password,
  }) async {
    final response = await _api.signup(
      name: name,
      emailOrPhone: emailOrPhone,
      country: country,
      password: password,
    );
    await _applySession(response);
  }

  Future<void> login({
    required String emailOrPhone,
    required String password,
  }) async {
    final response = await _api.login(emailOrPhone: emailOrPhone, password: password);
    await _applySession(response);
  }

  Future<void> continueAsGuest({String? name}) async {
    final response = await _api.continueAsGuest(name: name);
    await _applySession(response);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _token = null;
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> _applySession(Map<String, dynamic> response) async {
    final prefs = await SharedPreferences.getInstance();
    final token = response['token'] as String;
    await prefs.setString(_tokenKey, token);

    _token = token;
    user = AppUser.fromJson(response['user'] as Map<String, dynamic>);
    status = AuthStatus.authenticated;
    notifyListeners();
  }
}
