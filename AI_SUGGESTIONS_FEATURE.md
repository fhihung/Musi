# Tính năng AI Music Suggestions ✨

## 🎯 Tổng quan

Tính năng mới sử dụng Gemini AI để gợi ý nhạc dựa trên sở thích và lịch sử nghe nhạc của người dùng.

## 📦 Files đã tạo/cập nhật

### Files mới:
1. **`lib/screens/genre_selection_page.dart`**
   - Màn hình chọn thể loại nhạc yêu thích
   - 30+ thể loại phổ biến
   - Progress indicator
   - Validation tối thiểu 3 thể loại

2. **`lib/services/gemini_ai_service.dart`**
   - Tích hợp Gemini AI API
   - Generate music suggestions
   - Parse AI responses
   - Error handling

### Files đã cập nhật:
1. **`lib/screens/login_page.dart`**
   - Check genres sau khi đăng nhập
   - Redirect đến genre selection nếu chưa chọn

2. **`lib/screens/home_page.dart`**
   - Thay "Recommend for you" → "Suggested by AI ✨"
   - Gọi Gemini API
   - Search và hiển thị bài hát AI gợi ý

3. **`lib/services/cloud_backup_service.dart`**
   - Backup/restore favorite genres
   - Sync với cloud

## 🚀 Workflow

### 1. Đăng ký/Đăng nhập lần đầu
```
User đăng ký
    ↓
Tự động mở LoginPage (email filled)
    ↓
Đăng nhập thành công
    ↓
Check: đã chọn genres chưa?
    ↓ (Chưa)
Mở GenreSelectionPage
    ↓
User chọn ít nhất 3 thể loại
    ↓
Lưu vào Hive + Backup lên Cloud
    ↓
Vào HomePage
```

### 2. AI Suggestions Flow
```
HomePage load
    ↓
Check: có genres đã chọn?
    ↓ (Có)
Gọi Gemini AI API
    ↓
AI analyze: genres + recently played
    ↓
AI suggest 15 bài hát
    ↓
Search từng bài trên YouTube
    ↓
Hiển thị 10 bài đầu tiên
```

## 🎨 Genres Available

```dart
Pop, Rock, Hip Hop, R&B, Jazz, Classical, 
Electronic, EDM, Country, Blues, Reggae, 
Metal, Indie, Folk, Soul, Funk, Disco, 
Punk, K-Pop, J-Pop, Latin, Reggaeton, 
Trap, Lo-fi, House, Techno, Trance, 
Dubstep, Ambient, Acoustic
```

## 🤖 Gemini AI Configuration

```dart
API Key: AIzaSyCyfhA318E_HwhzFzuR0k2F9U9hPaY3NzM
Model: gemini-2.0-flash-exp
Temperature: 0.9
TopK: 40
TopP: 0.95
Max Tokens: 1024
```

## 📊 AI Prompt Structure

```
You are a music recommendation expert. 

User's favorite genres: [Pop, Rock, Electronic]

Recently played songs:
The Weeknd - Blinding Lights
Dua Lipa - Levitating
...

Please provide EXACTLY 15 song suggestions in format:
Artist Name - Song Title
```

## 🔄 Data Backup Structure

```json
{
  "user": {
    "favoriteGenres": ["Pop", "Rock", "Electronic"],
    "customPlaylists": [...],
    "likedSongs": [...],
    "recentlyPlayedSongs": [...]
  }
}
```

## 🎯 Features

### ✅ Genre Selection Page
- ✨ Modern Material Design 3 UI
- 📊 Progress indicator (minimum 3 genres)
- 💾 Auto-save to Hive
- ☁️ Auto-backup to cloud
- 🎨 FilterChip với selected state

### ✅ AI Suggestions
- 🤖 Powered by Gemini AI
- 🎵 Personalized based on genres + listening history
- 🔍 Auto-search trên YouTube
- ⚡ Loading states với animations
- 🎯 Top 10 suggestions hiển thị

### ✅ Cloud Sync
- ☁️ Genres được backup lên PocketBase
- 🔄 Auto-restore khi đăng nhập thiết bị mới
- 💾 Persist trong Hive

## 🛠️ Cách sử dụng

### 1. First Time Setup
```dart
1. Đăng ký tài khoản mới
2. Đăng nhập (email auto-filled)
3. Chọn ít nhất 3 thể loại yêu thích
4. Nhấn "Tiếp tục"
5. Genres được backup tự động
```

### 2. Viewing AI Suggestions
```dart
1. Mở HomePage
2. Scroll xuống section "Suggested by AI ✨"
3. AI suggestions sẽ load tự động
4. Nhấn play icon để phát tất cả
5. Hoặc chọn từng bài để phát
```

### 3. Updating Genres
```dart
1. Vào Settings
2. Tìm "Music Preferences" 
3. Update genres
4. Auto-backup lại
```

## 🔧 Technical Details

### Gemini AI Integration
- **Endpoint**: `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent`
- **Method**: POST
- **Headers**: Content-Type: application/json
- **Authentication**: API Key in URL params

### Response Parsing
```dart
// Extract song suggestions from AI response
List<String> _parseSuggestions(String text) {
  // Filter lines containing " - "
  // Remove headers and explanations
  // Take up to 15 suggestions
}
```

### Song Search
```dart
// For each AI suggestion
for (final suggestion in suggestions) {
  final results = await fetchSongsList(suggestion);
  if (results.isNotEmpty) {
    songs.add(results.first);
  }
}
```

## 🎨 UI Components

### Genre Selection
- FilterChip với selected state
- Primary color cho selected
- Bold font weight khi selected
- Progress bar
- Bottom action button

### AI Suggestions Section
- Section header với ✨ emoji
- Play all button
- Song list với RepaintBoundary
- Loading indicator khi gọi API
- Empty state nếu chưa chọn genres

## 📈 Performance

- **AI Call**: 2-5 seconds (depends on network)
- **Song Search**: 1-2 seconds per song
- **Total Load Time**: 15-25 seconds for 10 songs
- **Cache**: Không cache, mỗi lần load sẽ gọi API mới

## 🐛 Error Handling

1. **Gemini API Error**:
   - Log error
   - Return empty list
   - Section không hiển thị

2. **Song Search Error**:
   - Skip bài đó
   - Continue với bài tiếp theo
   - Log error

3. **No Genres Selected**:
   - Section không hiển thị
   - Chỉ show khi user đã chọn genres

## 🔐 Security

- ⚠️ API Key hiện tại là hardcoded
- 🔒 Nên move vào environment variables
- 🔐 Hoặc setup backend proxy để ẩn key

## 🚀 Future Improvements

- [ ] Cache AI suggestions (1 hour)
- [ ] Refresh button để get suggestions mới
- [ ] More genres (100+)
- [ ] Genre icons
- [ ] Mood-based suggestions
- [ ] Time-of-day recommendations
- [ ] Share favorite genres
- [ ] Export/Import genres
- [ ] Genre analytics
- [ ] Multi-language genre names

## 📝 Notes

- Gemini API free tier có rate limit
- Cần internet connection để gọi AI
- AI suggestions có thể không 100% accurate
- Một số bài AI gợi ý có thể không có trên YouTube

## 🎉 Demo Flow

```
1. Open app → Login
2. See "Choose favorite genres" screen
3. Select: Pop, Rock, Electronic
4. Tap "Continue"
5. Go to HomePage
6. Scroll to "Suggested by AI ✨"
7. See loading indicator
8. Wait 15-20 seconds
9. See 10 AI-suggested songs
10. Tap play button
11. Enjoy personalized music! 🎵
```

