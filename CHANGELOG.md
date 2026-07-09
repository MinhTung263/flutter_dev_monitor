## 2.3.1

* **Broaden SDK Compatibility**: Downgraded Dart SDK constraint to `>=3.0.0 <4.0.0` (matching Flutter versions from 2023 and 2024 onwards) and renamed duplicate wildcard parameters to avoid analyzer errors on older Dart versions.

## 2.3.0

* **Fix Offline Boot Hang**: Shlipped native storage scans to background threads (JVM Thread on Android, GCD queue on iOS), isolated ping sockets inside a background `Isolate.run` with 2-second timeout, and delayed monitoring controllers to prevent splash screen freezes when offline.
* **Default Light Mode Theme**: Configured the performance console dashboard and overlay HUD to start in light mode by default.
* **Example App Premium Redesign**: Restructured the single-file codebase into a clean modular package under `screens/` and `services/`, and redesigned all views featuring macOS-style virtual console outputs, colored method badge cards, and pixel alignment blueprints.
* **Updated pub.dev Screenshots**: Updated all 6 store screenshots with generic clean status bar configurations.

## 2.2.1

* **API Search Bar**: Added a search bar in the API tab to filter logs by URL, method, or status code.
* **FormData & Binary Payload Support**: Added detailed formatting for `FormData` payloads (showing fields and file metadata like filename, length, and content type) and custom labels for `Uint8List` and `Stream` data.
* **Custom AppBar Title Extraction**: Fixed auto-captured screen names when using custom AppBar wrappers (e.g. `BaseAppBar` with `AppText.title`) by recursively searching the title's element subtree for `Text` or `RichText` widgets.

## 2.2.0

* **Auto-captured Screen Names**: Dynamic runtime extraction of `AppBar.title` (if it's a `Text` widget) using Element tree post-frame traversal in `MonitorNavigatorObserver`, mapping route paths to user-friendly titles automatically. Fallback formatting converts camelCase/underscores and path variables (e.g. `/post_detail/123` ➔ `Post Detail (/123)`).
* **All Screens Filter**: Added "ALL" option in the screen route picker, merging logs, global RAM/FPS histories, and aggregate counts chronologically.
* **FPS Overlay Alerting & HUD Warning**: Visual indicators (blinking red/orange borders, exclamation warning badge `!`, and detailed inline error/slow API counts) on `FpsOverlay` when any screen encounters an API error, slow request, or uncaught exception. Automatically resets when opening the dashboard.
* **Errors Route Filter**: Associated caught Flutter/Dart exceptions to active route names and filtered exception logs on the ERRORS tab by the active screen route.
* **Reordered Log Tabs**: Shifted the `ERRORS` tab to the middle (API ➔ ERRORS ➔ ROUTES) for faster developer access.
* **List Header & Order Badge Toggles**: Added a `_HeaderToggleButton` to show/hide group list headers (`OPEN #X`/`ACTION #Y`) and hide the order badge (`#X`) in API logs.

## 2.1.0

* **Widget Alignment Grid & Crosshairs**: Added layout alignment guides. Cycle through Off ➔ Margins (Safe Area 16px/24px) ➔ 8px Grid ➔ 16px Grid ➔ Center Crosshairs directly from FpsOverlay. High-contrast cyan/blue colors for visibility.
* **Copy Error Details**: Added inline copy button to error tiles in the dashboard to copy error message + stacktrace to clipboard.
* **Simulated Error Triggers in Example**: Added buttons in the example app to synchronously trigger Flutter UI errors or asynchronously trigger Dart errors.
* **Fix Overlay Re-opening & Route Restoring**: Fixed an issue where the overlay dashboard button became unresponsive after popping `/MonitorDashboardPage` because the route observer did not restore `currentRoute` when the previous route was unnamed.
* **Fix Rebuild Overlay State Resets**: Ensured that the `builder(showOverlay: false)` parameter preserves the user's runtime toggle state on rebuilds.
* **Fix API Grouping on Rapid On-Refresh**: Switched log grouping calculations to use Request Start Time instead of Response Arrival Time, preventing incorrect API counts when pulling pull-to-refresh quickly.

## 2.0.0

* **Major release** — consolidates all 1.x improvements into a stable, versioned API.
* Floating overlay: tap → open dashboard directly; long press → expand details panel.
* `DevMonitor.builder({bool showOverlay, bool expandedByDefault})` — configure initial overlay visibility and state.
* `DevMonitor.hideOverlay()` / `showOverlay()` / `toggleOverlay()` — runtime control.
* `DevMonitor.tapToToggle(...)` — secret N-tap trigger to toggle overlay.
* OPEN / ACTION phase detection with per-visit grouping and `#N` labels.
* MetricsBar shows per-screen stats for the selected dashboard screen.
* Chronological API list sort; FPS HISTORY collapsed by default.
* Consistent reset icon (`Icons.restart_alt`) across dashboard and overlay.
* pub.dev screenshots added.

## 1.3.9

* **`DevMonitor.builder(expandedByDefault)`**: new parameter to choose whether the overlay starts as the details panel (`true`) or the collapsed pill (`false`, default).

## 1.3.8

* **Tap overlay pill → open dashboard directly**: single tap now opens `MonitorDashboardPage`; long press expands the details panel.
* **Hide overlay permanently**: added X button (`Icons.close`) in the details panel that calls `DevMonitor.hideOverlay()` — overlay stays hidden until `DevMonitor.showOverlay()` is called. Collapses back to pill state when hidden.
* **Fixed ticker crash on re-show**: `SingleTickerProviderStateMixin` ticker is now stopped/started instead of disposed/recreated, preventing the "multiple tickers" assertion.
* **Consistent reset icon**: both dashboard AppBar and overlay panel now use `Icons.restart_alt` with `MonitorColors.statusError`.
* **FPS HISTORY collapsed by default**: chart starts collapsed to reduce visual noise on open.

## 1.3.7

* **`DevMonitor.builder({bool showOverlay})`**: new method replacing `appBuilder` — pass `showOverlay: false` to start the overlay hidden (e.g. production builds). `appBuilder` kept as a backwards-compatible alias.
* **Updated README**: documents `builder()`, overlay visibility controls, `tapToToggle`, and OPEN/ACTION phase terminology.

## 1.3.6

* Added pub.dev screenshots: dashboard (light & dark), home with charts, API Lab, and overlay pill.

## 1.3.5

* **Renamed INIT → OPEN**: all labels (`phaseInit`, MetricsBar, section headers, tile badges) now say `OPEN` — more accurate since it reflects APIs that ran when the screen was opened, not only `initState`.
* **Fixed phase mis-classification for delayed first API**: if the first API on a screen is triggered after `refreshGapMs` (e.g. user reads the screen then taps a button), it is now classified as `ACTION` instead of `OPEN`. Uses `_sessionStartTime` recorded at `startSession`.
* **Per-visit OPEN entries**: each navigation to a screen creates a new `OPEN #N` group in the API list instead of accumulating call counts across visits. Section headers show `OPEN #1`, `OPEN #2`, etc.
* **MetricsBar shows per-screen stats**: OPEN and ACTION metrics now always reflect the dashboard's selected screen, even when the app has navigated to a different screen in the background.
* **MetricsBar OPEN and ACTION both show latest occurrence only**: ACTION now shows the latest action cycle's stats (previously showed totals across all cycles), consistent with OPEN showing the latest visit. Label includes `#N` so the visit/action number is always visible.
* **MetricsBar reduced to one row**: removed redundant ERRORS and RAM pills (already visible in the tab header and hardware grid). Row now shows `OPEN · ACTION · JANK`.
* **Removed duplicate screen name from tab header**: screen name is already in the AppBar; the tab bar now shows only the API / ROUTES / ERRORS tabs.
* **Chronological API list sort**: API log list now sorts strictly by timestamp (newest first) across all OPEN and ACTION groups.

## 1.3.4

* **Fixed API phase mis-classification on re-navigation**: re-entering a screen (e.g. pressing back then forward) now correctly classifies its init APIs as INIT instead of ACTION. Root cause: `startSession` now always resets `_lastApiTime` and `_screenInRefreshMode` on entry, so the elapsed time since the previous visit no longer triggers the refresh-gap heuristic.
* **Fixed overlay showing stale API count after pop**: the `FpsOverlay` pill now immediately reflects the API count of the screen being returned to. `MonitorNavigatorObserver` calls `updateDashboardView` on `didPop` and `didRemove` so the count refreshes without waiting for the next API call.

## 1.3.3

* **Refactored `MonitorDashboardPage`**: split 1300-line file into 6 focused part files (`dashboard_header`, `log_tab_section`, `api_log_section`, `error_log_section`, `route_log_section`) using Dart `part`/`part of`.
* **Fixed API history lost on re-navigation**: `startSession` now uses `putIfAbsent` — logs are preserved when a screen is re-pushed via replace navigation (e.g. GetX `offNamed`). Data only clears on explicit user action.
* **LRU screen eviction**: `ApiLogController` now caps tracked screens at 50. When exceeded, the oldest screen's data is evicted automatically.
* **Removed `clearSessionByAnchor`**: auto-clearing on pop/replace is gone. Navigation no longer resets API history — data accumulates until the user taps the clear button.
* **Cleaned up `MonitorNavigatorObserver`**: removed `pageToSessionMap` and `_activeAnchor` fields.

## 1.3.2

* **`FpsOverlay` pill redesign**: more compact layout, colored mini-labels (API/MEM/NET), animated one-time "hold to open" hint fades in on first appearance.
* **Tap `_DetailsPanel` to collapse**: tapping anywhere on the expanded panel now collapses it back to the pill (in addition to the existing collapse button).
* **Removed route arguments tracking**: `RouteLogItem.arguments` and related encoding removed — custom Dart classes cannot be reliably serialized without a `toJson()` method, making the feature unreliable.
* **Fixed `startSession` data wipe**: API logs are now preserved when a screen is re-pushed (e.g. via GetX `offNamed`/replace navigation). Data is only cleared when the user explicitly taps the clear button.

## 1.3.1

* Fixed repository URL in pubspec.yaml (was `tunglv`, now `MinhTung263`).

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
