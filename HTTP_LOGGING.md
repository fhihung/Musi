# HTTP Logging & API Interceptor 🔍

## 📋 Tổng quan

Hệ thống logging tự động cho tất cả API calls trong app, chỉ hoạt động khi debug mode.

## 🎯 Tính năng

### ✅ HTTP Logger
- Log tất cả HTTP requests/responses
- Beautiful formatted console output
- Chỉ hoạt động trong debug mode
- Hide sensitive headers (Authorization, API keys, tokens)
- Pretty print JSON
- Request/Response duration tracking
- Error logging
- Request counter

### ✅ PocketBase Logger  
- Log tất cả PocketBase operations
- CRUD operations tracking
- Filter & sort parameters
- Duration measurement
- Sanitize sensitive data
- Operation counter

## 📦 Files

### 1. `lib/services/http_logger.dart`
HTTP client interceptor với đầy đủ logging:

```dart
class LoggedHttpClient extends http.BaseClient {
  // Intercepts all HTTP requests
  // Logs request & response
  // Only in debug mode
}
```

### 2. `lib/services/pocketbase_logger.dart`
Logger cho PocketBase operations:

```dart
class PocketBaseLogger {
  static void logOperation(...);
  static void logResult(...);
}
```

## 🚀 Cách sử dụng

### HTTP Logging

**Tạo client:**
```dart
import 'package:musify/services/http_logger.dart';

// Automatically uses logged client in debug
final client = HttpLogger.createClient();

// In release mode, returns normal http.Client()
// In debug mode, returns LoggedHttpClient()
```

**Sử dụng trong service:**
```dart
class GeminiAIService {
  static final http.Client _httpClient = HttpLogger.createClient();

  static Future<void> callAPI() async {
    final response = await _httpClient.post(
      Uri.parse('https://api.example.com'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'key': 'value'}),
    );
  }
}
```

### PocketBase Logging

**Log operation:**
```dart
import 'package:musify/services/pocketbase_logger.dart';

PocketBaseLogger.logOperation(
  'CREATE',
  'users',
  data: {
    'email': 'user@example.com',
    'password': 'secret123', // Will be hidden
  },
);
```

**Log result:**
```dart
PocketBaseLogger.logResult(
  'CREATE users',
  true, // success
  duration: Duration(milliseconds: 250),
);
```

## 📊 Console Output Examples

### HTTP Request Log
```
┌─────────────────────────────────────────────────────
│ 🌐 HTTP REQUEST #1
├─────────────────────────────────────────────────────
│ Method: POST
│ URL: https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent
│ Headers:
│   Content-Type: application/json
│ Body:
│   {
│     "contents": [
│       {
│         "parts": [
│           {
│             "text": "Suggest music..."
│           }
│         ]
│       }
│     ]
│   }
└─────────────────────────────────────────────────────
```

### HTTP Response Log
```
┌─────────────────────────────────────────────────────
│ ✅ HTTP RESPONSE #1
├─────────────────────────────────────────────────────
│ Status: 200 OK
│ Duration: 2345ms
│ URL: https://generativelanguage.googleapis.com/...
│ Headers:
│   content-type: application/json
│ Body:
│   {
│     "candidates": [
│       {
│         "content": {
│           "parts": [
│             {
│               "text": "The Weeknd - Blinding Lights..."
│             }
│           ]
│         }
│       }
│     ]
│   }
└─────────────────────────────────────────────────────
```

### PocketBase Operation Log
```
┌─────────────────────────────────────────────────────
│ 🗄️  POCKETBASE #1
├─────────────────────────────────────────────────────
│ Operation: CREATE
│ Collection: users
│ Data:
│   {
│     "email": "user@example.com",
│     "password": "***HIDDEN***",
│     "name": "John Doe"
│   }
└─────────────────────────────────────────────────────
```

### PocketBase Result Log
```
┌─────────────────────────────────────────────────────
│ ✅ POCKETBASE RESULT
├─────────────────────────────────────────────────────
│ Operation: CREATE users
│ Success: true
│ Duration: 156ms
└─────────────────────────────────────────────────────
```

## 🎨 Status Emojis

| Status | Emoji | Meaning |
|--------|-------|---------|
| 2xx | ✅ | Success |
| 3xx | ↩️ | Redirect |
| 4xx | ⚠️ | Client Error |
| 5xx | 🔥 | Server Error |
| Error | ❌ | Request Failed |

## 🔒 Security Features

### Sensitive Data Hiding

**HTTP Headers:**
- `authorization`
- `token`
- `api-key`
- `apikey`
- `password`
- `secret`

**PocketBase Fields:**
- `password`
- `token`
- `secret`
- `apikey`
- `api_key`

Sensitive values are replaced with `***HIDDEN***`

### Example:
```dart
// Request
{
  "email": "user@example.com",
  "password": "mypassword123"
}

// Logged as
{
  "email": "user@example.com",
  "password": "***HIDDEN***"
}
```

## 📈 Performance Features

### Smart Truncation
- JSON responses limited to 50 lines
- Long responses show preview + line count
- Prevents console overflow

### Request Counter
- Each request numbered sequentially
- Easy to match request/response pairs
- Track total API calls

### Duration Tracking
- Measure request time
- Identify slow endpoints
- Performance debugging

## 🎯 Services Using Logging

### ✅ Gemini AI Service
```dart
// lib/services/gemini_ai_service.dart
static final http.Client _httpClient = HttpLogger.createClient();
```

Logs:
- Gemini API requests
- AI prompts
- Generated suggestions
- Response parsing

### ✅ Auth Service
```dart
// lib/services/auth_service.dart
PocketBaseLogger.logOperation('AUTH', 'users', ...);
PocketBaseLogger.logResult('AUTH users', true, ...);
```

Logs:
- User registration
- Login attempts
- Password changes
- Profile updates

### ✅ Cloud Backup Service
```dart
// lib/services/cloud_backup_service.dart
PocketBaseLogger.logOperation('BACKUP', ...);
```

Logs:
- Backup creation
- Data restore
- Backup deletion
- Sync operations

## 🛠️ Debugging Workflow

### 1. Enable Debug Mode
```bash
flutter run --debug
```

### 2. Perform Actions
- Login/Register
- Get AI suggestions
- Backup data
- Any API calls

### 3. Check Console
All API calls will be logged automatically:
```
🌐 HTTP REQUEST #1
✅ HTTP RESPONSE #1
🗄️ POCKETBASE #1
✅ POCKETBASE RESULT
```

### 4. Debug Issues
- Check request parameters
- Verify response data
- Measure performance
- Identify errors

## 📊 Log Analysis

### Request Tracking
```
HTTP REQUEST #1 → Login attempt
HTTP REQUEST #2 → Get genres
HTTP REQUEST #3 → AI suggestions
HTTP REQUEST #4 → Song search #1
HTTP REQUEST #5 → Song search #2
...
```

### Performance Monitoring
```
✅ HTTP RESPONSE #1 - Duration: 150ms (fast)
✅ HTTP RESPONSE #3 - Duration: 2500ms (slow - AI call)
✅ HTTP RESPONSE #4 - Duration: 300ms (normal)
```

### Error Detection
```
❌ HTTP ERROR #10
│ URL: https://api.example.com/endpoint
│ Error: SocketException: Connection timeout
```

## 🔧 Customization

### Change Log Level
Edit `http_logger.dart`:
```dart
// Always log (even in release)
if (true) { // was: if (kDebugMode)
  _logRequest(requestId, request);
}
```

### Adjust Truncation
```dart
// Show more lines
final limitedLines = lines.take(100); // was: 50
```

### Add More Sensitive Fields
```dart
bool _isSensitiveField(String key) {
  final lowerKey = key.toLowerCase();
  return lowerKey.contains('password') ||
         lowerKey.contains('token') ||
         lowerKey.contains('credit_card') || // NEW
         lowerKey.contains('ssn'); // NEW
}
```

## 📝 Best Practices

1. **Always use LoggedHttpClient in debug**
   ```dart
   final client = HttpLogger.createClient();
   ```

2. **Log PocketBase operations**
   ```dart
   PocketBaseLogger.logOperation(...);
   await someOperation();
   PocketBaseLogger.logResult(...);
   ```

3. **Include duration for performance tracking**
   ```dart
   final startTime = DateTime.now();
   await operation();
   final duration = DateTime.now().difference(startTime);
   PocketBaseLogger.logResult(..., duration: duration);
   ```

4. **Don't log in production**
   - Logs automatically disabled in release mode
   - Uses `kDebugMode` check

## 🎉 Benefits

✨ **Debugging:**
- See all API calls in real-time
- Identify network issues quickly
- Debug auth problems

⚡ **Performance:**
- Measure API response times
- Find slow endpoints
- Optimize requests

🔒 **Security:**
- Verify sensitive data is hidden
- Check auth headers
- Monitor API keys usage

📊 **Analytics:**
- Track API usage
- Count requests
- Identify patterns

## 🚨 Common Issues

### Logs not showing?
- Check you're in debug mode: `flutter run --debug`
- Verify console output is visible
- Check kDebugMode flag

### Too much logging?
- Increase truncation limits
- Filter by request ID
- Focus on specific operations

### Sensitive data visible?
- Add field to sensitive list
- Check field naming
- Update sanitize function

## 📚 References

- HTTP Package: https://pub.dev/packages/http
- PocketBase Dart SDK: https://github.com/pocketbase/dart-sdk
- Flutter Debugging: https://docs.flutter.dev/testing/debugging

