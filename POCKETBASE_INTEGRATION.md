# Tích hợp PocketBase cho Musify

Hướng dẫn này mô tả cách sử dụng tính năng đồng bộ đám mây với PocketBase trong ứng dụng Musify.

## 🎯 Tổng quan

Tích hợp PocketBase cho phép:
- ✅ Đăng ký và đăng nhập tài khoản người dùng
- ✅ Sao lưu dữ liệu lên đám mây (playlists, bài hát yêu thích, cài đặt)
- ✅ Khôi phục dữ liệu từ đám mây
- ✅ Đồng bộ dữ liệu giữa nhiều thiết bị
- ✅ Quản lý lịch sử sao lưu

## 📦 Packages đã thêm

```yaml
pocketbase: ^0.19.0
shared_preferences: ^2.3.5
package_info_plus: ^8.1.3
```

## 🗂️ Cấu trúc File

### Services đã tạo:

1. **`lib/services/auth_service.dart`**
   - Quản lý authentication với PocketBase
   - Đăng ký, đăng nhập, đăng xuất
   - Lưu trữ session tự động
   - Xử lý errors user-friendly

2. **`lib/services/cloud_backup_service.dart`**
   - Sao lưu dữ liệu lên PocketBase
   - Khôi phục dữ liệu từ cloud
   - Quản lý lịch sử backup
   - Xóa backup

### Screens đã tạo:

1. **`lib/screens/login_page.dart`**
   - Trang đăng nhập dạng bottom sheet
   - Validation form
   - Loading states
   - Error handling

2. **`lib/screens/register_page.dart`**
   - Trang đăng ký dạng bottom sheet
   - Validation: email, password, confirm password
   - Tự động đăng nhập sau khi đăng ký thành công

3. **`lib/screens/cloud_backup_screen.dart`**
   - Quản lý backup/restore
   - Hiển thị lịch sử backup
   - Confirmation dialogs
   - Status indicators

## 🔧 Cấu hình PocketBase

### 1. Cấu hình URL Server

Trong `lib/services/auth_service.dart`, cập nhật URL PocketBase server:

```dart
static final PocketBase _pb = PocketBase('http://127.0.0.1:8090');
```

**Lưu ý:** 
- Để test local: sử dụng `http://127.0.0.1:8090`
- Để production: thay bằng URL server thật (ví dụ: `https://your-domain.com`)

### 2. Collections Schema

#### Collection: `users` (auth)
- Type: Auth Collection
- Fields: email, password, name, avatar
- Rules:
  - listRule: `id = @request.auth.id`
  - viewRule: `id = @request.auth.id`
  - createRule: `""`
  - updateRule: `id = @request.auth.id`
  - deleteRule: `id = @request.auth.id`

#### Collection: `user_backups` (base)
- Type: Base Collection
- Fields:
  - `user_id` (text): ID người dùng
  - `backup_data` (json): Dữ liệu backup
  - `backup_version` (text): Phiên bản backup
  - `app_version` (text): Phiên bản app
  - `created_at` (date): Thời gian tạo
- Rules:
  - listRule: `@request.auth.id != "" && user_id = @request.auth.id`
  - viewRule: `@request.auth.id != "" && user_id = @request.auth.id`
  - createRule: `""`
  - updateRule: `@request.auth.id != "" && user_id = @request.auth.id`
  - deleteRule: `@request.auth.id != "" && user_id = @request.auth.id`

## 🚀 Cách sử dụng

### 1. Khởi động PocketBase Server

```bash
./pocketbase serve
```

Server sẽ chạy tại:
- REST API: http://127.0.0.1:8090/api/
- Dashboard: http://127.0.0.1:8090/_/

### 2. Tích hợp vào Settings

Trong `lib/screens/settings_page.dart`, thêm các option:

```dart
// Hiển thị nút Login nếu chưa đăng nhập
if (!AuthService.isAuthenticated) {
  CustomBar(
    'Đăng nhập',
    FluentIcons.person_24_regular,
    onTap: () {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const LoginPage(),
      );
    },
  ),
}

// Hiển thị thông tin user và các tùy chọn nếu đã đăng nhập
if (AuthService.isAuthenticated) {
  CustomBar(
    'Tài khoản: ${AuthService.userEmail}',
    FluentIcons.person_24_filled,
  ),
  CustomBar(
    'Sao lưu đám mây',
    FluentIcons.cloud_sync_24_regular,
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CloudBackupScreen(),
        ),
      );
    },
  ),
  CustomBar(
    'Đăng xuất',
    FluentIcons.sign_out_24_regular,
    onTap: () async {
      await AuthService.signOut();
      setState(() {});
    },
  ),
}
```

### 3. Sử dụng trong Code

#### Đăng nhập
```dart
final result = await AuthService.signIn(
  email: 'user@example.com',
  password: 'password123',
);

if (result.success) {
  // Đăng nhập thành công
} else {
  // Hiển thị lỗi: result.error
}
```

#### Đăng ký
```dart
final result = await AuthService.signUp(
  email: 'user@example.com',
  password: 'password123',
  name: 'User Name',
);
```

#### Backup dữ liệu
```dart
final result = await CloudBackupService.backupToCloud();
```

#### Restore dữ liệu
```dart
final result = await CloudBackupService.restoreFromCloud();
```

## 📊 Cấu trúc Backup Data

```json
{
  "user": {
    "customPlaylists": [...],
    "likedSongs": [...],
    "recentlyPlayedSongs": [...],
    "searchHistory": [...],
    "email": "user@example.com",
    "name": "User Name"
  },
  "settings": {
    "offlineMode": false,
    "useProxy": false,
    "usePureBlackColor": false,
    "useSystemColor": true
  },
  "playlists": {
    "customPlaylists": [...],
    "likedSongs": [...],
    "likedPlaylists": [...],
    "userPlaylists": [...],
    "recentlyPlayedSongs": [...],
    "mostPlayedSongs": [...]
  },
  "metadata": {
    "timestamp": "2025-10-14T16:27:32.236173",
    "appVersion": "9.6.6",
    "backupVersion": "2.0"
  }
}
```

## 🔐 Bảo mật

- Mật khẩu được hash bởi PocketBase (bcrypt)
- Token được lưu an toàn với SharedPreferences
- Auto-refresh token khi hết hạn
- Rules bảo vệ dữ liệu theo user

## 🐛 Troubleshooting

### Lỗi kết nối
```
Lỗi kết nối: Failed to connect
```
**Giải pháp:** Kiểm tra PocketBase server đang chạy và URL đúng

### Lỗi authentication
```
Email hoặc mật khẩu không đúng
```
**Giải pháp:** Kiểm tra thông tin đăng nhập hoặc tạo tài khoản mới

### Lỗi backup
```
Bạn chưa đăng nhập
```
**Giải pháp:** Đăng nhập trước khi sử dụng tính năng backup

## 📝 TODO

- [ ] Thêm forgot password
- [ ] Thêm email verification
- [ ] Thêm avatar upload
- [ ] Thêm automatic backup scheduler
- [ ] Thêm conflict resolution khi restore
- [ ] Thêm encryption cho sensitive data
- [ ] Thêm multi-device sync notification

## 🎨 UI Components

- Login Page: Bottom sheet với Material Design 3
- Register Page: Bottom sheet với validation
- Cloud Backup Screen: Full screen với history list
- Icons: Fluent UI System Icons

## 📚 Tham khảo

- [PocketBase Documentation](https://pocketbase.io/docs/)
- [PocketBase Dart SDK](https://github.com/pocketbase/dart-sdk)
- [Flutter SharedPreferences](https://pub.dev/packages/shared_preferences)

