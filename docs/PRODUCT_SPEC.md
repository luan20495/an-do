# Product Spec 1.0

## Nguyên tắc

1. Map-first: bản đồ luôn là không gian chính.
2. Zero-login UI: thiết bị được nhận diện ẩn danh.
3. SOS không bị chặn bởi profile trống.
4. Người hỗ trợ chỉ thấy phiên SOS đang hoạt động.
5. Hai hành động chính: **Báo đường** và **Giữ để SOS**.
6. Mọi phần còn lại dùng drawer, popup hoặc bottom sheet ba nấc.
7. Một giao diện duy nhất, Việt/Anh.

## Luồng chính

- Lần đầu: chọn ngôn ngữ → giải thích dữ liệu → bản đồ.
- SOS: giữ nút → chọn loại → profile tùy chọn → xác nhận dữ liệu → phát.
- Cứu hộ: chọn marker SOS → xem hồ sơ → chọn tuyến → dẫn đường/la bàn.
- Báo đường: chụp ảnh → chọn loại/mức độ → gửi hoặc lưu chờ mạng.
