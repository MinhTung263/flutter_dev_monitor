import '../../core/monitor_constants.dart';
import '../../data/hardware_datasource.dart';

class HardwareController {
  double currentRam = 0.0;
  double totalRam = 4096.0;
  double appDiskUsed = 0.0;
  double totalDisk = 0.0;
  String deviceModel = '';

  Map<String, List<double>> ramHistoryMap = {};
  final List<double> globalRamHistory = [];

  static const int _maxHistory = 40;

  void update(HardwareSnapshot snapshot, String currentScreen) {
    currentRam = snapshot.ramUsed;
    totalRam = snapshot.ramTotal;
    appDiskUsed = snapshot.appDiskUsed;
    totalDisk = snapshot.diskTotal;

    globalRamHistory.add(currentRam);
    if (globalRamHistory.length > _maxHistory) {
      globalRamHistory.removeAt(0);
    }

    if (currentScreen == MonitorConstants.dashboardRoute ||
        currentScreen == MonitorConstants.unknownRoute) return;

    ramHistoryMap[currentScreen] ??= [];
    ramHistoryMap[currentScreen]!.add(currentRam);
    if (ramHistoryMap[currentScreen]!.length > _maxHistory) {
      ramHistoryMap[currentScreen]!.removeAt(0);
    }
  }

  void clearScreen(String screen) => ramHistoryMap.remove(screen);

  void clearAll() {
    ramHistoryMap = {};
    globalRamHistory.clear();
    currentRam = 0.0;
    totalRam = 4096.0;
    appDiskUsed = 0.0;
    totalDisk = 0.0;
  }
}
