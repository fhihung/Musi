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
import 'package:musify/API/musify.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/screens/cloud_backup_screen.dart';
import 'package:musify/screens/login_page.dart';
import 'package:musify/screens/playlist_page.dart';
import 'package:musify/services/auth_service.dart';
import 'package:musify/services/gemini_ai_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/common_variables.dart';
import 'package:musify/utilities/utils.dart';
import 'package:musify/widgets/announcement_box.dart';
import 'package:musify/widgets/playlist_cube.dart';
import 'package:musify/widgets/section_header.dart';
import 'package:musify/widgets/song_bar.dart';
import 'package:musify/widgets/spinner.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ValueNotifier<int> _aiRefreshTrigger = ValueNotifier(0);

  @override
  void dispose() {
    _aiRefreshTrigger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playlistHeight = MediaQuery.sizeOf(context).height * 0.25 / 1.1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Musify.'),
        actions: [
          IconButton(
            onPressed: () {
              if (AuthService.isAuthenticated) {
                // If logged in, go to cloud backup screen and auto backup
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const CloudBackupScreen(autoBackup: true),
                  ),
                );
              } else {
                // If not logged in, show login sheet
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const LoginPage(),
                );
              }
            },
            icon: Icon(
              AuthService.isAuthenticated
                  ? FluentIcons.cloud_sync_24_filled
                  : FluentIcons.person_24_regular,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          children: [
            ValueListenableBuilder<String?>(
              valueListenable: announcementURL,
              builder: (_, _url, __) {
                if (_url == null) return const SizedBox.shrink();

                return AnnouncementBox(
                  message: context.l10n!.newAnnouncement,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  textColor: Theme.of(context).colorScheme.onSecondaryContainer,
                  url: _url,
                );
              },
            ),
            _buildSuggestedPlaylists(playlistHeight),
            _buildSuggestedPlaylists(playlistHeight, showOnlyLiked: true),
            _buildAISuggestedSongsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Padding(padding: EdgeInsets.all(35), child: Spinner()),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Center(
      child: Text(
        '${context.l10n!.error}!',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildSuggestedPlaylists(
    double playlistHeight, {
    bool showOnlyLiked = false,
  }) {
    final sectionTitle = showOnlyLiked
        ? context.l10n!.backToFavorites
        : context.l10n!.suggestedPlaylists;
    return FutureBuilder<List<dynamic>>(
      future: getPlaylists(
        playlistsNum: recommendedCubesNumber,
        onlyLiked: showOnlyLiked,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingWidget();
        } else if (snapshot.hasError) {
          logger.log(
            'Error in _buildSuggestedPlaylists',
            snapshot.error,
            snapshot.stackTrace,
          );
          return _buildErrorWidget(context);
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final playlists = snapshot.data ?? [];
        final itemsNumber = playlists.length.clamp(0, recommendedCubesNumber);
        final isLargeScreen = MediaQuery.of(context).size.width > 480;

        return Column(
          children: [
            SectionHeader(title: sectionTitle),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: playlistHeight),
              child: isLargeScreen
                  ? _buildHorizontalList(playlists, itemsNumber, playlistHeight)
                  : _buildCarouselView(playlists, itemsNumber, playlistHeight),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHorizontalList(
    List<dynamic> playlists,
    int itemCount,
    double height,
  ) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    PlaylistPage(playlistId: playlist['ytid']),
              ),
            ),
            child: PlaylistCube(playlist, size: height),
          ),
        );
      },
    );
  }

  Widget _buildCarouselView(
    List<dynamic> playlists,
    int itemCount,
    double height,
  ) {
    return CarouselView.weighted(
      flexWeights: const <int>[3, 2, 1],
      itemSnapping: true,
      onTap: (index) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PlaylistPage(playlistId: playlists[index]['ytid']),
        ),
      ),
      children: List.generate(itemCount, (index) {
        return PlaylistCube(playlists[index], size: height * 2);
      }),
    );
  }

  Widget _buildAISuggestedSongsSection() {
    return ValueListenableBuilder<int>(
      valueListenable: _aiRefreshTrigger,
      builder: (context, refreshCount, child) {
        return FutureBuilder<bool>(
          future: _checkIfGenresSelected(),
          builder: (context, genresSnapshot) {
            // Show AI suggestions only if genres are selected
            final hasGenres = genresSnapshot.hasData && genresSnapshot.data!;

            return FutureBuilder<List<dynamic>>(
              future: _getAISuggestedSongs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Column(
                    children: [
                      SectionHeader(
                        title: hasGenres
                            ? 'Suggested by AI ✨'
                            : context.l10n!.recommendedForYou,
                        actionButton: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      _buildLoadingWidget(),
                    ],
                  );
                }

                if (snapshot.hasError) {
                  logger.log(
                    'Error in _buildAISuggestedSongsSection',
                    snapshot.error,
                    snapshot.stackTrace,
                  );
                  return const SizedBox.shrink();
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox.shrink();
                }

                final data = snapshot.data!;
                final title = hasGenres
                    ? 'Suggested by AI ✨'
                    : context.l10n!.recommendedForYou;

                return Column(
                  children: [
                    SectionHeader(
                      title: title,
                      actionButton: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasGenres)
                            IconButton(
                              onPressed: () {
                                _aiRefreshTrigger.value++;
                              },
                              icon: Icon(
                                FluentIcons.arrow_clockwise_24_regular,
                                color: Theme.of(context).colorScheme.primary,
                                size: 24,
                              ),
                              tooltip: 'Làm mới gợi ý',
                            ),
                          IconButton(
                            onPressed: () async {
                              await Future.microtask(
                                () => setActivePlaylist({
                                  'title': hasGenres
                                      ? 'AI Suggestions'
                                      : 'Recommended',
                                  'list': data,
                                }),
                              );
                            },
                            icon: Icon(
                              FluentIcons.play_circle_24_filled,
                              color: Theme.of(context).colorScheme.primary,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: data.length,
                      padding: commonListViewBottmomPadding,
                      itemBuilder: (context, index) {
                        final borderRadius = getItemBorderRadius(
                          index,
                          data.length,
                        );
                        return RepaintBoundary(
                          key: ValueKey('song_${data[index]['ytid']}'),
                          child: SongBar(
                            data[index],
                            true,
                            borderRadius: borderRadius,
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<bool> _checkIfGenresSelected() async {
    try {
      final userBox = await Hive.openBox('user');
      final favoriteGenres = userBox.get('favoriteGenres') as List<dynamic>?;
      return favoriteGenres != null && favoriteGenres.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> _getAISuggestedSongs() async {
    try {
      // Get AI suggestions
      final suggestions = await GeminiAIService.getMusicSuggestions();

      if (suggestions.isEmpty) {
        logger.log(
          'AI returned empty suggestions, falling back to default',
          null,
          null,
        );
        return _getFallbackSongs();
      }

      // Search for each suggested song and get first result
      final songs = <dynamic>[];
      for (final suggestion in suggestions.take(10)) {
        try {
          final searchQuery = GeminiAIService.getSongSearchQuery(suggestion);
          final results = await fetchSongsList(searchQuery);

          if (results.isNotEmpty) {
            songs.add(results.first);
          }
        } catch (e) {
          logger.log('Error searching for song: $suggestion', e, null);
          continue;
        }
      }

      // If no songs found after AI search, fallback
      if (songs.isEmpty) {
        logger.log(
          'No songs found from AI suggestions, falling back to default',
          null,
          null,
        );
        return _getFallbackSongs();
      }

      return songs;
    } catch (e, stackTrace) {
      logger.log(
        'Error getting AI suggested songs, falling back to default',
        e,
        stackTrace,
      );
      return _getFallbackSongs();
    }
  }

  Future<List<dynamic>> _getFallbackSongs() async {
    try {
      // Use default recommended songs as fallback
      final recommendations = await getRecommendedSongs();
      return recommendations;
    } catch (e) {
      logger.log('Error getting fallback songs', e, null);
      return [];
    }
  }
}
