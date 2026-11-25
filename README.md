# Viora

Ứng dụng mạng xã hội và nhắn tin thời gian thực được xây dựng với **Flutter** và **Node.js (Express + MongoDB + Socket.IO)**.

---

## Tải xuống ứng dụng (Android APK)

[![Download Viora APK](https://img.shields.io/badge/Download-Viora.apk-2196F3?style=for-the-badge&logo=android&logoColor=white)](https://github.com/bachocodehihi/Viora/releases/latest/download/Viora.apk)

- **Tải trực tiếp bản mới nhất**: [`Viora.apk`](https://github.com/bachocodehihi/Viora/releases/latest/download/Viora.apk)
- **Trang phát hành (Releases)**: [github.com/bachocodehihi/Viora/releases](https://github.com/bachocodehihi/Viora/releases)

> **Lưu ý cài đặt:** Bật quyền *"Cài đặt ứng dụng từ nguồn không xác định"* (Install unknown apps) trên thiết bị Android trước khi mở file `Viora.apk`.

---

## Tính năng nổi bật

- **Mạng xã hội**: Đăng bài viết, Story, tương tác (thích, bình luận, chia sẻ), nhóm cộng đồng, tìm kiếm và quét mã QR.
- **Nhắn tin thời gian thực**: Chat 1-1 và chat nhóm qua Socket.IO (văn bản, hình ảnh, bài viết chia sẻ, mention `@`, tin nhắn thoại hiển thị sóng âm thực tế kèm thanh tua/scrubbing).
- **Trợ lý `@VioraAI` trong đoạn chat**: Tag `@VioraAI` trong cuộc trò chuyện 1-1 hoặc nhóm để AI tham gia trả lời như thành viên thứ 3 theo ngữ cảnh lịch sử chat.
- **Gọi thoại, Video Call & Livestream**: Tích hợp Agora RTC Engine và thông báo cuộc gọi đến (`flutter_callkit_incoming`).
- **Bản đồ & Định vị**: Tích hợp MapLibre GL và Geolocator.
- **Thông báo đẩy (Push Notification)**: Firebase Cloud Messaging (FCM).

---

## Cấu trúc dự án

```text
Viora/
├── Flutter/viora_app/      # Ứng dụng mobile Flutter
└── Nodejs/viora_backend/   # API Server Node.js, Express, MongoDB, Socket.IO
```

---

## Hướng dẫn chạy local

### 1. Backend (`Nodejs/viora_backend`)

```bash
cd Nodejs/viora_backend
npm install
node src/server.js
```

### 2. Mobile App (`Flutter/viora_app`)

Chỉnh lại URL backend trong `Flutter/viora_app/lib/config/api_config.dart`, sau đó chạy:

```bash
cd Flutter/viora_app
flutter pub get
flutter run --release
```
