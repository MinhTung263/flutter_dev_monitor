import 'package:flutter_dev_monitor/src/domain/api_log_item.dart';
import 'package:flutter_test/flutter_test.dart';

ApiLogItem _log(int i, {String? Function()? reqBuilder}) => ApiLogItem(
      url: 'https://api.example.com/items/$i',
      method: 'POST',
      statusCode: 200,
      duration: 10,
      screen: '/sell',
      timestamp: DateTime(2026),
      requestBodyBuilder: reqBuilder ?? () => '{"i":$i}',
      responseBodyBuilder: () => '{"ok":$i}',
    );

void main() {
  tearDown(() => ApiLogItem.bodyRetentionLimit = 0);

  test('body request chỉ mã hoá khi có người đọc', () {
    var encoded = 0;
    final log = _log(1, reqBuilder: () {
      encoded++;
      return '{"big":true}';
    });
    expect(encoded, 0);
    expect(log.requestBody, '{"big":true}');
    expect(log.requestBody, '{"big":true}');
    expect(encoded, 1, reason: 'mã hoá một lần rồi nhớ');
  });

  test('DevMonitor ẩn: chỉ giữ body của N log gần nhất', () {
    ApiLogItem.bodyRetentionLimit = 3;
    final logs = [for (var i = 0; i < 5; i++) _log(i)];
    expect(logs[0].isBodyReleased, isTrue);
    expect(logs[1].isBodyReleased, isTrue);
    expect(logs[1].responseBody, ApiLogItem.releasedBodyNote);
    expect(logs[4].isBodyReleased, isFalse);
    expect(logs[4].requestBody, '{"i":4}');
    expect(logs[4].responseBody, '{"ok":4}');
    // Siêu dữ liệu vẫn còn để xem danh sách request.
    expect(logs[0].url, endsWith('/items/0'));
  });

  test('bản sao copyWith dùng chung body — giải phóng một lần cho cả hai', () {
    ApiLogItem.bodyRetentionLimit = 2;
    final original = _log(10);
    final merged = original.copyWith(callCount: 3);
    expect(merged.requestBody, '{"i":10}');
    _log(11);
    _log(12); // đẩy body của log 10 ra khỏi giới hạn
    expect(original.isBodyReleased, isTrue);
    expect(merged.isBodyReleased, isTrue);
  });

  test('chuyển từ hiện sang ẩn thì cắt ngay các body cũ', () {
    ApiLogItem.bodyRetentionLimit = 0;
    final logs = [for (var i = 0; i < 6; i++) _log(100 + i)];
    expect(logs.every((l) => !l.isBodyReleased), isTrue);
    ApiLogItem.bodyRetentionLimit = 2;
    expect(logs.where((l) => l.isBodyReleased).length, 4);
    expect(logs.last.requestBody, '{"i":105}');
  });
}
