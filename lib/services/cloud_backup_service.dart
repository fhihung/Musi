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

import 'package:hive/hive.dart';
import 'package:musify/API/version.dart';
import 'package:musify/main.dart';
import 'package:musify/services/auth_service.dart';
import 'package:musify/services/pocketbase_http_client.dart';
import 'package:musify/services/pocketbase_logger.dart';

class CloudBackupService {
  static final PocketBaseHttpClient _client = PocketBaseHttpClient(
    'http://10.0.2.2:8090/api',
  );
  static const String _backupCollection = 'user_backups';
  static const String _backupVersion = '2.0';

  /// Backup data to cloud
  static Future<AuthResult> backupToCloud() async {
    final startTime = DateTime.now();

    try {
      if (!AuthService.isAuthenticated || AuthService.userId == null) {
        return AuthResult(success: false, error: 'Bạn chưa đăng nhập');
      }

      // Collect all data from Hive boxes
      final backupData = await _collectBackupData();

      // Create backup record
      final body = <String, dynamic>{
        'user_id': AuthService.userId,
        'backup_data': backupData,
        'backup_version': _backupVersion,
        'app_version': appVersion,
        'created_at': DateTime.now().toIso8601String(),
      };

      PocketBaseLogger.logOperation(
        'GET LIST',
        _backupCollection,
        filter: 'user_id = "${AuthService.userId}"',
        sort: '-created',
      );

      // Check if backup already exists
      final listResponse = await _client.get(
        '/collections/$_backupCollection/records',
        requiresAuth: true,
        queryParams: {
          'filter': 'user_id = "${AuthService.userId}"',
          'sort': '-created',
        },
      );

      if (listResponse.statusCode == 200) {
        final listData = jsonDecode(listResponse.body) as Map<String, dynamic>;
        final items = listData['items'] as List<dynamic>? ?? [];

        if (items.isNotEmpty) {
          // Update existing backup
          final existingId = items.first['id'] as String;
          PocketBaseLogger.logOperation(
            'UPDATE',
            _backupCollection,
            recordId: existingId,
            data: {'backup_version': _backupVersion, 'app_version': appVersion},
          );

          final updateResponse = await _client.patch(
            '/collections/$_backupCollection/records/$existingId',
            body: body,
            requiresAuth: true,
          );

          if (updateResponse.statusCode != 200) {
            throw Exception('Failed to update backup');
          }
        } else {
          // Create new backup
          PocketBaseLogger.logOperation(
            'CREATE',
            _backupCollection,
            data: {'backup_version': _backupVersion, 'app_version': appVersion},
          );

          final createResponse = await _client.post(
            '/collections/$_backupCollection/records',
            body: body,
            requiresAuth: true,
          );

          if (createResponse.statusCode != 200 &&
              createResponse.statusCode != 201) {
            throw Exception('Failed to create backup');
          }
        }

        PocketBaseLogger.logResult(
          'BACKUP',
          true,
          duration: DateTime.now().difference(startTime),
        );

        return AuthResult(success: true, message: 'Sao lưu thành công!');
      } else {
        throw Exception('Failed to check existing backups');
      }
    } catch (e) {
      logger.log('Backup error', e, null);
      PocketBaseLogger.logResult('BACKUP', false, error: e);
      return AuthResult(success: false, error: 'Lỗi khi sao lưu: $e');
    }
  }

  /// Restore data from cloud
  static Future<AuthResult> restoreFromCloud() async {
    final startTime = DateTime.now();

    try {
      if (!AuthService.isAuthenticated || AuthService.userId == null) {
        return AuthResult(success: false, error: 'Bạn chưa đăng nhập');
      }

      PocketBaseLogger.logOperation(
        'GET LIST',
        _backupCollection,
        filter: 'user_id = "${AuthService.userId}"',
        sort: '-created',
      );

      // Get latest backup
      final response = await _client.get(
        '/collections/$_backupCollection/records',
        requiresAuth: true,
        queryParams: {
          'filter': 'user_id = "${AuthService.userId}"',
          'sort': '-created',
          'perPage': '1',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];

        if (items.isEmpty) {
          return AuthResult(
            success: false,
            error: 'Không tìm thấy bản sao lưu nào',
          );
        }

        final latestBackup = items.first as Map<String, dynamic>;
        final backupData = latestBackup['backup_data'] as Map<String, dynamic>;

        // Restore the backup
        await _restoreBackupData(backupData);

        PocketBaseLogger.logResult(
          'RESTORE',
          true,
          duration: DateTime.now().difference(startTime),
        );

        return AuthResult(success: true, message: 'Khôi phục thành công!');
      } else {
        throw Exception('Failed to fetch backups');
      }
    } catch (e) {
      logger.log('Restore error', e, null);
      PocketBaseLogger.logResult('RESTORE', false, error: e);
      return AuthResult(success: false, error: 'Lỗi khi khôi phục: $e');
    }
  }

  /// Delete all cloud backups
  static Future<AuthResult> deleteCloudBackup() async {
    final startTime = DateTime.now();

    try {
      if (!AuthService.isAuthenticated || AuthService.userId == null) {
        return AuthResult(success: false, error: 'Bạn chưa đăng nhập');
      }

      PocketBaseLogger.logOperation(
        'GET LIST',
        _backupCollection,
        filter: 'user_id = "${AuthService.userId}"',
      );

      // Get all backups
      final response = await _client.get(
        '/collections/$_backupCollection/records',
        requiresAuth: true,
        queryParams: {'filter': 'user_id = "${AuthService.userId}"'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];

        // Delete each backup
        for (final item in items) {
          final id = item['id'] as String;
          await _client.delete(
            '/collections/$_backupCollection/records/$id',
            requiresAuth: true,
          );
        }

        PocketBaseLogger.logResult(
          'DELETE',
          true,
          duration: DateTime.now().difference(startTime),
        );

        return AuthResult(success: true, message: 'Xóa sao lưu thành công!');
      } else {
        throw Exception('Failed to fetch backups');
      }
    } catch (e) {
      logger.log('Delete backup error', e, null);
      PocketBaseLogger.logResult('DELETE', false, error: e);
      return AuthResult(success: false, error: 'Lỗi khi xóa sao lưu: $e');
    }
  }

  /// Get backup history
  static Future<List<Map<String, dynamic>>> getBackupHistory() async {
    try {
      if (!AuthService.isAuthenticated || AuthService.userId == null) {
        return [];
      }

      final response = await _client.get(
        '/collections/$_backupCollection/records',
        requiresAuth: true,
        queryParams: {
          'filter': 'user_id = "${AuthService.userId}"',
          'sort': '-created',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];

        return items.map((item) => item as Map<String, dynamic>).toList();
      }

      return [];
    } catch (e) {
      logger.log('Error getting backup history', e, null);
      return [];
    }
  }

  /// Collect backup data from Hive
  static Future<Map<String, dynamic>> _collectBackupData() async {
    final userBox = await Hive.openBox('user');
    final cacheBox = await Hive.openBox('cache');

    // Collect user-specific data
    final userData = <String, dynamic>{
      'language': userBox.get('language'),
      'themeMode': userBox.get('themeMode'),
      'accentColor': userBox.get('accentColor'),
      'useSystemColor': userBox.get('useSystemColor'),
      'sponsorBlockEnabled': userBox.get('sponsorBlockEnabled'),
      'playNextSongAutomatically': userBox.get('playNextSongAutomatically'),
      'defaultRecommendations': userBox.get('defaultRecommendations'),
      'audioQuality': userBox.get('audioQuality'),
      'favoriteGenres': userBox.get('favoriteGenres', defaultValue: []),
    };

    // Collect custom playlists
    final customPlaylists = <Map<String, dynamic>>[];
    for (var i = 0; i < userBox.length; i++) {
      final key = userBox.keyAt(i);
      if (key.toString().startsWith('customId-')) {
        final playlist = userBox.getAt(i);
        if (playlist is Map) {
          customPlaylists.add(Map<String, dynamic>.from(playlist));
        }
      }
    }

    // Collect cached data
    final cachedData = <String, dynamic>{
      'likedSongs': cacheBox.get('likedSongsCache', defaultValue: []),
      'recentlyPlayedSongs': userBox.get(
        'recentlyPlayedSongs',
        defaultValue: [],
      ),
      'offlineSongs': userBox.get('offlineSongs', defaultValue: []),
    };

    return {
      'user': userData,
      'playlists': customPlaylists,
      'cache': cachedData,
    };
  }

  /// Restore backup data to Hive
  static Future<void> _restoreBackupData(
    Map<String, dynamic> backupData,
  ) async {
    try {
      final userBox = await Hive.openBox('user');
      final cacheBox = await Hive.openBox('cache');

      // Restore user data
      final userData = backupData['user'] as Map<String, dynamic>? ?? {};
      if (userData.isNotEmpty) {
        await userBox.put('language', userData['language']);
        await userBox.put('themeMode', userData['themeMode']);
        await userBox.put('accentColor', userData['accentColor']);
        await userBox.put('useSystemColor', userData['useSystemColor']);
        await userBox.put(
          'sponsorBlockEnabled',
          userData['sponsorBlockEnabled'],
        );
        await userBox.put(
          'playNextSongAutomatically',
          userData['playNextSongAutomatically'],
        );
        await userBox.put(
          'defaultRecommendations',
          userData['defaultRecommendations'],
        );
        await userBox.put('audioQuality', userData['audioQuality']);
        await userBox.put('favoriteGenres', userData['favoriteGenres'] ?? []);
      }

      // Restore custom playlists
      final playlists = backupData['playlists'] as List<dynamic>? ?? [];
      for (final playlist in playlists) {
        if (playlist is Map<String, dynamic>) {
          final ytid = playlist['ytid'];
          if (ytid != null) {
            await userBox.put(ytid, playlist);
          }
        }
      }

      // Restore cached data
      final cachedData = backupData['cache'] as Map<String, dynamic>? ?? {};
      if (cachedData.isNotEmpty) {
        await cacheBox.put('likedSongsCache', cachedData['likedSongs'] ?? []);
        await userBox.put(
          'recentlyPlayedSongs',
          cachedData['recentlyPlayedSongs'] ?? [],
        );
        await userBox.put('offlineSongs', cachedData['offlineSongs'] ?? []);
      }
    } catch (e, stackTrace) {
      logger.log('Error restoring backup data', e, stackTrace);
    }
  }
}
