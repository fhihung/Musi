/*
 *     Copyright (C) 2025 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:musify/services/pocketbase_http_client.dart';
import 'package:musify/services/pocketbase_logger.dart';

class AuthResult {
  AuthResult({required this.success, this.error, this.message});
  final bool success;
  final String? error;
  final String? message;
}

/// Authentication service using PocketBase REST API
/// Reference: https://pocketbase.io/docs/api-records/
class AuthService {
  static final PocketBaseHttpClient _client = PocketBaseHttpClient(
    'http://10.0.2.2:8090/api',
  );

  static const String _userCollection = 'users';
  static Map<String, dynamic>? _currentUser;

  /// Get current authenticated user
  static Map<String, dynamic>? get currentUser => _currentUser;

  /// Check if user is authenticated
  static bool get isAuthenticated => _client.isAuthenticated;

  /// Get current user ID
  static String? get userId => _currentUser?['id'] as String?;

  /// Get current user email
  static String? get userEmail => _currentUser?['email'] as String?;

  /// Get current user name
  static String? get userName => _currentUser?['name'] as String?;

  /// Get current auth token
  static String? get authToken => _client.authToken;

  /// Initialize auth service and restore previous session
  static Future<void> init() async {
    try {
      await _client.init();

      // Try to restore user data from storage
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('pb_auth_user');

      if (userJson != null && _client.isAuthenticated) {
        try {
          _currentUser = jsonDecode(userJson) as Map<String, dynamic>;

          // Verify the token is still valid by refreshing
          await authRefresh();
        } catch (e) {
          // Token is invalid, clear it
          await clearAuth();
        }
      }
    } catch (e) {
      // Ignore init errors
    }
  }

  /// Refresh auth token
  static Future<bool> authRefresh() async {
    try {
      PocketBaseLogger.logOperation('AUTH REFRESH', _userCollection);
      final startTime = DateTime.now();

      final response = await _client.post(
        '/collections/$_userCollection/auth-refresh',
        body: {},
        requiresAuth: true,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String;
        final record = data['record'] as Map<String, dynamic>;

        await _client.saveAuthToken(token);
        _currentUser = record;

        // Save user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pb_auth_user', jsonEncode(record));

        PocketBaseLogger.logResult(
          'AUTH REFRESH',
          true,
          duration: DateTime.now().difference(startTime),
        );
        return true;
      } else {
        PocketBaseLogger.logResult('AUTH REFRESH', false, error: response.body);
        return false;
      }
    } catch (e) {
      PocketBaseLogger.logResult('AUTH REFRESH', false, error: e);
      return false;
    }
  }

  /// Sign up a new user
  static Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final startTime = DateTime.now();

    try {
      final body = <String, dynamic>{
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'name': name,
        'emailVisibility': true,
      };

      PocketBaseLogger.logOperation('CREATE', _userCollection, data: body);

      final response = await _client.post(
        '/collections/$_userCollection/records',
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        PocketBaseLogger.logResult(
          'CREATE $_userCollection',
          true,
          duration: DateTime.now().difference(startTime),
        );
        return AuthResult(success: true, message: 'Đăng ký thành công!');
      } else {
        final error = _parseErrorMessage(response.body);
        PocketBaseLogger.logResult(
          'CREATE $_userCollection',
          false,
          error: error,
        );
        return AuthResult(success: false, error: error);
      }
    } catch (e) {
      PocketBaseLogger.logResult('CREATE $_userCollection', false, error: e);
      return AuthResult(success: false, error: 'Lỗi kết nối: $e');
    }
  }

  /// Sign in with email and password
  static Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final startTime = DateTime.now();

    try {
      PocketBaseLogger.logOperation(
        'AUTH',
        _userCollection,
        data: {'identity': email},
      );

      final response = await _client.post(
        '/collections/$_userCollection/auth-with-password',
        body: {'identity': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String;
        final record = data['record'] as Map<String, dynamic>;

        // Save auth token
        await _client.saveAuthToken(token);
        _currentUser = record;

        // Save user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pb_auth_user', jsonEncode(record));

        PocketBaseLogger.logResult(
          'AUTH $_userCollection',
          true,
          duration: DateTime.now().difference(startTime),
        );

        return AuthResult(success: true, message: 'Đăng nhập thành công!');
      } else {
        final error = _parseErrorMessage(response.body);
        PocketBaseLogger.logResult(
          'AUTH $_userCollection',
          false,
          error: error,
        );
        return AuthResult(success: false, error: error);
      }
    } catch (e) {
      PocketBaseLogger.logResult('AUTH $_userCollection', false, error: e);
      return AuthResult(success: false, error: 'Lỗi kết nối: $e');
    }
  }

  /// Sign out current user
  static Future<void> signOut() async {
    await clearAuth();
  }

  /// Clear stored auth data
  static Future<void> clearAuth() async {
    _currentUser = null;
    await _client.clearAuthToken();
  }

  /// Update user profile
  static Future<AuthResult> updateProfile({
    String? name,
    String? avatar,
  }) async {
    try {
      if (!isAuthenticated || userId == null) {
        return AuthResult(success: false, error: 'Bạn chưa đăng nhập');
      }

      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (avatar != null) body['avatar'] = avatar;

      final response = await _client.patch(
        '/collections/$_userCollection/records/$userId',
        body: body,
        requiresAuth: true,
      );

      if (response.statusCode == 200) {
        final record = jsonDecode(response.body) as Map<String, dynamic>;
        _currentUser = record;

        // Update saved user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pb_auth_user', jsonEncode(record));

        return AuthResult(
          success: true,
          message: 'Cập nhật thông tin thành công!',
        );
      } else {
        return AuthResult(
          success: false,
          error: _parseErrorMessage(response.body),
        );
      }
    } catch (e) {
      return AuthResult(success: false, error: 'Lỗi kết nối: $e');
    }
  }

  /// Change password
  static Future<AuthResult> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      if (!isAuthenticated || userId == null) {
        return AuthResult(success: false, error: 'Bạn chưa đăng nhập');
      }

      final response = await _client.patch(
        '/collections/$_userCollection/records/$userId',
        body: {
          'oldPassword': oldPassword,
          'password': newPassword,
          'passwordConfirm': newPassword,
        },
        requiresAuth: true,
      );

      if (response.statusCode == 200) {
        return AuthResult(success: true, message: 'Đổi mật khẩu thành công!');
      } else {
        return AuthResult(
          success: false,
          error: _parseErrorMessage(response.body),
        );
      }
    } catch (e) {
      return AuthResult(success: false, error: 'Lỗi kết nối: $e');
    }
  }

  /// Parse error message from PocketBase response
  static String _parseErrorMessage(String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final message = json['message'] as String?;

      if (message != null) {
        // Translate common error messages
        if (message.contains('Failed to authenticate')) {
          return 'Email hoặc mật khẩu không đúng';
        }
        if (message.contains('already exists')) {
          return 'Email đã được sử dụng';
        }
        return message;
      }

      return 'Có lỗi xảy ra';
    } catch (e) {
      return responseBody;
    }
  }
}
