import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_dev_monitor/flutter_dev_monitor.dart';
import 'package:flutter_dev_monitor/src/presentation/ui/widgets/api_log_tile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Body FormData đúng như MonitorInterceptor ghi lại (chạy interceptor thật).
Future<String?> _capturedBody(Object data,
    {Map<String, dynamic>? headers}) async {
  final options = RequestOptions(
    path: 'https://api.example.com/upload',
    method: 'POST',
    data: data,
    headers: headers,
  );
  final handler = RequestInterceptorHandler();
  MonitorInterceptor().onRequest(options, handler);
  // DevMonitor ẩn (như trong test): body được mã hoá lười qua builder.
  final builder = options.extra['req_body_builder'] as String? Function()?;
  return options.extra['req_body'] as String? ?? builder?.call();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'FormData -> --form từng phần (giữ khoá trùng), file -> @"tên", '
      'bỏ Content-Type multipart', () async {
    final form = FormData.fromMap({'name': "O'Neil", 'note': 'a b'})
      ..fields.add(const MapEntry('ids[]', '1'))
      ..fields.add(const MapEntry('ids[]', '2'))
      ..files.add(
        MapEntry(
          'avatar',
          MultipartFile.fromBytes([1, 2, 3], filename: 'anh.png'),
        ),
      );
    final body = await _capturedBody(form);
    expect(body, isNotNull);

    final curl = buildCurlCommand(
      method: 'POST',
      url: 'https://api.example.com/upload',
      headers: {
        'Authorization': 'Bearer x',
        'content-type': 'multipart/form-data; boundary=--dio-boundary-123',
      },
      body: body,
    );

    expect(curl, contains("--form 'name=O'\\''Neil'"));
    expect(curl, contains("--form 'note=a b'"));
    expect(RegExp(r"--form 'ids\[\]=").allMatches(curl).length, 2);
    expect(curl, contains("--form 'avatar=@\"anh.png\""));
    expect(curl, isNot(contains('boundary')));
    expect(curl, isNot(contains(' -d ')));
    expect(curl, contains("-H 'Authorization: Bearer x'"));
  });

  test('x-www-form-urlencoded -> --data-urlencode từng trường', () {
    final curl = buildCurlCommand(
      method: 'POST',
      url: 'https://api.example.com/token',
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: jsonEncode({'grant_type': 'password', 'username': 'demo'}),
    );
    expect(curl, contains("--data-urlencode 'grant_type=password'"));
    expect(curl, contains("--data-urlencode 'username=demo'"));
    expect(curl, isNot(contains(' -d ')));
  });

  test('JSON thường -> -d gọn 1 dòng, thoát dấu nháy đơn', () {
    final curl = buildCurlCommand(
      method: 'POST',
      url: 'https://api.example.com/orders',
      headers: {'Content-Type': 'application/json'},
      body: '{\n  "note": "it\'s ok",\n  "qty": 2\n}',
    );
    expect(curl, contains("-d '{\"note\":\"it'\\''s ok\",\"qty\":2}'"));
    expect(curl, contains("-H 'Content-Type: application/json'"));
  });
}
