## 1.3.0

* **Full response body**: removed all truncation limits — response data (arrays, maps, strings) now displayed in full regardless of size.
* **Route arguments tracking**: `RouteLogItem` now captures `route.settings.arguments` (JSON-encoded for Map/List, toString otherwise). Shown as an expandable `arguments ▾` row in the ROUTES tab tile.
* **Network ping**: live TCP ping to `1.1.1.1:80`, refreshed every 5 s. Displayed as `NET Xms` in the FpsOverlay pill (3rd row) and as a `NET` metric row in the details panel. Color-coded: green < 50 ms, yellow < 150 ms, red ≥ 150 ms.
* **`DevMonitor.tapToToggle`**: wrap any widget with a secret N-tap trigger (default 7) to toggle the overlay. Optional `clipboardKey` is copied to the clipboard on each trigger — useful as a passphrase for testers. Overlay is now visible by default (`isShowing: true`).
* **`MonitorTextStyle` + text widgets**: added `MonitorTextStyle.mono/label/body` factories and `MonoText`, `LabelText`, `BodyText` widgets (exported publicly) — applied across all UI files to eliminate repeated `TextStyle` boilerplate.
* **`_ScreenPickerSheet` redesign**: card-style items with left accent border for selected screen, numeric index badge (1 = newest), route name split into screen title + sub-path, count badge. Screens ordered newest-first.
* **Small-screen layout fixes**: `MetricsBar` split into two rows (INIT+ACTION / ERRORS+JANK+RAM); screen name in tab header wrapped in `Flexible`; section summary text ellipsis; `_HardwareStat` value overflow ellipsis.
* **FpsOverlay navigation**: long-press on pill opens `MonitorDashboardPage` directly; opening dashboard from details panel collapses overlay to pill; guard prevents opening a duplicate dashboard when already on that page.

## 1.2.0

* **API log — tabbed expanded view** (TIMELINE | REQUEST | RESPONSE | HEADERS): interceptor now captures query params, request/response headers, and bodies (pretty-printed JSON, capped to prevent OOM). `url` changed to full URI via `options.uri.toString()`.
* **Copy actions**: cURL generation (`>_ Copy cURL` chip in REQUEST tab), per-section inline copy buttons for URL/params/headers, copy-all bottom sheet (`⧉` button in tile tab bar) listing every copyable item.
* **LOCAL tab** (`DevMonitor.trackLocal` / `DevMonitor.trackSingleton`): log reads from SharedPreferences, Hive, SQLite, SecureStorage, or any in-memory singleton. `value` accepts `dynamic` (Map/List auto-serialized to indented JSON). Tiles expand to show full JSON with copy button.
* **Dashboard scroll**: `NestedScrollView` — hardware grid + charts collapse when scrolling the log list; MetricsBar + TabHeader + FilterBar stay pinned.
* **Light/dark theme persistence** via native channels (Android `SharedPreferences`, iOS `UserDefaults`) — no external package required. Theme restores automatically on app restart without any `init()` call in `main()`.
* **Overlay `_DetailsPanel` theme-aware**: follows light/dark toggle via merged `Listenable`; light mode uses slate palette with shadow for panel depth; metric accent colors darkened for readability on light backgrounds. Restored physical screen resolution (`physW×physH`) to device info row.
* **Example app**: added `ApiLabScreen` with 9 API test cases (GET with query params, POST with body, PUT, PATCH, DELETE, 404) and `LocalLabScreen` with mock `AppState` / `AuthService` singletons plus simulated SharedPreferences, Hive, and SQLite reads.
* Fixed: `ApiLogController` was dropping captured fields (headers, body, params) when creating new log entries — all fields now propagated correctly.
* Fixed: `Container(color + decoration)` assertion crash when expanding API log tiles.
* Fixed: `_SparklinePainter` and chart painters now include `isDark` in `shouldRepaint` to force canvas redraw on theme toggle.

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
