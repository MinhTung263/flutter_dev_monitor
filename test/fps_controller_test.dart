import 'package:flutter_dev_monitor/src/domain/api_log_item.dart';
import 'package:flutter_dev_monitor/src/presentation/controller/api_log_controller.dart';
import 'package:flutter_dev_monitor/src/presentation/controller/fps_controller.dart';
import 'package:test/test.dart';

void main() {
  group('FpsController PerfDog Metrics', () {
    late FpsController controller;

    setUp(() {
      controller = FpsController();
    });

    test('initial state has zero jank, bigJank, drops, and stutter rate', () {
      expect(controller.jankFrameCount, equals(0));
      expect(controller.bigJankFrameCount, equals(0));
      expect(controller.dropFrameCount, equals(0));
      expect(controller.stutterRate, equals(0.0));
      expect(controller.totalFrameCount, equals(0));
    });

    test('normal frames within budget do not trigger jank or stutter', () {
      const targetBudgetUs = 16667; // 60Hz ~ 16.67ms
      // 3 normal frames: 8ms, 12ms, 15ms
      controller.recordTiming(longestUs: 8000, targetBudgetUs: targetBudgetUs);
      controller.recordTiming(longestUs: 12000, targetBudgetUs: targetBudgetUs);
      controller.recordTiming(longestUs: 15000, targetBudgetUs: targetBudgetUs);

      expect(controller.totalFrameCount, equals(3));
      expect(controller.jankFrameCount, equals(0));
      expect(controller.bigJankFrameCount, equals(0));
      expect(controller.dropFrameCount, equals(0));
      expect(controller.stutterRate, equals(0.0));
    });

    test('jank frame exceeding budget triggers jank and drop count', () {
      const targetBudgetUs = 16667; // 16.67ms
      // Frame taking 35ms (35000us) -> exceeds budget -> 1 jank, 1 dropped frame (35000 ~/ 16667 - 1 = 1)
      controller.recordTiming(longestUs: 35000, targetBudgetUs: targetBudgetUs);

      expect(controller.jankFrameCount, equals(1));
      expect(controller.bigJankFrameCount, equals(0));
      expect(controller.dropFrameCount, equals(1));
      expect(controller.stutterRate, equals(100.0));
    });

    test('severe frame >= 100ms triggers BigJank', () {
      const targetBudgetUs = 16667;
      // Frame taking 120ms (120000us) -> severe freeze
      controller.recordTiming(longestUs: 120000, targetBudgetUs: targetBudgetUs);

      expect(controller.jankFrameCount, equals(1));
      expect(controller.bigJankFrameCount, equals(1));
      expect(controller.dropFrameCount, equals(6)); // 120000 ~/ 16667 - 1 = 6
    });

    test('stutter rate calculates ratio of jank frame time to total frame time', () {
      const targetBudgetUs = 16667;
      // 1 smooth frame of 10ms (10000us)
      controller.recordTiming(longestUs: 10000, targetBudgetUs: targetBudgetUs);
      // 1 jank frame of 30ms (30000us)
      controller.recordTiming(longestUs: 30000, targetBudgetUs: targetBudgetUs);

      // Total time = 40000us, Jank time = 30000us -> Stutter Rate = 30000 / 40000 * 100 = 75.0%
      expect(controller.stutterRate, closeTo(75.0, 0.01));
    });

    test('clearAll resets all PerfDog metrics to zero', () {
      const targetBudgetUs = 16667;
      controller.recordTiming(longestUs: 120000, targetBudgetUs: targetBudgetUs);
      expect(controller.bigJankFrameCount, equals(1));

      controller.clearAll();

      expect(controller.jankFrameCount, equals(0));
      expect(controller.bigJankFrameCount, equals(0));
      expect(controller.dropFrameCount, equals(0));
      expect(controller.totalFrameCount, equals(0));
      expect(controller.stutterRate, equals(0.0));
      expect(controller.currentBuildMs, equals(0.0));
      expect(controller.currentGpuMs, equals(0.0));
    });

    test('base-route session unification prevents log splitting on late AppBar title resolution', () {
      final apiCtrl = ApiLogController();
      // 1. BottomNavBar tab pressed -> provisional tab title "Đơn hàng"
      apiCtrl.startSession('/page_builder/order_view#Đơn hàng');
      apiCtrl.addLog(
        ApiLogItem(
          id: 1,
          method: 'GET',
          url: 'https://api.example.com/orders?page=1',
          statusCode: 200,
          duration: 120,
          timestamp: DateTime.now(),
          screen: '/page_builder/order_view#Đơn hàng',
        ),
        '/page_builder/order_view#Đơn hàng',
        '',
      );

      // 2. OrderPageAppBar mounts 60ms later -> authoritative title "Lịch sử đơn hàng"
      apiCtrl.renameSession(
        '/page_builder/order_view',
        '/page_builder/order_view#Lịch sử đơn hàng',
      );

      // 3. Another API completes still carrying the old or bare route
      apiCtrl.addLog(
        ApiLogItem(
          id: 2,
          method: 'GET',
          url: 'https://api.example.com/orders/summary',
          statusCode: 200,
          duration: 85,
          timestamp: DateTime.now(),
          screen: '/page_builder/order_view#Đơn hàng',
        ),
        '/page_builder/order_view#Đơn hàng',
        '',
      );

      // Both logs must be unified under '/page_builder/order_view#Lịch sử đơn hàng'
      apiCtrl.isDashboardOpen = true;
      apiCtrl.updateView('/page_builder/order_view#Lịch sử đơn hàng');
      expect(apiCtrl.initApiCount, equals(2));
      expect(apiCtrl.apiLogs.length, equals(2));
      expect(
        apiCtrl.apiLogs.every(
          (l) => l.screen == '/page_builder/order_view#Lịch sử đơn hàng',
        ),
        isTrue,
      );
    });

    test('chained LOAD APIs after slow initial batch remain in LOAD and parallel durations merge accurately', () {
      final apiCtrl = ApiLogController();
      const screen = '/pos/sale#Bán hàng';
      apiCtrl.startSession(screen);

      final t0 = DateTime.now();
      // Batch 1: 2 parallel APIs started at t0, taking 950ms and 1100ms (> 800ms refreshGapMs!)
      final start1 = apiCtrl.onRequestStart(screen);
      final start2 = apiCtrl.onRequestStart(screen);
      expect(start1.phase, equals(ApiLogItem.phaseInit));
      expect(start2.phase, equals(ApiLogItem.phaseInit));

      apiCtrl.addLog(
        ApiLogItem(
          id: 1,
          method: 'GET',
          url: 'https://api.example.com/products',
          statusCode: 200,
          duration: 950,
          timestamp: t0,
          screen: screen,
        ),
        screen,
        '',
        preassignedPhase: start1.phase,
        preassignedCycle: start1.cycle,
      );
      apiCtrl.addLog(
        ApiLogItem(
          id: 2,
          method: 'GET',
          url: 'https://api.example.com/categories',
          statusCode: 200,
          duration: 1100,
          timestamp: t0,
          screen: screen,
        ),
        screen,
        '',
        preassignedPhase: start2.phase,
        preassignedCycle: start2.cycle,
      );

      // Batch 2 (chained in onInit right after Batch 1 finishes, 1110ms after t0, zero user touch):
      final start3 = apiCtrl.onRequestStart(screen);
      expect(start3.phase, equals(ApiLogItem.phaseInit));

      apiCtrl.addLog(
        ApiLogItem(
          id: 3,
          method: 'GET',
          url: 'https://api.example.com/vouchers',
          statusCode: 200,
          duration: 190,
          timestamp: t0.add(const Duration(milliseconds: 1110)),
          screen: screen,
        ),
        screen,
        '',
        preassignedPhase: start3.phase,
        preassignedCycle: start3.cycle,
      );

      final stats = apiCtrl.statsForScreen(screen);
      expect(stats.openCount, equals(3));
      expect(stats.actionCount, equals(0));
      // Merged duration: [0..1100] (1100ms) + [1110..1300] (190ms) = 1290ms (NOT 950+1100+190 = 2240ms)
      expect(stats.openMs, equals(1290));
    });

    test('subsequent user interactions accumulate total actionCount across multiple interaction cycles', () {
      final apiCtrl = ApiLogController();
      const screen = '/orders#Lịch sử đơn hàng';
      apiCtrl.startSession(screen);

      final baseTime = DateTime.now().subtract(const Duration(seconds: 5));
      // Initial LOAD: 2 APIs
      apiCtrl.addLog(
        ApiLogItem(
          id: 1,
          method: 'GET',
          url: 'https://api.example.com/bills?page=1',
          statusCode: 200,
          duration: 200,
          timestamp: baseTime,
          screen: screen,
        ),
        screen,
        '',
        preassignedPhase: ApiLogItem.phaseInit,
        preassignedCycle: 1,
      );

      // User interacts #1 (e.g. taps filter -> 2 APIs)
      apiCtrl.onUserPointerDown(screen);
      final act1A = apiCtrl.onRequestStart(screen);
      final act1B = apiCtrl.onRequestStart(screen);
      expect(act1A.phase, equals(ApiLogItem.phaseRefresh));
      expect(act1A.cycle, equals(1));
      expect(act1B.cycle, equals(1));

      final tAct1 = baseTime.add(const Duration(seconds: 2));
      apiCtrl.addLog(
        ApiLogItem(
          id: 2,
          method: 'GET',
          url: 'https://api.example.com/bills?page=1',
          statusCode: 200,
          duration: 150,
          timestamp: tAct1,
          screen: screen,
        ),
        screen,
        '',
        preassignedPhase: act1A.phase,
        preassignedCycle: act1A.cycle,
      );
      apiCtrl.addLog(
        ApiLogItem(
          id: 3,
          method: 'POST',
          url: 'https://api.example.com/bills/offline/search',
          statusCode: 200,
          duration: 100,
          timestamp: tAct1,
          screen: screen,
        ),
        screen,
        '',
        preassignedPhase: act1B.phase,
        preassignedCycle: act1B.cycle,
      );

      // After Interaction #1 (which called 2 APIs), actionCount is 2
      expect(apiCtrl.statsForScreen(screen).actionCount, equals(2));
      expect(apiCtrl.refreshApiCount, equals(2));

      // User interacts #2 (e.g. pulls to refresh or taps next page -> 1 API)
      apiCtrl.onUserPointerDown(screen);
      final act2 = apiCtrl.onRequestStart(screen);
      expect(act2.phase, equals(ApiLogItem.phaseRefresh));
      expect(act2.cycle, equals(2));

      final tAct2 = baseTime.add(const Duration(seconds: 4));
      apiCtrl.addLog(
        ApiLogItem(
          id: 4,
          method: 'GET',
          url: 'https://api.example.com/bills?page=2',
          statusCode: 200,
          duration: 180,
          timestamp: tAct2,
          screen: screen,
        ),
        screen,
        '',
        preassignedPhase: act2.phase,
        preassignedCycle: act2.cycle,
      );

      apiCtrl.isDashboardOpen = true;
      apiCtrl.updateView(screen);
      final stats = apiCtrl.statsForScreen(screen);

      // LOAD has 1 API; latest interaction (#2) has 1 API (not accumulating 2+1=3 on the badge!)
      expect(stats.openCount, equals(1));
      expect(stats.actionCount, equals(1));
      expect(apiCtrl.refreshApiCount, equals(1));
      expect(apiCtrl.totalRefreshApiCount, equals(3));
      expect(stats.actionCycles, equals(2));
      // Same URL '/bills?page=1' called in LOAD and INTERACTION #1 must NOT merge across phases
      expect(
        apiCtrl.apiLogs.where((l) => l.phase == ApiLogItem.phaseInit).length,
        equals(1),
      );
      expect(
        apiCtrl.apiLogs.where((l) => l.phase == ApiLogItem.phaseRefresh).length,
        equals(3),
      );
    });
  });
}
