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

import 'package:get/get.dart';
import 'package:musify/services/auth_service.dart';

/// Authentication controller using GetX for reactive state management
class AuthController extends GetxController {
  // Observable authentication state
  final _isAuthenticated = false.obs;

  /// Check if user is authenticated (observable)
  RxBool get isAuthenticated => _isAuthenticated;

  /// Get current user data
  Map<String, dynamic>? get currentUser => AuthService.currentUser;

  /// Get user email
  String? get userEmail => AuthService.userEmail;

  /// Get user name
  String? get userName => AuthService.userName;

  /// Get user ID
  String? get userId => AuthService.userId;

  @override
  void onInit() {
    super.onInit();
    // Initialize auth state from AuthService
    updateAuthState();
  }

  /// Update auth state from AuthService
  void updateAuthState() {
    _isAuthenticated.value = AuthService.isAuthenticated;
  }

  /// Sign in
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final result = await AuthService.signIn(email: email, password: password);
    if (result.success) {
      updateAuthState();
    }
    return result;
  }

  /// Sign up
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final result = await AuthService.signUp(
      email: email,
      password: password,
      name: name,
    );
    if (result.success) {
      updateAuthState();
    }
    return result;
  }

  /// Sign out
  Future<void> signOut() async {
    await AuthService.signOut();
    updateAuthState();
  }

  /// Refresh auth token
  Future<bool> refreshAuth() async {
    final result = await AuthService.authRefresh();
    if (result) {
      updateAuthState();
    }
    return result;
  }
}
