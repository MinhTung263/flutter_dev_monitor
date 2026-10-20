import '../../core/monitor_constants.dart';

class FpsController {
  double currentFps = 60.0;
  double currentBuildMs = 0.0;
  double currentGpuMs = 0.0;
  int jankFrameCount = 0;
  int bigJankFrameCount = 0;
  int dropFrameCount = 0;
  int totalFrameCount = 0;
  int totalRenderDurationUs = 0;
  int totalJankDurationUs = 0;
  bool isIdle = false;

  /// PerfDog Stutter Rate (%): Total duration of jank frames / Total frame duration * 100
  double get stutterRate => (totalRenderDurationUs > 0 && jankFrameCount > 0)
      ? (totalJankDurationUs / totalRenderDurationUs * 100.0).clamp(0.0, 100.0)
      : 0.0;

  Map<String, List<double>> fpsHistoryMap = {};
  final List<double> overlayFpsHistory = [];
  final List<double> overlayGpuHistory = [];
  final List<double> overlayBuildHistory = [];

  static const int _maxHistory = 150;
  static const int _maxOverlay = 60;

  void addSample(String screenName, double fps) {
    if (screenName.isEmpty || screenName == MonitorConstants.unknownRoute) return;
    fpsHistoryMap[screenName] ??= [];
    fpsHistoryMap[screenName]!.add(fps);
    if (fpsHistoryMap[screenName]!.length > _maxHistory) {
      fpsHistoryMap[screenName]!.removeAt(0);
    }
  }

  void addOverlaySamples(double fps, double gpuMs, double buildMs) {
    void addCapped(List<double> list, double value) {
      if (value > 0) {
        list.add(value);
        if (list.length > _maxOverlay) list.removeAt(0);
      }
    }

    addCapped(overlayFpsHistory, fps);
    addCapped(overlayGpuHistory, gpuMs);
    addCapped(overlayBuildHistory, buildMs);
  }

  void update(double fps, double buildMs, double gpuMs, {bool isIdle = false}) {
    currentFps = fps;
    currentBuildMs = buildMs;
    currentGpuMs = gpuMs;
    this.isIdle = isIdle;
  }

  /// Records timing of each frame according to PerfDog / DevTools specs
  void recordTiming({required int longestUs, required int targetBudgetUs}) {
    totalFrameCount++;
    totalRenderDurationUs += longestUs;
    if (longestUs > targetBudgetUs) {
      jankFrameCount++;
      totalJankDurationUs += longestUs;
      final dropped = (longestUs ~/ targetBudgetUs) - 1;
      if (dropped > 0) {
        dropFrameCount += dropped;
      }
      // BigJank: severe stutter >= 100ms (>= 6 frames dropped at 60Hz)
      if (longestUs >= 100000) {
        bigJankFrameCount++;
      }
    }
  }

  void recordJankFrame() {
    jankFrameCount++;
  }

  void clearOverlayHistory() {
    overlayFpsHistory.clear();
    overlayGpuHistory.clear();
    overlayBuildHistory.clear();
  }

  void clearScreen(String screen) => fpsHistoryMap.remove(screen);

  void clearAll() {
    fpsHistoryMap = {};
    jankFrameCount = 0;
    bigJankFrameCount = 0;
    dropFrameCount = 0;
    totalFrameCount = 0;
    totalRenderDurationUs = 0;
    totalJankDurationUs = 0;
    currentFps = 60.0;
    currentBuildMs = 0.0;
    currentGpuMs = 0.0;
    clearOverlayHistory();
  }
}
