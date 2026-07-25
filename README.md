# An Đồ — Flutter Android-first

**Tên ứng dụng:** An Đồ  
**Application ID:** `com.hoangluan.safetymap`  
**Slogan:** Biết nguy hiểm. Tìm đường an toàn.

Repo này chuyển prototype HTML thành ứng dụng Flutter native. HTML chỉ nằm trong `prototype/` để đối chiếu UX, không chạy bằng WebView.

## Phạm vi 1.0

- Mở lần đầu bắt buộc chọn ngôn ngữ, mặc định Tiếng Việt; lần sau ghi nhớ lựa chọn.
- Một màn hình bản đồ MapLibre toàn màn hình.
- Không có màn đăng nhập: Firebase Anonymous Auth tạo UID tự động.
- Hồ sơ SOS tùy chọn: tên, điện thoại, email; không trường nào bắt buộc.
- Giữ nút SOS để phát phiên SOS, Foreground Service tiếp tục lấy vị trí khi app xuống nền.
- Danh sách SOS đang hoạt động; người hỗ trợ chỉ xem các phiên SOS chủ động chia sẻ.
- Chọn một phiên SOS, xem 2–3 tuyến OSRM, chọn tuyến phù hợp và mở la bàn.
- Báo đoạn đường có vấn đề bằng ảnh đã nén, loại sự cố, mức độ và ghi chú.
- Mất mạng: dữ liệu quan trọng được giữ local/chờ gửi; bản đồ offline là tính năng mở rộng sau 1.0.
- Một thiết kế duy nhất; không có nhiều theme. Hỗ trợ Việt/Anh.

## Công nghệ

- Flutter 3.44.x / Dart 3.7+
- MapLibre GL
- Firebase Auth, Realtime Database, Firestore, Storage, FCM, Crashlytics, App Check
- Geolocator + flutter_foreground_task
- OSRM public demo endpoint qua interface có thể đổi sang server riêng

## Chạy nhanh

```bash
./tool/repair_platform_scaffold.sh  # chạy một lần nếu ZIP chưa có gradle-wrapper.jar
flutter pub get
flutter run --flavor dev --dart-define=FIREBASE_ENABLED=false
```

Chế độ trên dùng dữ liệu demo local và bản đồ online, phù hợp để kiểm tra UI mà chưa cần Firebase.

## Firebase (đã cấu hình)

- **Account:** `luan20496@gmail.com`
- **Project:** `fir-integration-4405d`
- **Apps:** `com.hoangluan.safetymap` (production) · `com.hoangluan.safetymap.dev` (dev)
- **RTDB:** `https://fir-integration-4405d-default-rtdb.asia-southeast1.firebasedatabase.app`
- Anonymous Auth đã bật; rules Database + Firestore đã deploy.

```bash
flutter run --flavor dev --dart-define=FIREBASE_ENABLED=true
```

## Kết nối Firebase (tạo mới / máy khác)

1. Đăng nhập đúng account: `firebase login:use luan20496@gmail.com`
2. Bật Anonymous Authentication trên project `fir-integration-4405d`.
3. Chạy:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=fir-integration-4405d --platforms=android \
  --android-package-name=com.hoangluan.safetymap
```

4. Chạy app với `--dart-define=FIREBASE_ENABLED=true`.

## Firebase Rules

Repo có sẵn `database.rules.json`, `firestore.rules`, `storage.rules` và `firebase.json`. Deploy bằng `firebase deploy`.

## Build Android

```bash
flutter analyze
flutter test
flutter build apk --flavor dev --debug
flutter build appbundle --flavor production --release \
  --dart-define=FIREBASE_ENABLED=true \
  --dart-define=PRODUCTION=true \
  --obfuscate \
  --split-debug-info=build/symbols
```

AAB production nằm trong `build/app/outputs/bundle/productionRelease/`.

## Điều cần kiểm tra trên thiết bị thật

- Android 8, 10, 12, 13, 14, 15 và 16.
- Samsung/Xiaomi/Oppo/Vivo với tối ưu pin.
- Tắt màn hình 30–60 phút khi SOS đang chạy.
- Mạng chuyển Wi-Fi ⇄ 4G ⇄ mất mạng.
- GPS kém, quyền bị thu hồi, notification bị tắt.
- Ảnh camera lớn, mạng yếu và upload lại.
- Force Stop: Android không cho app tiếp tục; UI phải giải thích rõ.

## Quyền riêng tư

Chính sách đầy đủ (VI/EN) trên GitHub Pages:

**https://luan20495.github.io/an-do/**

Tóm tắt trong app:
- Không đọc IMEI, serial hoặc MAC.
- Installation ID được tạo ngẫu nhiên và lưu local; Firebase UID dùng phân quyền.
- Không chia sẻ vị trí người dùng bình thường.
- Vị trí trực tiếp chỉ được công khai trong phiên SOS do người dùng chủ động phát.
- Profile được mã hóa trong Android EncryptedSharedPreferences trước; chỉ gửi trong phiên SOS sau khi người dùng xác nhận.
- Ứng dụng không thay thế 112 và không bảo đảm một đội cứu hộ sẽ tiếp nhận.
