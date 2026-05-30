class FpsController {
  double currentFps = 0.0;
  double currentBuildMs = 0.0;
  double currentGpuMs = 0.0;

  Map<String, List<double>> fpsHistoryMap = {};
  final List<double> overlayFpsHistory = [];
  final List<double> overlayGpuHistory = [];
  final List<double> overlayBuildHistory = [];

  static const int _maxHistory = 150;
  static const int _maxOverlay = 60;

  void addSample(String screenName, double fps) {
    if (screenName.isEmpty || screenName == '/unknown') return;
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

  void update(double fps, double buildMs, double gpuMs) {
    currentFps = fps;
    currentBuildMs = buildMs;
    currentGpuMs = gpuMs;
  }

  void clearOverlayHistory() {
    overlayFpsHistory.clear();
    overlayGpuHistory.clear();
    overlayBuildHistory.clear();
  }

  void clearScreen(String screen) => fpsHistoryMap.remove(screen);

  void clearAll() {
    fpsHistoryMap = {};
    clearOverlayHistory();
  }
}
