# flutter_dev_monitor

An in-app developer monitor for Flutter. Tracks API calls, FPS, RAM, and disk usage with a floating overlay and a full dashboard — framework-agnostic, works with GetX, Provider, Riverpod, or plain Flutter.

## Features

- **Floating HUD** — draggable overlay showing live FPS, GPU ms, build ms, RAM
- **API log** — captures every Dio request: URL, method, status code, duration, caller function, and screen
- **FPS chart** — per-screen frame-time history
- **Hardware grid** — RAM / disk usage updated every 3 seconds
- **Phase detection** — automatically separates *init* calls (first load) from *refresh* calls (pull-to-refresh, periodic polling)
- **Screen-aware** — data is scoped per route; cleared when the screen is popped

## Getting started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_dev_monitor: ^1.0.0
  dio: ^5.9.0        # required for MonitorInterceptor
```

## Setup

### 1. Add the Dio interceptor

```dart
final dio = Dio()..interceptors.add(MonitorInterceptor());
```

All requests made through this `Dio` instance are automatically captured.

### 2. Register the navigator observer

```dart
MaterialApp(
  navigatorObservers: [MonitorNavigatorObserver()],
  home: ...,
)
```

This tracks which screen is active so API logs are grouped by route.

### 3. Wrap your root widget with `FpsOverlay`

```dart
MaterialApp(
  navigatorObservers: [MonitorNavigatorObserver()],
  home: FpsOverlay(
    child: const HomeScreen(),
  ),
)
```

A draggable HUD appears on screen showing real-time FPS and memory.

### 4. Open the dashboard

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
  ..interceptors.add(MonitorInterceptor());

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [MonitorNavigatorObserver()],
      home: FpsOverlay(child: const HomeScreen()),
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
    dio.get('/posts');       // captured automatically
    dio.get('/users');       // captured automatically
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
      body: const Center(child: Text('Your app content')),
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

| Class | Description |
|---|---|
| `MonitorInterceptor` | Dio interceptor — add to your `Dio` instance |
| `MonitorNavigatorObserver` | Navigator observer — pass to `MaterialApp.navigatorObservers` |
| `FpsOverlay` | Wraps your widget tree; shows the draggable HUD |
| `MonitorDashboardPage` | Full dashboard — push as a named route |
| `MonitorController` | Singleton `ChangeNotifier` with all observable state |

### `FpsOverlay` parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | required | The widget tree to wrap |
| `isShowing` | `bool` | `true` | Show or hide the overlay at runtime |

### `MonitorDashboardPage` parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `initialScreen` | `String` | required | Route name of the screen to show on open (e.g. `'/HomeScreen'`) |

## Notes

- **Debug / profile only** — wrap usage in `kDebugMode` or `kProfileMode` checks before releasing to production.
- The package uses a `MethodChannel` for native RAM and disk data. Native implementations are included for Android (Kotlin) and iOS (Swift).
- Supports Android and iOS only (not web or desktop).
