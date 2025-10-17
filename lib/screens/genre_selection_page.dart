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
import 'package:hive/hive.dart';
import 'package:musify/services/cloud_backup_service.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/widgets/spinner.dart';

class GenreSelectionPage extends StatefulWidget {
  const GenreSelectionPage({super.key});

  @override
  State<GenreSelectionPage> createState() => _GenreSelectionPageState();
}

class _GenreSelectionPageState extends State<GenreSelectionPage> {
  final List<String> _allGenres = [
    'Pop',
    'Rock',
    'Hip Hop',
    'R&B',
    'Jazz',
    'Classical',
    'Electronic',
    'EDM',
    'Country',
    'Blues',
    'Reggae',
    'Metal',
    'Indie',
    'Folk',
    'Soul',
    'Funk',
    'Disco',
    'Punk',
    'K-Pop',
    'J-Pop',
    'Latin',
    'Reggaeton',
    'Trap',
    'Lo-fi',
    'House',
    'Techno',
    'Trance',
    'Dubstep',
    'Ambient',
    'Acoustic',
  ];

  final Set<String> _selectedGenres = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedGenres();
  }

  Future<void> _loadSavedGenres() async {
    try {
      final userBox = await Hive.openBox('user');
      final savedGenres = userBox.get('favoriteGenres') as List<dynamic>?;
      if (savedGenres != null) {
        setState(() {
          _selectedGenres.addAll(savedGenres.cast<String>());
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _saveAndContinue() async {
    if (_selectedGenres.isEmpty) {
      showToast(context, 'Vui lòng chọn ít nhất một thể loại');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Save to Hive
      final userBox = await Hive.openBox('user');
      await userBox.put('favoriteGenres', _selectedGenres.toList());

      // Backup to cloud
      final backupResult = await CloudBackupService.backupToCloud();
      if (!backupResult.success) {
        // Log error but don't block the user
        print('Failed to backup to cloud: ${backupResult.error}');
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, 'Lỗi khi lưu thể loại: $e');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn thể loại yêu thích'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn ít nhất 3 thể loại bạn yêu thích',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Chúng tôi sẽ sử dụng thông tin này để gợi ý nhạc phù hợp với bạn',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _selectedGenres.length / 3,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 8),
                Text(
                  'Đã chọn: ${_selectedGenres.length}/3+',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allGenres.map((genre) {
                    final isSelected = _selectedGenres.contains(genre);
                    return FilterChip(
                      label: Text(genre),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedGenres.add(genre);
                          } else {
                            _selectedGenres.remove(genre);
                          }
                        });
                      },
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      checkmarkColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: FilledButton(
                onPressed: _isLoading ? null : _saveAndContinue,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(height: 24, width: 24, child: Spinner())
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Tiếp tục'),
                          const SizedBox(width: 8),
                          Icon(
                            FluentIcons.arrow_right_24_filled,
                            size: 20,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
