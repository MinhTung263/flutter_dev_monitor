## 1.1.0

* **Dashboard redesign** — dark theme by default (GitHub dark palette) with reactive light/dark toggle via `ValueNotifier`; theme switch updates all widgets instantly without hot reload.
* **Screen selector in AppBar** — tappable dropdown in AppBar title; title updates to reflect the selected screen route.
* **Jank frame counter** — counts frames where `buildDuration + rasterDuration > 16.67ms`; displayed as `⚡N` pill in the overlay and a JANK pill in the metrics bar.
* **Response payload size tracking** — reads `content-length` header or falls back to string body length; shown in the API log tile and section header summary (`N calls · XX.XKB · NNNms`).
* **Flutter/Dart runtime error capture** — hooks `FlutterError.onError` and `PlatformDispatcher.instance.onError`; stores up to 50 errors with type badge (`FLUTTER`/`DART`), timestamp, message, and expandable stack trace (first 20 lines).
* **RAM history chart** — per-screen RAM chart (pink) with Avg/Min/Max stat cards and Y-axis; collapsible alongside the FPS history chart.
* **API log filter bar** — chips to filter by ALL / SLOW / ERR / GET / POST; chips only appear when their count > 0.
* **API / ERRORS tab toggle** — switch between API call list and Flutter error list within the dashboard.
* Fixed: overlay dashboard button now hides reactively when already on `MonitorDashboardPage` (moved check inside `ListenableBuilder`).
* Fixed: `CustomPainter` canvases (FPS and RAM charts) now repaint on theme toggle (`isDark` added to `shouldRepaint`).
* Fixed: `const _HBorder()` now creates a new instance per build to prevent Flutter's const-identity optimization from skipping theme color updates.

## 1.0.1

* Add complete README with setup guide and API reference.
* Add example app demonstrating all features.

## 1.0.0

* Initial release.
* Floating overlay showing FPS, RAM, and disk usage.
* Full developer dashboard with API log, FPS chart, and hardware metrics.
* Dio interceptor for automatic API call tracking.
* Navigator observer for route tracking.
* Framework-agnostic: works with GetX, Provider, Riverpod, or plain Flutter.
