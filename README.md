# flutter_dev_monitor

An in-app developer monitor for Flutter. Tracks API calls, FPS, RAM, and disk usage with a floating overlay and a full dashboard — framework-agnostic, works with GetX, Provider, Riverpod, or plain Flutter.

## Features

- **Floating HUD** — draggable overlay showing live FPS, GPU ms, build ms, RAM, and network ping
- **API log** — captures every Dio request: URL, method, status code, duration, caller function, and screen
- **OPEN / ACTION phases** — automatically separates APIs that ran when the screen opened (OPEN) from those triggered by user actions (ACTION); each visit creates a fresh OPEN group
- **FPS chart** — per-screen frame-time history with avg/min/max stats
- **RAM chart** — per-screen memory history with avg/min/max stats
- **Hardware grid** — RAM / disk usage updated every 3 seconds
- **Error capture** — catches Flutter and Dart unhandled errors with stack traces
- **Route log** — records every push / pop / replace with timestamp
- **Screen-aware** — data is scoped per route; up to 50 screens tracked (LRU eviction)

## Getting started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_dev_monitor: ^1.3.0
  dio: ^5.9.0        # required for MonitorInterceptor
```

## Setup

### 1. Add the Dio interceptor

```dart
final dio = Dio()..interceptors.add(DevMonitor.interceptor);
```

All requests made through this `Dio` instance are automatically captured.

### 2. Configure `MaterialApp`

```dart
MaterialApp(
  navigatorObservers: [DevMonitor.observer],
  builder: DevMonitor.builder(),   // overlay visible by default
  home: const HomeScreen(),
)
```

- `DevMonitor.observer` tracks the active route so API logs are grouped by screen.
- `DevMonitor.builder()` injects the draggable FPS/RAM overlay automatically.

#### Overlay visibility

By default the overlay is always visible. Pass `showOverlay: false` to start hidden — useful for production builds where you only want the overlay on demand:

```dart
// Always visible (default):
builder: DevMonitor.builder(),

// Hidden until toggled (e.g. release / QA builds):
builder: DevMonitor.builder(showOverlay: false),
```

Toggle at runtime from anywhere:

```dart
DevMonitor.showOverlay();
DevMonitor.hideOverlay();
DevMonitor.toggleOverlay();
```

Or wrap any widget (logo, version label, etc.) with a secret N-tap trigger:

```dart
DevMonitor.tapToToggle(
  tapCount: 7,          // default
  clipboardKey: 'dev',  // optional: copies to clipboard on trigger
  child: myLogoWidget,
)
```

### 3. Open the dashboard

Navigate to `MonitorDashboardPage` from anywhere — a button in your AppBar works well:

```dart
IconButton(
  icon: const Icon(Icons.bar_chart),
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: '/MonitorDashboardPage'),
      builder: (_) => const MonitorDashboardPage(
        initialScreen: '/HomeScreen',
      ),
    ),
  ),
)
```

## Full example

```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dev_monitor/flutter_dev_monitor.dart';

final dio = Dio(BaseOptions(baseUrl: 'https://jsonplaceholder.typicode.com'))
  ..interceptors.add(DevMonitor.interceptor);

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [DevMonitor.observer],
      builder: DevMonitor.builder(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    dio.get('/posts');    // captured automatically — appears as OPEN
    dio.get('/users');    // captured automatically — appears as OPEN
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/MonitorDashboardPage'),
                builder: (_) => const MonitorDashboardPage(
                  initialScreen: '/HomeScreen',
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => dio.get('/posts/1'), // appears as ACTION
          child: const Text('Refresh'),
        ),
      ),
    );
  }
}
```

A runnable example with multiple screens and refresh simulation is in the [`example/`](example/) directory.

## Usage with state management

### Provider / plain Flutter

```dart
// MonitorController.instance is a singleton ChangeNotifier.
final fps = MonitorController.instance.currentFps;
```

### GetX

```dart
Get.put(MonitorController.instance);
```

### Riverpod

```dart
final monitorProvider = ChangeNotifierProvider((_) => MonitorController.instance);
```

## API reference

| Class / Member | Description |
|---|---|
| `DevMonitor.interceptor` | Singleton `MonitorInterceptor` — add to your `Dio` instance |
| `DevMonitor.observer` | Singleton `MonitorNavigatorObserver` — pass to `navigatorObservers` |
| `DevMonitor.builder({bool showOverlay})` | Returns a `TransitionBuilder` for `MaterialApp.builder`; sets initial overlay visibility |
| `DevMonitor.appBuilder` | `TransitionBuilder` — same as `builder()` with default visibility, kept for backwards compatibility |
| `DevMonitor.showOverlay()` | Show the overlay at runtime |
| `DevMonitor.hideOverlay()` | Hide the overlay at runtime |
| `DevMonitor.toggleOverlay()` | Toggle overlay visibility |
| `DevMonitor.tapToToggle(...)` | Wraps a widget with a secret N-tap toggle trigger |
| `MonitorDashboardPage` | Full dashboard — push as a named route |
| `MonitorController` | Singleton `ChangeNotifier` with all observable state |
| `FpsOverlay` | Low-level overlay widget — use `DevMonitor.builder()` instead |

### `DevMonitor.builder()` parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `showOverlay` | `bool` | `true` | Initial overlay visibility; can be changed at runtime via `showOverlay()`/`hideOverlay()` |

### `DevMonitor.tapToToggle()` parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | required | Widget to wrap |
| `tapCount` | `int` | `7` | Number of consecutive taps to trigger |
| `clipboardKey` | `String?` | `null` | String copied to clipboard on each trigger |

### `MonitorDashboardPage` parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `initialScreen` | `String` | required | Route name of the screen to show on open (e.g. `'/HomeScreen'`) |

## Notes

- **Debug / profile only** — wrap usage in `kDebugMode` or `kProfileMode` checks before releasing to production.
- The package uses a `MethodChannel` for native RAM and disk data. Native implementations are included for Android (Kotlin) and iOS (Swift).
- Supports Android and iOS only (not web or desktop).
