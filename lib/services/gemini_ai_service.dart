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
import 'package:http/http.dart' as http;
import 'package:musify/main.dart';
import 'package:musify/services/http_logger.dart';

class GeminiAIService {
  static const String _apiKey = 'AIzaSyCyfhA318E_HwhzFzuR0k2F9U9hPaY3NzM';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';

  // HTTP client with logging
  static final http.Client _httpClient = HttpLogger.createClient();

  /// Get AI-powered music suggestions based on user preferences
  static Future<List<String>> getMusicSuggestions() async {
    try {
      final userBox = await Hive.openBox('user');

      // Get user's favorite genres
      final favoriteGenres =
          userBox.get('favoriteGenres') as List<dynamic>? ?? [];

      // Get recently played songs
      final recentlyPlayed =
          userBox.get('recentlyPlayedSongs') as List<dynamic>? ?? [];

      // If no data, return empty
      if (favoriteGenres.isEmpty) {
        return [];
      }

      // Build prompt for AI
      final prompt = _buildPrompt(
        favoriteGenres.cast<String>(),
        recentlyPlayed,
      );

      // Call Gemini API with logged client
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.9,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Log full response for debugging
        logger.log('Gemini API Response', data, null);

        final text =
            data['candidates']?[0]?['content']?['parts']?[0]?['text']
                as String?;

        if (text != null && text.isNotEmpty) {
          final suggestions = _parseSuggestions(text);

          if (suggestions.isEmpty) {
            logger.log(
              'Gemini API returned text but no valid suggestions found',
              text,
              null,
            );
          } else {
            logger.log(
              'Gemini AI found ${suggestions.length} suggestions',
              suggestions,
              null,
            );
          }

          return suggestions;
        } else {
          logger.log('Gemini API returned empty text', data, null);
        }
      } else {
        logger.log(
          'Gemini API error: ${response.statusCode}',
          response.body,
          null,
        );
      }
    } catch (e, stackTrace) {
      logger.log('Error getting AI suggestions', e, stackTrace);
    }

    return [];
  }

  /// Build prompt for Gemini AI
  static String _buildPrompt(
    List<String> genres,
    List<dynamic> recentlyPlayed,
  ) {
    final genresText = genres.join(', ');

    String recentSongsText = '';
    if (recentlyPlayed.isNotEmpty) {
      final songs = recentlyPlayed
          .take(10)
          .map((song) {
            if (song is Map) {
              final title = song['title'] ?? '';
              final artist = song['artist'] ?? '';
              return '$title - $artist';
            }
            return '';
          })
          .where((s) => s.isNotEmpty)
          .join('\n');

      if (songs.isNotEmpty) {
        recentSongsText = '\n\nRecently played songs:\n$songs';
      }
    }

    return '''
You are a music recommendation expert. Based on the user's favorite music genres and listening history, suggest 15 popular and trending songs that they might enjoy.

User's favorite genres: $genresText$recentSongsText

Please provide EXACTLY 10 song suggestions in the following format (one per line):
Artist Name - Song Title

Requirements:
1. Each line must follow the format: "Artist Name - Song Title"
2. Suggest popular, well-known songs that match the user's taste
3. Mix different artists and songs from the favorite genres
4. Include both classic hits and recent trending songs
5. Make sure all songs are real and can be found on YouTube/streaming platforms
6. Do NOT include any explanations, just the list
7. EXACTLY 10 songs, no more, no less

Example format:
The Weeknd - Blinding Lights
Dua Lipa - Levitating
Ed Sheeran - Shape of You
''';
  }

  /// Parse AI response to extract song suggestions
  static List<String> _parseSuggestions(String text) {
    final lines = text.split('\n').where((line) {
      final trimmed = line.trim();
      // Must contain " - " and not be a header or explanation
      return trimmed.contains(' - ') &&
          !trimmed.toLowerCase().startsWith('artist') &&
          !trimmed.toLowerCase().startsWith('example') &&
          !trimmed.toLowerCase().startsWith('song') &&
          !trimmed.startsWith('#') &&
          !trimmed.startsWith('*');
    }).toList();

    // Return up to 15 suggestions
    return lines.take(15).map((line) => line.trim()).toList();
  }

  /// Search for a song on YouTube and return query
  static String getSongSearchQuery(String suggestion) {
    // The suggestion is already in "Artist - Song" format
    // Just clean it up and return as search query
    return suggestion.trim();
  }
}
