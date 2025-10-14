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

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// HTTP Client with logging interceptor
class LoggedHttpClient extends http.BaseClient {
  LoggedHttpClient(this._inner);

  final http.Client _inner;
  static int _requestCounter = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final requestId = ++_requestCounter;
    final startTime = DateTime.now();

    // Log request only in debug mode
    if (kDebugMode) {
      _logRequest(requestId, request);
    }

    try {
      final response = await _inner.send(request);
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      // Log response only in debug mode
      if (kDebugMode) {
        // Read the response body for logging
        final responseBody = await response.stream.bytesToString();
        await _logResponseWithBody(
          requestId,
          request,
          response,
          duration,
          responseBody,
        );

        // Return a new StreamedResponse with fresh stream
        final bodyBytes = utf8.encode(responseBody);
        return http.StreamedResponse(
          http.ByteStream.fromBytes(bodyBytes),
          response.statusCode,
          headers: response.headers,
          reasonPhrase: response.reasonPhrase,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
          request: request,
        );
      }

      return response;
    } catch (e) {
      if (kDebugMode) {
        _logError(requestId, request, e);
      }
      rethrow;
    }
  }

  void _logRequest(int requestId, http.BaseRequest request) {
    final buffer = StringBuffer();
    buffer.writeln('┌─────────────────────────────────────────────────────');
    buffer.writeln('│ 🌐 HTTP REQUEST #$requestId');
    buffer.writeln('├─────────────────────────────────────────────────────');
    buffer.writeln('│ Method: ${request.method}');
    buffer.writeln('│ URL: ${request.url}');

    if (request.headers.isNotEmpty) {
      buffer.writeln('│ Headers:');
      request.headers.forEach((key, value) {
        // Hide sensitive headers
        if (_isSensitiveHeader(key)) {
          buffer.writeln('│   $key: ***HIDDEN***');
        } else {
          buffer.writeln('│   $key: $value');
        }
      });
    }

    if (request is http.Request && request.body.isNotEmpty) {
      buffer.writeln('│ Body:');
      try {
        final json = jsonDecode(request.body);
        final prettyJson = const JsonEncoder.withIndent('  ').convert(json);
        prettyJson.split('\n').forEach((line) {
          buffer.writeln('│   $line');
        });
      } catch (e) {
        // If not JSON, just print the body
        buffer.writeln('│   ${request.body}');
      }
    }

    buffer.writeln('└─────────────────────────────────────────────────────');
    debugPrint(buffer.toString());
  }

  Future<void> _logResponseWithBody(
    int requestId,
    http.BaseRequest request,
    http.StreamedResponse response,
    Duration duration,
    String responseBody,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln('┌─────────────────────────────────────────────────────');
    buffer.writeln(
      '│ ${_getStatusEmoji(response.statusCode)} HTTP RESPONSE #$requestId',
    );
    buffer.writeln('├─────────────────────────────────────────────────────');
    buffer.writeln('│ Status: ${response.statusCode} ${response.reasonPhrase}');
    buffer.writeln('│ Duration: ${duration.inMilliseconds}ms');
    buffer.writeln('│ URL: ${request.url}');

    if (response.headers.isNotEmpty) {
      buffer.writeln('│ Headers:');
      response.headers.forEach((key, value) {
        if (_isSensitiveHeader(key)) {
          buffer.writeln('│   $key: ***HIDDEN***');
        } else {
          buffer.writeln('│   $key: $value');
        }
      });
    }

    // Log response body
    if (responseBody.isNotEmpty) {
      buffer.writeln('│ Body:');
      try {
        final json = jsonDecode(responseBody);
        final prettyJson = const JsonEncoder.withIndent('  ').convert(json);
        final lines = prettyJson.split('\n');
        // Limit to first 50 lines to avoid too much logging
        final limitedLines = lines.take(50);
        for (final line in limitedLines) {
          buffer.writeln('│   $line');
        }
        if (lines.length > 50) {
          buffer.writeln('│   ... (${lines.length - 50} more lines)');
        }
      } catch (e) {
        // If not JSON, just print first 500 chars
        final preview = responseBody.length > 500
            ? '${responseBody.substring(0, 500)}...'
            : responseBody;
        preview.split('\n').forEach((line) {
          buffer.writeln('│   $line');
        });
      }
    }

    buffer.writeln('└─────────────────────────────────────────────────────');
    debugPrint(buffer.toString());
  }

  void _logError(int requestId, http.BaseRequest request, dynamic error) {
    final buffer = StringBuffer();
    buffer.writeln('┌─────────────────────────────────────────────────────');
    buffer.writeln('│ ❌ HTTP ERROR #$requestId');
    buffer.writeln('├─────────────────────────────────────────────────────');
    buffer.writeln('│ Method: ${request.method}');
    buffer.writeln('│ URL: ${request.url}');
    buffer.writeln('│ Error: $error');
    buffer.writeln('└─────────────────────────────────────────────────────');
    debugPrint(buffer.toString());
  }

  bool _isSensitiveHeader(String key) {
    final lowerKey = key.toLowerCase();
    return lowerKey.contains('authorization') ||
        lowerKey.contains('token') ||
        lowerKey.contains('api-key') ||
        lowerKey.contains('apikey') ||
        lowerKey.contains('password') ||
        lowerKey.contains('secret');
  }

  String _getStatusEmoji(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return '✅'; // Success
    } else if (statusCode >= 300 && statusCode < 400) {
      return '↩️'; // Redirect
    } else if (statusCode >= 400 && statusCode < 500) {
      return '⚠️'; // Client error
    } else if (statusCode >= 500) {
      return '🔥'; // Server error
    }
    return '❓'; // Unknown
  }
}

/// Factory to create logged HTTP client
class HttpLogger {
  static http.Client createClient() {
    if (kDebugMode) {
      return LoggedHttpClient(http.Client());
    }
    return http.Client();
  }
}
