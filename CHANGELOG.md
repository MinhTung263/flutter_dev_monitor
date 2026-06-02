## 1.1.1

* **RAM chart auto-scale** — chart Y-axis now scales to actual app usage (ceiling = `maxVal × 1.4`, min 256 MB) instead of total device RAM; fixes chart appearing flat near zero on devices with 8+ GB RAM.
* **RAM pill in metrics bar** — added live RAM usage pill (`currentRam`) alongside ERRORS and JANK; turns red when usage exceeds 80% of device RAM.
* **RAM chart stat cards** — added second row with USAGE (current % of device RAM) and DEVICE (total device RAM in GB) below the existing Avg/Min/Max cards.
* **Overlay panel compact** — reduced `_DetailsPanel` height by ~50px: device info merged into one row, metric font/spacing tightened, sparkline reduced to 28px; fixes overflow on small screens (iPhone SE etc.).

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
