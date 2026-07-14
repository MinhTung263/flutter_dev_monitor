# Hướng Dẫn Bản Địa Hóa / Localizations Guide

Tài liệu này hướng dẫn cách cập nhật, quản lý và tự động sinh mã (generate code) cho toàn bộ chuỗi văn bản bản địa hóa trong `flutter_dev_monitor`.

---

## 1. Cấu Trúc Thư Mục / Directory Structure

Các tệp tin liên quan đến bản địa hóa nằm ở các đường dẫn sau:
*   [translations.json](file:///Users/minhtung/Development/flutter_dev_monitor/lib/src/core/translations.json): Tệp cấu hình gốc chứa toàn bộ các bản dịch tiếng Anh (`en`) và tiếng Việt (`vi`).
*   [generate_localizations.dart](file:///Users/minhtung/Development/flutter_dev_monitor/tool/generate_localizations.dart): Tập lệnh generator để tự động sinh mã Dart.
*   [monitor_strings.dart](file:///Users/minhtung/Development/flutter_dev_monitor/lib/src/core/monitor_strings.dart): *(Generated)* Trình điều phối trung tâm kiểu dữ liệu an toàn (Type-safe).
*   [monitor_strings_en.dart](file:///Users/minhtung/Development/flutter_dev_monitor/lib/src/core/monitor_strings_en.dart): *(Generated)* Map từ vựng tiếng Anh.
*   [monitor_strings_vi.dart](file:///Users/minhtung/Development/flutter_dev_monitor/lib/src/core/monitor_strings_vi.dart): *(Generated)* Map từ vựng tiếng Việt.

---

## 2. Hướng Dẫn Sử Dụng / How to Use

### Bước 1: Cập nhật hoặc Thêm chuỗi văn bản mới
Mở tệp [translations.json](file:///Users/minhtung/Development/flutter_dev_monitor/lib/src/core/translations.json) và bổ sung theo định dạng phù hợp:

#### A. Đối với chuỗi văn bản tĩnh (Static Strings):
```json
"myNewKey": {
  "en": "My New Text",
  "vi": "Văn bản mới của tôi"
}
```

#### B. Đối với chuỗi văn bản động có tham số truyền vào (Parameterized Strings):
```json
"welcomeMessage": {
  "en": "Welcome {name}!",
  "vi": "Chào mừng {name}!",
  "type": "parameterized",
  "params": ["String name"],
  "replace": ["{name}", "name"]
}
```

#### C. Đối với văn bản đếm số lượng có số ít / số nhiều (Pluralization):
Xem khóa mẫu `errorsCount` trong tệp JSON:
```json
"errorsCount": {
  "en": "{count} Errors",
  "vi": "{count} Lỗi",
  "type": "parameterized",
  "params": ["int count"],
  "replace": ["{count}", "count"],
  "hasOne": true,
  "enOne": "1 Error",
  "viOne": "1 Lỗi"
}
```

---

### Bước 2: Chạy Generator sinh mã tự động
Sau khi lưu tệp JSON, hãy mở Terminal ở thư mục gốc của dự án và chạy lệnh sau:
```bash
dart run tool/generate_localizations.dart
```

Sau khi chạy, generator sẽ tự động viết lại các tệp `.dart` trong thư mục `lib/src/core/` tương ứng.

---

### Bước 3: Sử dụng trong giao diện UI
Trong các Widget của bạn, bạn có thể gọi trực tiếp thông qua `MonitorStrings` mà không cần thêm `.current` hay `.instance`:

#### Ví dụ với Văn bản tĩnh:
```dart
import 'path/to/core/monitor_strings.dart';

BodyText(MonitorStrings.screensTitle, 14);
```

#### Ví dụ với Văn bản động có tham số:
```dart
// Sẽ trả về "Bước 1" hoặc "Step 1" tùy thuộc vào ngôn ngữ hệ thống máy
MonoText(MonitorStrings.step(1), 10);

// Sẽ tự động xử lý số ít/số nhiều "1 Lỗi" hoặc "5 Lỗi"
LabelText(MonitorStrings.errorsCount(totalErrors));
```
