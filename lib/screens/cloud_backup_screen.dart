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
import 'package:intl/intl.dart';
import 'package:musify/services/auth_service.dart';
import 'package:musify/services/cloud_backup_service.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/widgets/spinner.dart';

class CloudBackupScreen extends StatefulWidget {
  const CloudBackupScreen({super.key, this.autoBackup = false});

  final bool autoBackup;

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _backupHistory = [];

  @override
  void initState() {
    super.initState();
    _loadBackupHistory();

    // Auto backup if requested
    if (widget.autoBackup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performBackup();
      });
    }
  }

  Future<void> _loadBackupHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final history = await CloudBackupService.getBackupHistory();
      setState(() {
        _backupHistory = history;
      });
    } catch (e) {
      if (mounted) {
        showToast(context, 'Không thể tải lịch sử sao lưu: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _performBackup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await CloudBackupService.backupToCloud();

      if (mounted) {
        if (result.success) {
          showToast(context, result.message ?? 'Sao lưu thành công!');
          await _loadBackupHistory();
        } else {
          showToast(context, result.error ?? 'Sao lưu thất bại');
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _performRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khôi phục dữ liệu'),
        content: const Text(
          'Thao tác này sẽ ghi đè lên dữ liệu hiện tại. '
          'Bạn có chắc chắn muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await CloudBackupService.restoreFromCloud();

      if (mounted) {
        if (result.success) {
          showToast(context, result.message ?? 'Khôi phục thành công!');
        } else {
          showToast(context, result.error ?? 'Khôi phục thất bại');
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa sao lưu'),
        content: const Text(
          'Thao tác này sẽ xóa vĩnh viễn tất cả dữ liệu sao lưu trên đám mây. '
          'Bạn có chắc chắn muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await CloudBackupService.deleteCloudBackup();

      if (mounted) {
        if (result.success) {
          showToast(context, result.message ?? 'Xóa sao lưu thành công!');
          await _loadBackupHistory();
        } else {
          showToast(context, result.error ?? 'Xóa sao lưu thất bại');
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sao lưu đám mây'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(FluentIcons.arrow_left_24_regular),
        ),
      ),
      body: _isLoading
          ? const Center(child: Spinner())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(FluentIcons.cloud_sync_24_regular),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tài khoản: ${AuthService.userEmail ?? "Chưa đăng nhập"}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sao lưu playlist, bài hát yêu thích và cài đặt của bạn trên đám mây để truy cập từ nhiều thiết bị khác nhau.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 12),
                          _buildBackupInfoChips(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _performBackup,
                          icon: const Icon(
                            FluentIcons.cloud_arrow_up_24_regular,
                          ),
                          label: const Text('Sao lưu'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading || _backupHistory.isEmpty
                              ? null
                              : _performRestore,
                          icon: const Icon(
                            FluentIcons.cloud_arrow_down_24_regular,
                          ),
                          label: const Text('Khôi phục'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Backup History
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lịch sử sao lưu',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_backupHistory.isNotEmpty)
                        TextButton.icon(
                          onPressed: _isLoading ? null : _deleteBackup,
                          icon: const Icon(
                            FluentIcons.delete_24_regular,
                            size: 16,
                          ),
                          label: const Text('Xóa tất cả'),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: _backupHistory.isEmpty
                        ? Card(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    FluentIcons.cloud_off_24_regular,
                                    size: 48,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Chưa có bản sao lưu nào',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Nhấn "Sao lưu" để tạo bản sao lưu đầu tiên',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _backupHistory.length,
                            itemBuilder: (context, index) {
                              final backup = _backupHistory[index];
                              final createdAt = DateTime.tryParse(
                                backup['created_at'] ?? '',
                              );

                              return Card(
                                child: ListTile(
                                  leading: const Icon(
                                    FluentIcons.cloud_24_filled,
                                  ),
                                  title: Text(
                                    createdAt != null
                                        ? DateFormat(
                                            'dd/MM/yyyy HH:mm',
                                          ).format(createdAt)
                                        : 'Không xác định',
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Phiên bản: ${backup['app_version'] ?? 'N/A'}',
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            FluentIcons.music_note_2_24_regular,
                                            size: 12,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Playlist, Bài hát yêu thích & Nhạc offline',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: createdAt != null
                                      ? Text(
                                          _getTimeAgo(createdAt),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBackupInfoChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _buildInfoChip(FluentIcons.music_note_2_24_regular, 'Playlist'),
        _buildInfoChip(FluentIcons.heart_24_regular, 'Bài hát yêu thích'),
        _buildInfoChip(FluentIcons.arrow_download_24_regular, 'Nhạc offline'),
        _buildInfoChip(FluentIcons.settings_24_regular, 'Cài đặt'),
        _buildInfoChip(FluentIcons.history_24_regular, 'Lịch sử phát'),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
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

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} ngày trước';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }
}
