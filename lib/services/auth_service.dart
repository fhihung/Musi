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

import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:musify/services/pocketbase_logger.dart';

class AuthResult {
  AuthResult({required this.success, this.error, this.message});
  final bool success;
  final String? error;
  final String? message;
}

class AuthService {
  static final PocketBase _pb = PocketBase('http://10.0.2.2:8090');
  static const String _authStoreKey = 'pb_auth';

  static PocketBase get pb => _pb;

  static bool get isAuthenticated => _pb.authStore.isValid;

  static String? get userId => _pb.authStore.record?.id;

  static String? get userEmail => _pb.authStore.record?.getStringValue('email');

  static String? get userName => _pb.authStore.record?.getStringValue('name');

  /// Initialize auth service and restore previous session
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authData = prefs.getString(_authStoreKey);

      if (authData != null && authData.isNotEmpty) {
        _pb.authStore.save(authData, null);

        // Verify the token is still valid
        if (_pb.authStore.isValid) {
          try {
            await _pb.collection('users').authRefresh();
          } catch (e) {
            // Token is invalid, clear it
            await clearAuth();
          }
        }
      }

      // Listen to auth changes and persist them
      _pb.authStore.onChange.listen((e) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_authStoreKey, e.token);
      });
    } catch (e) {
      // Ignore init errors
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

      PocketBaseLogger.logOperation('CREATE', 'users', data: body);

      await _pb.collection('users').create(body: body);

      PocketBaseLogger.logResult(
        'CREATE users',
        true,
        duration: DateTime.now().difference(startTime),
      );

      return AuthResult(success: true, message: 'Đăng ký thành công!');
    } catch (e) {
      PocketBaseLogger.logResult('CREATE users', false, error: e);
      return AuthResult(success: false, error: _getErrorMessage(e));
    }
  }

  /// Sign in with email and password
  static Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final startTime = DateTime.now();

    try {
      PocketBaseLogger.logOperation('AUTH', 'users', data: {'email': email});

      await _pb.collection('users').authWithPassword(email, password);

      PocketBaseLogger.logResult(
        'AUTH users',
        true,
        duration: DateTime.now().difference(startTime),
      );

      return AuthResult(success: true, message: 'Đăng nhập thành công!');
    } catch (e) {
      PocketBaseLogger.logResult('AUTH users', false, error: e);
      return AuthResult(success: false, error: _getErrorMessage(e));
    }
  }

  /// Sign out current user
  static Future<void> signOut() async {
    _pb.authStore.clear();
    await clearAuth();
  }

  /// Clear stored auth data
  static Future<void> clearAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authStoreKey);
    } catch (e) {
      // Ignore errors
    }
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

      await _pb.collection('users').update(userId!, body: body);

      return AuthResult(
        success: true,
        message: 'Cập nhật thông tin thành công!',
      );
    } catch (e) {
      return AuthResult(success: false, error: _getErrorMessage(e));
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

      await _pb
          .collection('users')
          .update(
            userId!,
            body: {
              'oldPassword': oldPassword,
              'password': newPassword,
              'passwordConfirm': newPassword,
            },
          );

      return AuthResult(success: true, message: 'Đổi mật khẩu thành công!');
    } catch (e) {
      return AuthResult(success: false, error: _getErrorMessage(e));
    }
  }

  /// Request password reset
  static Future<AuthResult> requestPasswordReset(String email) async {
    try {
      await _pb.collection('users').requestPasswordReset(email);

      return AuthResult(
        success: true,
        message: 'Email khôi phục mật khẩu đã được gửi!',
      );
    } catch (e) {
      return AuthResult(success: false, error: _getErrorMessage(e));
    }
  }

  /// Get user-friendly error message
  static String _getErrorMessage(dynamic error) {
    if (error is ClientException) {
      final statusCode = error.statusCode;
      final response = error.response;

      if (statusCode == 400) {
        if (response.toString().contains('email')) {
          return 'Email không hợp lệ hoặc đã được sử dụng';
        }
        if (response.toString().contains('password')) {
          return 'Mật khẩu không hợp lệ';
        }
        return 'Thông tin không hợp lệ';
      }

      if (statusCode == 401) {
        return 'Email hoặc mật khẩu không đúng';
      }

      if (statusCode == 403) {
        return 'Tài khoản chưa được xác thực';
      }

      if (statusCode == 404) {
        return 'Không tìm thấy tài khoản';
      }

      return 'Lỗi kết nối: ${error.response}';
    }

    return error.toString();
  }
}
