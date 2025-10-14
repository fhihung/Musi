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

/// Logger for PocketBase operations
class PocketBaseLogger {
  static int _operationCounter = 0;

  /// Log a PocketBase operation
  static void logOperation(
    String operation,
    String collection, {
    Map<String, dynamic>? data,
    String? filter,
    String? sort,
    String? recordId,
  }) {
    if (!kDebugMode) return;

    final operationId = ++_operationCounter;
    final buffer = StringBuffer();

    buffer.writeln('┌─────────────────────────────────────────────────────');
    buffer.writeln('│ 🗄️  POCKETBASE #$operationId');
    buffer.writeln('├─────────────────────────────────────────────────────');
    buffer.writeln('│ Operation: $operation');
    buffer.writeln('│ Collection: $collection');

    if (recordId != null) {
      buffer.writeln('│ Record ID: $recordId');
    }

    if (filter != null) {
      buffer.writeln('│ Filter: $filter');
    }

    if (sort != null) {
      buffer.writeln('│ Sort: $sort');
    }

    if (data != null) {
      buffer.writeln('│ Data:');
      try {
        // Hide sensitive fields
        final sanitizedData = _sanitizeData(data);
        final prettyJson = const JsonEncoder.withIndent(
          '  ',
        ).convert(sanitizedData);
        prettyJson.split('\n').forEach((line) {
          buffer.writeln('│   $line');
        });
      } catch (e) {
        buffer.writeln('│   ${data.toString()}');
      }
    }

    buffer.writeln('└─────────────────────────────────────────────────────');
    debugPrint(buffer.toString());
  }

  /// Log a PocketBase result
  static void logResult(
    String operation,
    bool success, {
    dynamic result,
    dynamic error,
    Duration? duration,
  }) {
    if (!kDebugMode) return;

    final buffer = StringBuffer();

    buffer.writeln('┌─────────────────────────────────────────────────────');
    buffer.writeln('│ ${success ? '✅' : '❌'} POCKETBASE RESULT');
    buffer.writeln('├─────────────────────────────────────────────────────');
    buffer.writeln('│ Operation: $operation');
    buffer.writeln('│ Success: $success');

    if (duration != null) {
      buffer.writeln('│ Duration: ${duration.inMilliseconds}ms');
    }

    if (error != null) {
      buffer.writeln('│ Error: $error');
    }

    if (result != null && success) {
      buffer.writeln('│ Result:');
      try {
        if (result is List) {
          buffer.writeln('│   Count: ${result.length}');
          if (result.isNotEmpty) {
            buffer.writeln('│   First item: ${result.first}');
          }
        } else if (result is Map) {
          final sanitizedResult = _sanitizeData(result);
          final prettyJson = const JsonEncoder.withIndent(
            '  ',
          ).convert(sanitizedResult);
          final lines = prettyJson.split('\n');
          final limitedLines = lines.take(20);
          for (final line in limitedLines) {
            buffer.writeln('│   $line');
          }
          if (lines.length > 20) {
            buffer.writeln('│   ... (${lines.length - 20} more lines)');
          }
        } else {
          buffer.writeln('│   $result');
        }
      } catch (e) {
        buffer.writeln('│   ${result.toString()}');
      }
    }

    buffer.writeln('└─────────────────────────────────────────────────────');
    debugPrint(buffer.toString());
  }

  /// Sanitize sensitive data
  static Map<String, dynamic> _sanitizeData(dynamic data) {
    if (data is! Map) return {};

    final sanitized = <String, dynamic>{};

    data.forEach((key, value) {
      if (_isSensitiveField(key.toString())) {
        sanitized[key.toString()] = '***HIDDEN***';
      } else if (value is Map) {
        sanitized[key.toString()] = _sanitizeData(value);
      } else if (value is List) {
        sanitized[key.toString()] = value.map((item) {
          if (item is Map) {
            return _sanitizeData(item);
          }
          return item;
        }).toList();
      } else {
        sanitized[key.toString()] = value;
      }
    });

    return sanitized;
  }

  static bool _isSensitiveField(String key) {
    final lowerKey = key.toLowerCase();
    return lowerKey.contains('password') ||
        lowerKey.contains('token') ||
        lowerKey.contains('secret') ||
        lowerKey.contains('apikey') ||
        lowerKey.contains('api_key');
  }
}
