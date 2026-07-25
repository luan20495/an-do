# Implementation Summary

## Đã triển khai

- Flutter Android-first, application ID `com.hoangluan.safetymap`.
- Màn chọn ngôn ngữ bắt buộc ở lần mở đầu, mặc định Tiếng Việt.
- Một giao diện duy nhất, không có nhiều theme.
- Một màn hình MapLibre toàn màn hình với bottom sheet ba nấc.
- Firebase Anonymous Auth và Installation ID mã hóa local.
- SOS profile tùy chọn, lưu bằng Android EncryptedSharedPreferences.
- Foreground Service lấy vị trí mỗi 10 giây và cập nhật Realtime Database.
- Danh sách SOS đang hoạt động, nhận hỗ trợ một ca, mở tuyến và la bàn.
- OSRM lấy tối đa ba tuyến thay thế.
- Báo đường bằng camera/thư viện, nén JPEG và upload Firebase Storage.
- Hàng đợi local cho báo cáo khi Firebase/mạng chưa sẵn sàng.
- Firebase rules cho Realtime Database, Firestore và Storage.
- Flavors `dev` và `production`.
- Unit/widget tests và Android CI.

## Mở rộng sau

- Bản đồ và routing offline thật.
- Video/audio hiện trường.
- Dashboard điều phối web.
- Xác minh tổ chức cứu hộ.
