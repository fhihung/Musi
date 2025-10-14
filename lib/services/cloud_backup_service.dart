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

import 'package:hive/hive.dart';
import 'package:musify/API/version.dart';
import 'package:musify/main.dart';
import 'package:musify/services/auth_service.dart';
import 'package:musify/services/pocketbase_logger.dart';

class CloudBackupService {
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
      final existingBackups = await AuthService.pb
          .collection(_backupCollection)
          .getFullList(
            filter: 'user_id = "${AuthService.userId}"',
            sort: '-created',
          );

      if (existingBackups.isNotEmpty) {
        // Update existing backup
        PocketBaseLogger.logOperation(
          'UPDATE',
          _backupCollection,
          recordId: existingBackups.first.id,
          data: {'backup_version': _backupVersion, 'app_version': appVersion},
        );

        await AuthService.pb
            .collection(_backupCollection)
            .update(existingBackups.first.id, body: body);
      } else {
        // Create new backup
        PocketBaseLogger.logOperation(
          'CREATE',
          _backupCollection,
          data: {'backup_version': _backupVersion, 'app_version': appVersion},
        );

        await AuthService.pb.collection(_backupCollection).create(body: body);
      }

      PocketBaseLogger.logResult(
        'BACKUP',
        true,
        duration: DateTime.now().difference(startTime),
      );

      return AuthResult(success: true, message: 'Sao lưu thành công!');
    } catch (e) {
      logger.log('Backup error', e, null);
      PocketBaseLogger.logResult('BACKUP', false, error: e);
      return AuthResult(success: false, error: 'Lỗi khi sao lưu: $e');
    }
  }

  /// Restore data from cloud
  static Future<AuthResult> restoreFromCloud() async {
    try {
      if (!AuthService.isAuthenticated || AuthService.userId == null) {
        return AuthResult(success: false, error: 'Bạn chưa đăng nhập');
      }

      // Get latest backup
      final backups = await AuthService.pb
          .collection(_backupCollection)
          .getFullList(
            filter: 'user_id = "${AuthService.userId}"',
            sort: '-created',
          );

      if (backups.isEmpty) {
        return AuthResult(
          success: false,
          error: 'Không tìm thấy bản sao lưu nào',
        );
      }

      final backup = backups.first;
      final backupData =
          backup.data['backup_data'] as Map<String, dynamic>? ?? {};

      // Restore data to Hive boxes
      await _restoreBackupData(backupData);

      return AuthResult(
        success: true,
        message: 'Khôi phục dữ liệu thành công!',
      );
    } catch (e) {
      logger.log('Restore error', e, null);
      return AuthResult(success: false, error: 'Lỗi khi khôi phục: $e');
    }
  }

  /// Get backup history
  static Future<List<Map<String, dynamic>>> getBackupHistory() async {
    try {
      if (!AuthService.isAuthenticated || AuthService.userId == null) {
        return [];
      }

      final backups = await AuthService.pb
          .collection(_backupCollection)
          .getFullList(
            filter: 'user_id = "${AuthService.userId}"',
            sort: '-created',
          );

      return backups.map((backup) {
        return {
          'id': backup.id,
          'created_at': backup.data['created_at'] as String?,
          'app_version': backup.data['app_version'] as String?,
          'backup_version': backup.data['backup_version'] as String?,
        };
      }).toList();
    } catch (e) {
      logger.log('Get backup history error', e, null);
      return [];
    }
  }

  /// Delete all cloud backups
  static Future<AuthResult> deleteCloudBackup() async {
    try {
      if (!AuthService.isAuthenticated || AuthService.userId == null) {
        return AuthResult(success: false, error: 'Bạn chưa đăng nhập');
      }

      final backups = await AuthService.pb
          .collection(_backupCollection)
          .getFullList(filter: 'user_id = "${AuthService.userId}"');

      for (final backup in backups) {
        await AuthService.pb.collection(_backupCollection).delete(backup.id);
      }

      return AuthResult(success: true, message: 'Xóa sao lưu thành công!');
    } catch (e) {
      logger.log('Delete backup error', e, null);
      return AuthResult(success: false, error: 'Lỗi khi xóa sao lưu: $e');
    }
  }

  /// Collect all data from Hive boxes
  static Future<Map<String, dynamic>> _collectBackupData() async {
    final userBox = await Hive.openBox('user');
    final settingsBox = await Hive.openBox('settings');

    // Get user data
    final userData = {
      'customPlaylists': userBox.get('customPlaylists', defaultValue: []),
      'likedSongs': userBox.get('likedSongs', defaultValue: []),
      'recentlyPlayedSongs': userBox.get(
        'recentlyPlayedSongs',
        defaultValue: [],
      ),
      'searchHistory': userBox.get('searchHistory', defaultValue: []),
      'favoriteGenres': userBox.get('favoriteGenres', defaultValue: []),
    };

    // Get settings data
    final settingsData = {
      'offlineMode': settingsBox.get('offlineMode', defaultValue: false),
      'useProxy': settingsBox.get('useProxy', defaultValue: false),
      'usePureBlackColor': settingsBox.get(
        'usePureBlackColor',
        defaultValue: false,
      ),
      'useSystemColor': settingsBox.get('useSystemColor', defaultValue: true),
      'themeMode': settingsBox.get('themeMode'),
      'language': settingsBox.get('language'),
    };

    return {
      'user': {
        ...userData,
        'email': AuthService.userEmail,
        'name': AuthService.userName,
        'userId': AuthService.userId,
        'username': AuthService.userName,
        'favoriteGenres': userData['favoriteGenres'],
        'lastSyncTime': DateTime.now().toIso8601String(),
      },
      'settings': settingsData,
      'playlists': {
        'customPlaylists': userBox.get('customPlaylists', defaultValue: []),
        'likedSongs': userBox.get('likedSongs', defaultValue: []),
        'likedPlaylists': userBox.get('likedPlaylists', defaultValue: []),
        'userPlaylists': userBox.get('userPlaylists', defaultValue: []),
        'recentlyPlayedSongs': userBox.get(
          'recentlyPlayedSongs',
          defaultValue: [],
        ),
        'mostPlayedSongs': userBox.get('mostPlayedSongs', defaultValue: []),
      },
      'metadata': {
        'timestamp': DateTime.now().toIso8601String(),
        'deviceInfo': {
          'platform': 'flutter',
          'timestamp': DateTime.now().toIso8601String(),
        },
        'appVersion': appVersion,
        'backupVersion': _backupVersion,
      },
    };
  }

  /// Restore data to Hive boxes
  static Future<void> _restoreBackupData(
    Map<String, dynamic> backupData,
  ) async {
    try {
      final userBox = await Hive.openBox('user');
      final settingsBox = await Hive.openBox('settings');

      // Restore user data
      final userData = backupData['user'] as Map<String, dynamic>? ?? {};
      if (userData.isNotEmpty) {
        await userBox.put('customPlaylists', userData['customPlaylists'] ?? []);
        await userBox.put('likedSongs', userData['likedSongs'] ?? []);
        await userBox.put(
          'recentlyPlayedSongs',
          userData['recentlyPlayedSongs'] ?? [],
        );
        await userBox.put('searchHistory', userData['searchHistory'] ?? []);
        await userBox.put('favoriteGenres', userData['favoriteGenres'] ?? []);
      }

      // Restore playlists data
      final playlistsData =
          backupData['playlists'] as Map<String, dynamic>? ?? {};
      if (playlistsData.isNotEmpty) {
        await userBox.put(
          'likedPlaylists',
          playlistsData['likedPlaylists'] ?? [],
        );
        await userBox.put(
          'userPlaylists',
          playlistsData['userPlaylists'] ?? [],
        );
        await userBox.put(
          'mostPlayedSongs',
          playlistsData['mostPlayedSongs'] ?? [],
        );
      }

      // Restore settings data
      final settingsData =
          backupData['settings'] as Map<String, dynamic>? ?? {};
      if (settingsData.isNotEmpty) {
        await settingsBox.put(
          'offlineMode',
          settingsData['offlineMode'] ?? false,
        );
        await settingsBox.put('useProxy', settingsData['useProxy'] ?? false);
        await settingsBox.put(
          'usePureBlackColor',
          settingsData['usePureBlackColor'] ?? false,
        );
        await settingsBox.put(
          'useSystemColor',
          settingsData['useSystemColor'] ?? true,
        );
        if (settingsData['themeMode'] != null) {
          await settingsBox.put('themeMode', settingsData['themeMode']);
        }
        if (settingsData['language'] != null) {
          await settingsBox.put('language', settingsData['language']);
        }
      }

      logger.log('Restore completed successfully', null, null);
    } catch (e, stackTrace) {
      logger.log('Error restoring backup data', e, stackTrace);
      rethrow;
    }
  }
}
