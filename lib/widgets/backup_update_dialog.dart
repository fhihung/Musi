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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:musify/services/cloud_backup_service.dart';
import 'package:musify/utilities/flutter_toast.dart';

class BackupUpdateDialog extends StatefulWidget {
  const BackupUpdateDialog({super.key});

  @override
  State<BackupUpdateDialog> createState() => _BackupUpdateDialogState();
}

class _BackupUpdateDialogState extends State<BackupUpdateDialog> {
  bool _isLoading = false;

  Future<void> _performRestore() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await CloudBackupService.restoreFromCloud();

      if (mounted) {
        if (result.success) {
          showToast(context, result.message ?? 'Khôi phục thành công!');
          Navigator.of(context).pop(true); // Return true to indicate success
        } else {
          showToast(context, result.error ?? 'Khôi phục thất bại');
        }
      }
    } catch (e) {
      if (mounted) {
        showToast(context, 'Lỗi khi khôi phục: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            FluentIcons.cloud_arrow_down_24_regular,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text('Cập nhật dữ liệu'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chúng tôi tìm thấy bản sao lưu dữ liệu của bạn trên đám mây. '
            'Bạn có muốn khôi phục dữ liệu này không?',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      FluentIcons.info_24_regular,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Dữ liệu sẽ được khôi phục bao gồm:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildInfoItem(FluentIcons.music_note_2_24_regular, 'Playlist'),
                _buildInfoItem(
                  FluentIcons.heart_24_regular,
                  'Bài hát yêu thích',
                ),
                _buildInfoItem(
                  FluentIcons.arrow_download_24_regular,
                  'Nhạc offline',
                ),
                _buildInfoItem(FluentIcons.settings_24_regular, 'Cài đặt'),
                _buildInfoItem(FluentIcons.history_24_regular, 'Lịch sử phát'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Lưu ý: Dữ liệu hiện tại sẽ được ghi đè bởi dữ liệu từ bản sao lưu.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Bỏ qua'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _performRestore,
          child: _isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Khôi phục'),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
