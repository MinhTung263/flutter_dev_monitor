import '../../core/monitor_constants.dart';
import '../../data/hardware_datasource.dart';

class HardwareController {
  double currentRam = 0.0;
  double totalRam = 0.0;
  double appDiskUsed = 0.0;
  double totalDisk = 0.0;
  double freeDisk = 0.0;
  String deviceModel = '';

  Map<String, List<double>> ramHistoryMap = {};
  final List<double> globalRamHistory = [];

  static const int _maxHistory = 40;

  void update(HardwareSnapshot snapshot, String currentScreen) {
    currentRam = snapshot.ramUsed;
    if (snapshot.ramTotal > 0) {
      totalRam = snapshot.ramTotal;
    }
    appDiskUsed = snapshot.appDiskUsed;
    if (snapshot.diskTotal > 0) {
      totalDisk = snapshot.diskTotal;
    }
    freeDisk = snapshot.diskFree;

    globalRamHistory.add(currentRam);
    if (globalRamHistory.length > _maxHistory) {
      globalRamHistory.removeAt(0);
    }

    if (currentScreen == MonitorConstants.dashboardRoute ||
        currentScreen == MonitorConstants.unknownRoute) {
      return;
    }

    ramHistoryMap[currentScreen] ??= [];
    ramHistoryMap[currentScreen]!.add(currentRam);
    if (ramHistoryMap[currentScreen]!.length > _maxHistory) {
      ramHistoryMap[currentScreen]!.removeAt(0);
    }
  }

  void clearScreen(String screen) => ramHistoryMap.remove(screen);

  void renameSession(String oldScreen, String newScreen) {
    if (oldScreen == newScreen) return;
    final oldBase =
        oldScreen.contains('#') ? oldScreen.split('#').first : oldScreen;
    final newBase =
        newScreen.contains('#') ? newScreen.split('#').first : newScreen;

    final keysToMigrate = ramHistoryMap.keys.where((k) {
      if (k == newScreen) return false;
      if (k == oldScreen) return true;
      if (oldBase == newBase) {
        final kBase = k.contains('#') ? k.split('#').first : k;
        return kBase == newBase;
      }
      return false;
    }).toList();

    for (final k in keysToMigrate) {
      final samples = ramHistoryMap.remove(k);
      if (samples != null && samples.isNotEmpty) {
        final target = ramHistoryMap.putIfAbsent(newScreen, () => <double>[]);
        target.addAll(samples);
        if (target.length > _maxHistory) {
          target.removeRange(0, target.length - _maxHistory);
        }
      }
    }
  }

  void clearAll() {
    ramHistoryMap = {};
    globalRamHistory.clear();
    currentRam = 0.0;
    totalRam = 0.0;
    appDiskUsed = 0.0;
    totalDisk = 0.0;
    freeDisk = 0.0;
  }
}
