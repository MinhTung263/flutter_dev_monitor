import 'package:flutter_dev_monitor/flutter_dev_monitor.dart';
import 'package:test/test.dart';

// Mirror of _extractCallerPackage logic (now removed from production code)
String? extractCallerPackage(String trace) {
  final pkgRegex = RegExp(r'\(package:([a-z0-9_]+)/');
  for (final line in trace.split('\n')) {
    if (line.isEmpty) continue;
    final match = pkgRegex.firstMatch(line);
    if (match != null) {
      final pkg = match.group(1)!;
      if (pkg.startsWith('sds_feat_') ||
          pkg.startsWith('easy_pos') && !pkg.contains('page_builder')) {
        return pkg;
      }
    }
  }
  return null;
}

// Mirror of _inferScreenFromUrl logic from MonitorInterceptor
String? inferScreenFromUrl(String path) {
  final match = RegExp(r'/page/([^/]+)/').firstMatch(path);
  if (match != null) {
    final segment = match.group(1)!;
    if (segment == 'common' || segment == 'v1' || segment == 'v2') {
      return null;
    }
    return segment;
  }
  return null;
}

void main() {
  group('_extractCallerPackage', () {
    test('returns sds_feat_order_view when bill API fired from background keepAlive widget', () {
      const fakeTrace = '''
#0      MonitorInterceptor.onRequest (package:flutter_dev_monitor/src/data/monitor_interceptor.dart:20:5)
#1      Interceptor.onRequest (package:dio/src/interceptors.dart:77:7)
#2      QueuedInterceptorsRunner._handleRequest (package:dio/src/interceptors.dart:152:27)
#3      OrderViewRepository.loadBills (package:sds_feat_order_view/feature/data/order_view_repository.dart:45:12)
#4      OrderViewController.refreshOrders (package:sds_feat_order_view/feature/presentation/controller.dart:88:5)
''';
      expect(extractCallerPackage(fakeTrace), equals('sds_feat_order_view'));
    });

    test('returns sds_feat_invoice for invoice API', () {
      const fakeTrace = '''
#0      MonitorInterceptor.onRequest (package:flutter_dev_monitor/src/data/monitor_interceptor.dart:20:5)
#1      InvoiceRepository.fetchInvoices (package:sds_feat_invoice/feature/data/invoice_repository.dart:33:9)
''';
      expect(extractCallerPackage(fakeTrace), equals('sds_feat_invoice'));
    });

    test('returns null when no feature package found', () {
      const fakeTrace = '''
#0      MonitorInterceptor.onRequest (package:flutter_dev_monitor/src/data/monitor_interceptor.dart:20:5)
#1      QueuedInterceptorsRunner._handleRequest (package:dio/src/interceptors.dart:152:27)
#2      _rootRunUnary (dart:async/zone.dart:1396:47)
''';
      expect(extractCallerPackage(fakeTrace), isNull);
    });

    test('first sds_feat_* frame wins', () {
      const fakeTrace = '''
#0      MonitorInterceptor.onRequest (package:flutter_dev_monitor/src/data/monitor_interceptor.dart:20:5)
#1      BillRepository.fetch (package:sds_feat_order_view/feature/data/bill_repository.dart:28:7)
#2      InvoiceController.onLoad (package:sds_feat_invoice/feature/presentation/controller.dart:55:5)
''';
      expect(extractCallerPackage(fakeTrace), equals('sds_feat_order_view'));
    });
  });

  group('_inferScreenFromUrl', () {
    test('bill API → bill', () {
      expect(inferScreenFromUrl('/api/client/page/bill/get-with-paging'), equals('bill'));
    });

    test('invoice API → invoice', () {
      expect(inferScreenFromUrl('/api/client/page/invoice/get-with-paging'), equals('invoice'));
    });

    test('home2 stats → home2', () {
      expect(inferScreenFromUrl('/api/client/page/home2/bill-common-stats'), equals('home2'));
    });

    test('order_view → order_view', () {
      expect(inferScreenFromUrl('/api/client/page/order_view/list'), equals('order_view'));
    });

    test('common segment → null', () {
      expect(inferScreenFromUrl('/api/client/common/get-status'), isNull);
    });

    test('URL without /page/ → null', () {
      expect(inferScreenFromUrl('/api/payment-integration/gateway/get/4466'), isNull);
    });

    test('v1 segment skipped → null', () {
      expect(inferScreenFromUrl('/api/v1/something/list'), isNull);
    });

    test('print-template → print-template (has dashes, still valid segment)', () {
      expect(inferScreenFromUrl('/api/client/page/print-template/get-all'), equals('print-template'));
    });
  });

  group('HTTP methods PUT & DELETE support', () {
    test('MonitorFilterKeys contains GET, POST, PUT, DELETE', () {
      expect(MonitorFilterKeys.get, equals('GET'));
      expect(MonitorFilterKeys.post, equals('POST'));
      expect(MonitorFilterKeys.put, equals('PUT'));
      expect(MonitorFilterKeys.delete, equals('DELETE'));
    });

    test('MonitorColors.methodColor returns distinct colors for methods', () {
      final getColor = MonitorColors.methodColor('GET');
      final postColor = MonitorColors.methodColor('POST');
      final putColor = MonitorColors.methodColor('PUT');
      final deleteColor = MonitorColors.methodColor('DELETE');

      expect(getColor, equals(MonitorColors.methodGet));
      expect(postColor, equals(MonitorColors.methodPost));
      expect(putColor, equals(MonitorColors.methodPut));
      expect(deleteColor, equals(MonitorColors.methodDelete));

      // Case insensitivity
      expect(MonitorColors.methodColor('put'), equals(MonitorColors.methodPut));
      expect(MonitorColors.methodColor('delete'), equals(MonitorColors.methodDelete));
    });
  });

  group('ApiLogItem.matchesQuery', () {
    final getLog = ApiLogItem(
      url: 'https://api.easypos.vn/api/v1/order/list',
      method: 'GET',
      statusCode: 200,
      duration: 120,
      screen: '/order',
      timestamp: DateTime.now(),
    );

    final postWithGetInUrl = ApiLogItem(
      url: 'https://api.easypos.vn/api/v1/widget/get-order-detail',
      method: 'POST',
      statusCode: 200,
      duration: 250,
      screen: '/order',
      timestamp: DateTime.now(),
    );

    final postTarget = ApiLogItem(
      url: 'https://api.easypos.vn/api/v1/target/settings',
      method: 'POST',
      statusCode: 200,
      duration: 300,
      screen: '/settings',
      timestamp: DateTime.now(),
    );

    final errorLog = ApiLogItem(
      url: 'https://api.easypos.vn/api/v1/auth/login',
      method: 'POST',
      statusCode: 404,
      duration: 80,
      screen: '/login',
      timestamp: DateTime.now(),
    );

    test('searching "get" matches GET and NEVER matches POST even if URL contains "get"', () {
      expect(getLog.matchesQuery('get'), isTrue);
      expect(getLog.matchesQuery('GET'), isTrue);

      // POST request with "get-order-detail" in url must NOT match "get"
      expect(postWithGetInUrl.matchesQuery('get'), isFalse);
      expect(postWithGetInUrl.matchesQuery('GET'), isFalse);

      // POST request with "target" (contains "get") in url must NOT match "get"
      expect(postTarget.matchesQuery('get'), isFalse);
    });

    test('searching "post" matches POST and does not match GET', () {
      expect(postWithGetInUrl.matchesQuery('post'), isTrue);
      expect(postTarget.matchesQuery('POST'), isTrue);
      expect(getLog.matchesQuery('post'), isFalse);
    });

    test('searching "get /order" matches GET with /order and rejects POST', () {
      expect(getLog.matchesQuery('get /order'), isTrue);
      expect(postWithGetInUrl.matchesQuery('get /order'), isFalse);
    });

    test('searching status code "404" matches 404 response', () {
      expect(errorLog.matchesQuery('404'), isTrue);
      expect(getLog.matchesQuery('404'), isFalse);
    });

    test('searching generic keyword "order" matches both when present in url', () {
      expect(getLog.matchesQuery('order'), isTrue);
      expect(postWithGetInUrl.matchesQuery('order'), isTrue);
      expect(errorLog.matchesQuery('order'), isFalse);
    });
  });
}
