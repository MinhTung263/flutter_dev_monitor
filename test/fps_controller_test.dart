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
    });
  });
}
