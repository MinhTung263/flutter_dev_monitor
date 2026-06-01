# UI Reference — flutter_dev_monitor

A screen-by-screen breakdown of every visible element and what it measures.

---

## 1. Floating HUD Overlay

The overlay is injected automatically by `DevMonitor.appBuilder`. It sits on top of the entire app and can be dragged to any position. Tap to expand, tap **×** to collapse.

### 1.1 Collapsed — Pill Badge

A compact pill shown at all times when the overlay is visible.

| Element | What it shows |
|---|---|
| **Colored dot** | Green when FPS ≥ 50. Orange/red when FPS < 50 (jank detected). |
| **`XX.X fps`** | Current frame rate, averaged over the last ~90 vsync timestamps. Calculated as `(frames − 1) × 1,000,000 / spanMicroseconds`. |
| **`⚡N`** (orange, only when > 0) | Cumulative jank frame count since the last clear. A frame is jank when `buildDuration + rasterDuration > 16.67 ms` (60 fps budget). |
| **`API N`** | Number of API calls logged in the current phase (INIT or ACTION) of the current screen. |
| **`Mem XXX M`** | App process RAM usage in MB, polled every 3 seconds via a native `MethodChannel`. |

### 1.2 Expanded — Details Panel

Tap the pill to expand into a 210 px wide panel with a sidebar of action buttons.

#### Device info row
| Element | What it shows |
|---|---|
| **Device name** | Model name from the native channel (e.g. `iPhone 15 Pro`, `Pixel 7`). |
| **`[WWWxHHH]`** | Physical screen resolution in pixels (logical size × device pixel ratio). |
| **OS version** | Platform version string (e.g. `iOS 17.4`, `Android 14`). |
| **`X.Xx  NNHz`** | Device pixel ratio and display refresh rate (`View.of(context).display.refreshRate`). |

#### Metric rows
| Label | Value | Range bracket |
|---|---|---|
| **Pre** | Average build phase duration in ms (`FrameTiming.buildDuration`). | `[min max]` over recent samples. |
| **GPU** | Average rasterization duration in ms (`FrameTiming.rasterDuration`). | `[min max]` over recent samples. |
| **Mem** | Current RAM in MB (same as pill). | — |
| **API** | Current-phase API call count (same as pill). | — |
| **FPS** | Current FPS (same as pill). | `[min max]` over recent samples. |

> **Pre** = the Flutter framework build step (widget tree diff + layout). **GPU** = time to rasterize that frame on the GPU. Both should stay well under 8 ms each on a 60 Hz device.

#### Sparkline chart

A 34 px tall mini-chart drawn with `CustomPainter`.

| Series | Color | Scale |
|---|---|---|
| **FPS** (green, filled area) | `#4ADE80` | 0 – device max Hz |
| **GPU ms** (orange, line) | `#FB923C` | 0 – 33.3 ms |

A faint horizontal reference line marks the 60 fps level.

#### Action buttons (sidebar)

| Button | Action |
|---|---|
| **×** (close) | Collapse the panel back to the pill. |
| **⛶** (expand/dashboard) | Opens `MonitorDashboardPage` for the current route. Hidden when already on the dashboard. |
| **🧹** (clear, red) | Calls `MonitorController.clearAll()` — resets all API logs, FPS history, RAM history, jank count, and error logs. |

---

## 2. Dashboard Page (`MonitorDashboardPage`)

Accessible by pushing the route `/MonitorDashboardPage`. Requires `initialScreen` — the route name to pre-select.

### 2.1 App Bar

| Element | Action |
|---|---|
| **IN-APP MONITOR** title | Static label. |
| **↺ (red restart icon)** | Clears all data (`clearAll` + `clearOverlayHistory`) and resets screen selection to `/unknown`. |

---

### 2.2 Screen Selector

Dropdown row at the top of the header.

| Element | What it shows |
|---|---|
| **Route name** | Currently selected route (e.g. `/HomeScreen`). Tap to open the picker sheet. |
| **Screen picker bottom sheet** | Lists every route that has recorded at least one FPS sample. Selecting a route refreshes all charts and logs for that screen. |

> Data is scoped per screen. Switching screens shows only the FPS history, RAM history, and API calls that happened while that screen was in the foreground.

---

### 2.3 Hardware Grid

Two side-by-side stat bars, updated every 3 seconds.

| Stat | Value | Progress bar |
|---|---|---|
| **RAM** | `used MB / total MB` — RAM consumed by the app process out of total device RAM. | Cyan. Turns **red** when usage > 80 % of total. |
| **STORAGE** | App sandbox disk usage in MB. | Purple. Turns **red** at 500 MB (warning ceiling). |

---

### 2.4 FPS History Chart (collapsible)

Tap the **FPS HISTORY** header to expand or collapse.

| Element | What it shows |
|---|---|
| **Sample count** | How many FPS readings have been recorded for the selected screen. |
| **Chart** | FPS value over time (newest on the right). Green line + fill. Y-axis: 0 – device max Hz. A dashed 60 fps reference line is drawn. Red dots mark frames below 30 fps. |

---

### 2.5 RAM History Chart (collapsible, pink)

Tap the **RAM HISTORY** header to expand or collapse. Collapsed by default.

| Element | What it shows |
|---|---|
| **Sample count** | Number of RAM snapshots for the selected screen. |
| **Avg card** | Average RAM usage (MB) across all samples. |
| **Min card** | Minimum RAM reading. |
| **Max card** | Maximum RAM reading. Turns **red** when `max > 80 %` of total device RAM. |
| **Area chart** | RAM over time (newest on the right). Pink line + gradient fill. |
| **Y-axis** | Top label = chart ceiling (either `totalRam` or `1.4 × max`). Mid label = half of ceiling, with `/totalRam` appended when known. Bottom = `0M`. |

---

### 2.6 Metrics Bar

Four pills summarizing the current screen's session at a glance.

| Pill | Color | What it shows |
|---|---|---|
| **INIT** | Blue | Total accumulated duration (ms) of all INIT-phase API calls on the selected screen. Shows `-- ` when no init calls exist. Badge shows call count. |
| **ACTION** | Green | Total accumulated duration (ms) of all ACTION/refresh-phase API calls. Shows `--` when none. Badge shows call count. |
| **ERRORS** | Red (when > 0) / grey | Count of API calls that returned a non-2xx status code. |
| **JANK** | Orange (when > 0) / grey | Cumulative jank frame count (same counter as the `⚡` in the pill). Resets on clear. |

---

### 2.7 Log Tab Header

Toggles the log list between two modes.

| Tab | Color | What it shows |
|---|---|---|
| **API** | Blue | All captured Dio requests for the selected screen. Badge = total call count. |
| **ERRORS** | Red | Flutter/Dart runtime errors captured via `FlutterError.onError` and `PlatformDispatcher.instance.onError`. Badge = error count. |

The current screen route is shown right-aligned in the same row for reference.

---

### 2.8 Filter Bar (API tab only)

A horizontally scrollable row of chips. Chips only appear when their count is > 0 (except ALL).

| Chip | Filter |
|---|---|
| **ALL** | Every call on the screen. Always visible. |
| **SLOW** | Calls flagged as slow (duration > threshold defined in `ApiLogItem.isSlow`). |
| **ERR** | Calls with a non-2xx HTTP status. |
| **GET** | GET method calls only. |
| **POST** | POST method calls only. |

Switching screens resets the filter back to **ALL**.

---

### 2.9 API Log List

Calls are grouped under section headers, then listed newest-last within each group.

#### Section header (`INIT` / `ACTION #N`)

| Element | What it shows |
|---|---|
| **Label** | `INIT` for the initial page-load phase. `ACTION #N` for the Nth refresh/action cycle. |
| **Summary** | `N calls · XX.XKB · NNNms` — total call count, total response payload size, and total duration for that group. Size is omitted when no `content-length` or string body was available. |

#### API log tile (collapsed)

| Element | What it shows |
|---|---|
| **`#N` badge** (grey) | Sequential order number within the current screen session. |
| **`INIT` / `REFRESH` badge** | Phase badge — blue for init, purple for refresh. |
| **`×N` badge** (amber, only when > 1) | How many times this exact request was called (deduplication count). |
| **`GET` / `POST` badge** | HTTP method. |
| **`NNNms`** | Total round-trip duration. |
| **`⚠ SLOW`** (orange, below duration) | Shown when the call exceeds the slow threshold. |
| **URL** | Full request URL (selectable). |
| **Caller name** | The Dart function/method that initiated the call, extracted by the interceptor's stack trace. |

#### API log tile (expanded — Execution Timeline)

Tap any tile to reveal the timeline.

| Step | What it shows |
|---|---|
| **Request Sent** | Timestamp when the request left the device (`HH:MM:SS`). |
| **Server Processing** | `+NNNms` — network + backend time. Orange when slow. |
| **Payload Response** | `HTTP NNN — XX.XKB` when size is known, otherwise `HTTP NNN — Data synchronized.` |
| **Slow banner** | Shown at the top of the expanded panel when `isSlow = true`. Displays `Operation took X.XXs — risk of UI jank.` |
| **Footer** | Screen route · phase, and the caller function name (selectable). |

---

### 2.10 Error Log List (ERRORS tab)

Captures unhandled Flutter widget errors and uncaught Dart exceptions. Max 50 errors stored; oldest are dropped.

#### Error log tile (collapsed)

| Element | What it shows |
|---|---|
| **`#N` badge** | Sequential error ID (increments globally, never resets within a session). |
| **`FLUTTER` / `DART` badge** | Source type. `FLUTTER` = caught by `FlutterError.onError` (widget tree errors). `DART` = caught by `PlatformDispatcher.instance.onError` (uncaught async/isolate exceptions). |
| **Timestamp** | `HH:MM:SS` when the error was caught. |
| **Error message** | Exception message, up to 2 lines when collapsed. |

#### Error log tile (expanded)

Tap to reveal the full stack trace — first 20 lines, selectable text.

---

## 3. Data Lifecycle

| Event | Effect |
|---|---|
| Navigate to a new screen | `startSession(route)` is called. FPS history, RAM history, and API logs accumulate under that route key. |
| Navigate back (pop) | Session data is **not** cleared automatically. It remains visible in the dashboard under that route. |
| Tap **🧹** in the overlay | Clears everything: API logs, FPS, RAM, jank count, error logs, overlay sparkline history. |
| Tap **↺** in the dashboard app bar | Same as the clear button. Also resets the screen selector to `/unknown`. |
| Screen has no data | Charts show "No data for this screen". Log list shows the empty state. |
