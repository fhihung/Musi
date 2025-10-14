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
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// HTTP client for PocketBase API
/// Reference: https://pocketbase.io/docs/api-records/
class PocketBaseHttpClient {
  PocketBaseHttpClient._internal(this.baseUrl);

  static PocketBaseHttpClient? _instance;

  factory PocketBaseHttpClient(String baseUrl) {
    _instance ??= PocketBaseHttpClient._internal(baseUrl);
    return _instance!;
  }

  final String baseUrl;
  String? _authToken;

  /// Initialize and restore auth token from storage
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('pb_auth_token');
    } catch (e) {
      // Ignore init errors
    }
  }

  /// Save auth token to storage
  Future<void> saveAuthToken(String token) async {
    _authToken = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pb_auth_token', token);
    } catch (e) {
      // Ignore save errors
    }
  }

  /// Clear auth token from storage
  Future<void> clearAuthToken() async {
    _authToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pb_auth_token');
      await prefs.remove('pb_auth_user');
    } catch (e) {
      // Ignore clear errors
    }
  }

  /// Get current auth token
  String? get authToken => _authToken;

  /// Check if authenticated
  bool get isAuthenticated => _authToken != null && _authToken!.isNotEmpty;

  /// Build headers with optional auth token
  Map<String, String> _buildHeaders({bool includeAuth = false}) {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (includeAuth && _authToken != null) {
      headers['Authorization'] = _authToken!;
    }

    return headers;
  }

  /// GET request
  Future<http.Response> get(
    String path, {
    bool requiresAuth = false,
    Map<String, String>? queryParams,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (queryParams != null) {
      uri = uri.replace(queryParameters: queryParams);
    }

    return http.get(uri, headers: _buildHeaders(includeAuth: requiresAuth));
  }

  /// POST request
  Future<http.Response> post(
    String path, {
    required Map<String, dynamic> body,
    bool requiresAuth = false,
  }) async {
    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: _buildHeaders(includeAuth: requiresAuth),
      body: jsonEncode(body),
    );
  }

  /// PUT request
  Future<http.Response> put(
    String path, {
    required Map<String, dynamic> body,
    bool requiresAuth = false,
  }) async {
    return http.put(
      Uri.parse('$baseUrl$path'),
      headers: _buildHeaders(includeAuth: requiresAuth),
      body: jsonEncode(body),
    );
  }

  /// PATCH request
  Future<http.Response> patch(
    String path, {
    required Map<String, dynamic> body,
    bool requiresAuth = false,
  }) async {
    return http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _buildHeaders(includeAuth: requiresAuth),
      body: jsonEncode(body),
    );
  }

  /// DELETE request
  Future<http.Response> delete(String path, {bool requiresAuth = false}) async {
    return http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _buildHeaders(includeAuth: requiresAuth),
    );
  }
}
