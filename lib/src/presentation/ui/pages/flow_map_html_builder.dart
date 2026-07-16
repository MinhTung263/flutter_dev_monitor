import 'dart:convert';

/// Generates a complete, self-contained interactive HTML page for the
/// DevMonitor Flow Map. Pass the JSON-encoded map data as [jsonData].
String buildFlowMapHtml({required String jsonData}) {
  String staticPaths = '';
  String staticCards = '';
  String staticDetails = '';
  String workspaceTransform =
      'transform: translate3d(100px, 100px, 0px) scale(0.8);';

  try {
    final Map<String, dynamic> data = jsonDecode(jsonData);
    final List<dynamic> nodes = data['nodes'] ?? [];
    final List<dynamic> transitions = data['transitions'] ?? [];

    if (nodes.isNotEmpty) {
      double minX = double.infinity;
      double maxX = -double.infinity;
      double minY = double.infinity;
      double maxY = -double.infinity;

      String staticDetailsList = '';

      for (final n in nodes) {
        final x = (n['x'] as num).toDouble();
        final y = (n['y'] as num).toDouble();
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;

        final isPopup = (n['route'] as String).contains('dialog') ||
            (n['route'] as String).contains('bottomSheet');
        final typeText = isPopup ? 'popup' : 'page';
        final typeClass = isPopup ? 'dialog' : 'page';
        final isCurrent = n['isCurrent'] == true;
        final id = 'node-${(n['route'] as String).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

        final apis = n['apis'] as List<dynamic>? ?? [];
        final errors = n['errors'] as List<dynamic>? ?? [];

        int apiErrorCount = 0;
        for (final api in apis) {
          final sc = api['statusCode'] ?? 200;
          if (sc < 200 || sc >= 300) {
            apiErrorCount++;
          }
        }

        final bool hasSlow = apis.any((api) => api['isSlow'] == true);
        final bool hasIssue = hasSlow || errors.isNotEmpty || apiErrorCount > 0;

        final errClass = hasIssue ? ' error' : '';
        final cardClass = 'card${isCurrent ? ' active' : ''}$errClass';

        final apiErrBadge = apiErrorCount > 0
            ? '<span class="stat-badge error" title="API Errors">$apiErrorCount api err</span>'
            : '';
        final errBadge = errors.isNotEmpty
            ? '<span class="stat-badge error" title="Flutter Errors">${errors.length} err</span>'
            : '';

        // Make fallback cards clickable anchors to jump to details below
        staticCards += '''
      <a href="#details-$id" class="$cardClass" style="position: absolute; left: ${x}px; top: ${y}px; width: 180px; height: 65px; text-decoration: none; color: inherit;" id="$id">
        <div class="card-header-row">
          <span class="badge $typeClass">$typeText</span>
          <span class="card-title" title="${n['title']}">${n['title']}</span>
        </div>
        <div class="card-stats">
          <span class="stat-badge" title="Visits">${n['visitCount']} visits</span>
          <span class="stat-badge" title="API Requests">${apis.length} requests</span>
          $apiErrBadge
          $errBadge
        </div>
      </a>
''';

        // Pre-build details for this node
        String apisListHtml = '';
        if (apis.isEmpty) {
          apisListHtml =
              '<p style="font-size: 13px; color: #94a3b8; font-style: italic; margin: 4px 0;">Không có cuộc gọi API nào.</p>';
        } else {
          apisListHtml =
              '<div style="display: flex; flex-direction: column; gap: 8px;">';
          for (final api in apis) {
            final method = api['method'] ?? 'GET';
            final url = api['url'] ?? '';
            final statusCode = api['statusCode'] ?? 200;
            final duration = api['duration'] ?? 0;
            final methodColor = method == 'GET' ? '#10b981' : '#3b82f6';
            final statusColor = statusCode == 200 ? '#10b981' : '#ef4444';

            apisListHtml += '''
            <div style="font-size: 13px; padding: 8px; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 6px;">
              <span style="font-weight: bold; color: $methodColor;">$method</span>
              <code style="word-break: break-all; margin-left: 6px;">$url</code>
              <div style="margin-top: 4px; font-size: 11px; color: #64748b;">
                Status: <strong style="color: $statusColor;">$statusCode</strong> | Duration: ${duration}ms
              </div>
            </div>
''';
          }
          apisListHtml += '</div>';
        }

        String errorsListHtml = '';
        if (errors.isEmpty) {
          errorsListHtml =
              '<p style="font-size: 13px; color: #94a3b8; font-style: italic; margin: 4px 0;">Không ghi nhận lỗi nào.</p>';
        } else {
          errorsListHtml =
              '<div style="display: flex; flex-direction: column; gap: 8px;">';
          for (final err in errors) {
            final msg = err['message'] ?? '';
            final trace = err['stackTrace'] ?? '';
            errorsListHtml += '''
            <div style="font-size: 13px; padding: 8px; background: #fef2f2; border: 1px solid #fecaca; border-radius: 6px; color: #991b1b;">
              <strong>$msg</strong>
              <pre style="margin: 6px 0 0 0; font-family: monospace; font-size: 11px; overflow-x: auto; background: #ffffff; padding: 6px; border-radius: 4px; border: 1px solid #fecaca;">$trace</pre>
            </div>
''';
          }
          errorsListHtml += '</div>';
        }

        staticDetailsList += '''
<div id="details-$id" style="margin-bottom: 32px; padding: 16px; border-radius: 8px; background: #f8fafc; border: 1px solid #e2e8f0;">
  <h3 style="margin-top: 0; color: #0f172a; font-size: 16px; display: flex; align-items: center; gap: 8px;">
    <span style="background: #3b82f6; color: #ffffff; padding: 2px 8px; border-radius: 4px; font-size: 12px; text-transform: uppercase;">$typeText</span>
    ${n['title'].isEmpty ? n['route'] : n['title']}
  </h3>
  <p style="font-size: 13px; color: #64748b; margin: 4px 0 12px 0;">Đường dẫn: <code>${n['route']}</code> | Lượt truy cập: <strong>${n['visitCount']}</strong></p>
  
  <h4 style="font-size: 14px; color: #334155; margin: 12px 0 6px 0; border-bottom: 1px dashed #cbd5e1; padding-bottom: 4px;">API Requests (${apis.length})</h4>
  $apisListHtml
  
  <h4 style="font-size: 14px; color: #334155; margin: 16px 0 6px 0; border-bottom: 1px dashed #cbd5e1; padding-bottom: 4px;">Lỗi Flutter (${errors.length})</h4>
  $errorsListHtml
</div>
''';
      }

      staticDetails = '''
<div class="static-details-container" style="max-width: 800px; margin: 40px auto; padding: 24px; font-family: sans-serif; background: #ffffff; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); border: 1px solid #e2e8f0;">
  <h2 style="margin-top: 0; color: #1e293b; border-bottom: 2px solid #3b82f6; padding-bottom: 8px;">Chi tiết lịch sử các màn hình</h2>
  <p style="color: #64748b; font-size: 14px; margin-bottom: 24px;">(Danh sách chi tiết cuộc gọi API và lỗi khi xem ở chế độ xem trước ngoại tuyến/Quick Look - Bấm vào các thẻ trên sơ đồ để nhảy nhanh tới chi tiết)</p>
  $staticDetailsList
</div>
''';

      final contentW = (maxX - minX) + 180.0;
      final contentH = (maxY - minY) + 65.0;
      final cx = minX + contentW / 2;
      final cy = minY + contentH / 2;

      final vpW = 500.0;
      final vpH = 700.0;
      final scaleX = vpW / (contentW + 100);
      final scaleY = vpH / (contentH + 100);
      double scale = (scaleX < scaleY ? scaleX : scaleY);
      if (scale > 1.0) scale = 1.0;
      if (scale < 0.15) scale = 0.15;

      final tx = vpW / 2 - cx * scale;
      final ty = vpH / 2 - cy * scale;

      workspaceTransform =
          'transform: translate3d(${tx.toStringAsFixed(1)}px, ${ty.toStringAsFixed(1)}px, 0px) scale(${scale.toStringAsFixed(3)});';

      for (final t in transitions) {
        final fromNode = nodes.firstWhere((n) => n['route'] == t['from'],
            orElse: () => null);
        final toNode =
            nodes.firstWhere((n) => n['route'] == t['to'], orElse: () => null);
        if (fromNode != null && toNode != null) {
          final fromX = (fromNode['x'] as num).toDouble() + 90.0;
          final fromY = (fromNode['y'] as num).toDouble() + 65.0;
          final toX = (toNode['x'] as num).toDouble() + 90.0;
          final toY = (toNode['y'] as num).toDouble();

          final isBack = t['isBack'] == true;
          String d;
          if (isBack) {
            final midX = (fromX + toX) / 2 - 80.0;
            final midY = (fromY + toY) / 2;
            d = 'M $fromX $fromY Q $midX $midY $toX $toY';
          } else {
            final midY = (fromY + toY) / 2;
            d = 'M $fromX $fromY C $fromX $midY, $toX $midY, $toX $toY';
          }

          final stroke = isBack ? '#ff9800' : '#2196f3';
          final marker = isBack ? 'url(#arrow-orange)' : 'url(#arrow-blue)';

          staticPaths += '''
        <path d="$d" fill="none" stroke="$stroke" stroke-width="2" marker-end="$marker" />
''';
        }
      }
    }
  } catch (_) {}

  final prefix = _kHtmlPrefix
      .replaceFirst(
          'id="workspace"', 'id="workspace" style="$workspaceTransform"')
      .replaceFirst('<!-- STATIC_PATHS -->', staticPaths)
      .replaceFirst('<!-- STATIC_CARDS -->', staticCards);

  return (prefix + jsonData + _kHtmlSuffix)
      .replaceFirst('<!-- STATIC_DETAILS -->', staticDetails);
}

// ──────────────────────────────────────────────────────
const String _kHtmlPrefix = '''<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes, viewport-fit=cover">
  <title>DevMonitor - Sơ đồ luồng tương tác</title>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Fira+Code:wght@400;500&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg-color: #f4f6f9;
      --surface-color: #ffffff;
      --card-bg: #ffffff;
      --border-color: #dce1ea;
      --text-color: #1a1d23;
      --text-secondary: #6b7280;
      --primary: #4f8ef7;
      --accent: #f97316;
      --success: #22c55e;
      --danger: #ef4444;
      --divider: rgba(0, 0, 0, 0.07);
    }
    
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }
    
    html, body {
      font-family: 'Inter', sans-serif;
      background-color: var(--bg-color);
      color: var(--text-color);
      width: 100%;
      margin: 0;
      padding: 0;
      overflow-x: auto;
      overflow-y: auto;
    }
    
    #container {
      width: 100%;
      height: 100vh;
      height: 100dvh;
      position: relative;
      cursor: grab;
      overflow: auto; /* Allow scrollbars if JS is disabled */
      background-image: radial-gradient(rgba(0, 0, 0, 0.1) 1px, transparent 1px);
      background-size: 20px 20px;
      -webkit-overflow-scrolling: touch;
    }
    
    #container:active {
      cursor: grabbing;
    }
    
    #workspace {
      width: 3200px;
      height: 2400px;
      position: absolute;
      top: 0;
      left: 0;
      transform-origin: 0 0;
      overflow: visible;
    }

    /* By default, show static details for non-JS viewers */
    .static-details-container {
      display: none !important; /* hide in Quick Look; map must be opened in browser */
    }

    /* Hide static details when JS is enabled */
    body.js-enabled .static-details-container {
      display: none !important;
    }

    /* By default, show static warning banner */
    .quick-look-warning {
      display: flex !important;
    }

    /* Hide warning banner when JS is enabled */
    body.js-enabled .quick-look-warning {
      display: none !important;
    }
    
    .toolbar {
      position: fixed;
      top: max(16px, env(safe-area-inset-top));
      left: max(16px, env(safe-area-inset-left));
      z-index: 100;
      display: flex;
      gap: 12px;
    }
    /* Hide toolbar when JavaScript is disabled (Quick Look) */
    body:not(.js-enabled) .toolbar { display: none !important; }
    /* Hide startup hint when JavaScript is enabled (browser) */
    body.js-enabled #startup-hint { display: none !important; }
    
    .search-box {
      background: var(--surface-color);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      padding: 8px 16px;
      display: flex;
      align-items: center;
      gap: 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    }
    
    .search-box input {
      background: transparent;
      border: none;
      color: var(--text-color);
      font-size: 14px;
      outline: none;
      width: 220px;
    }
    
    .btn {
      background: var(--surface-color);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      padding: 8px 12px;
      color: var(--text-color);
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
      transition: background 0.2s, border-color 0.2s;
    }
    
    .btn:hover {
      background: var(--card-bg);
      border-color: var(--primary);
    }
    
    .card {
      position: absolute;
      width: 180px;
      height: 65px;
      background: var(--card-bg);
      border: 1px solid var(--border-color);
      border-radius: 8px;
      padding: 8px;
      cursor: pointer;
      user-select: none;
      box-shadow: 0 2px 8px rgba(0,0,0,0.08);
      transition: box-shadow 0.2s, border-color 0.2s;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
    }
    
    .card:hover {
      box-shadow: 0 4px 14px rgba(79, 142, 247, 0.25);
      border-color: var(--primary);
    }
    
    .card.active {
      border: 2px solid var(--success);
    }
    .card.error {
      border: 2px solid var(--danger);
    }

    .card-header-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 4px;
    }

    .badge {
      font-size: 8px;
      font-weight: 700;
      padding: 2px 4px;
      border-radius: 4px;
      text-transform: uppercase;
      white-space: nowrap;
    }

    .badge.page {
      background: rgba(79, 142, 247, 0.12);
      color: var(--primary);
    }

    .badge.dialog {
      background: rgba(249, 115, 22, 0.12);
      color: var(--accent);
    }

    .card-title {
      font-size: 11px;
      font-weight: 600;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      color: var(--text-color);
      flex: 1;
    }

    .card-stats {
      display: flex;
      justify-content: flex-start;
      gap: 4px;
      flex-wrap: wrap;
      font-size: 9px;
      color: var(--text-secondary);
    }

    .stat-badge {
      padding: 1px 4px;
      border-radius: 4px;
      background: rgba(255,255,255,0.05);
    }

    .stat-badge.error {
      background: rgba(243, 139, 168, 0.15);
      color: var(--danger);
    }

    .slow-apis {
      font-size: 8px;
      color: var(--danger);
      margin-top: 4px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    
    .modal {
      display: none;
      position: fixed;
      top: 0;
      right: 0;
      width: 550px;
      height: 100%;
      background: var(--surface-color);
      border-left: 1px solid var(--border-color);
      box-shadow: -8px 0 24px rgba(0,0,0,0.12);
      z-index: 1000;
      flex-direction: column;
      animation: slideIn 0.3s cubic-bezier(0.16, 1, 0.3, 1);
    }
    
    @keyframes slideIn {
      from { transform: translateX(100%); }
      to { transform: translateX(0); }
    }
    
    .modal-header {
      padding: 20px;
      border-bottom: 1px solid var(--divider);
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .modal-title {
      font-size: 16px;
      font-weight: 700;
      color: var(--text-color);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      max-width: 80%;
    }
    
    .close-btn {
      background: transparent;
      border: none;
      color: var(--text-secondary);
      font-size: 24px;
      cursor: pointer;
    }
    
    .tab-bar {
      display: flex;
      border-bottom: 1px solid var(--divider);
      background: rgba(0,0,0,0.03);
    }
    
    .tab-btn {
      flex: 1;
      padding: 14px;
      background: transparent;
      border: none;
      color: var(--text-secondary);
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      text-align: center;
      transition: color 0.2s, background 0.2s;
    }
    
    .tab-btn.active {
      color: var(--primary);
      border-bottom: 2px solid var(--primary);
      background: rgba(255,255,255,0.02);
    }
    
    .modal-body {
      flex: 1;
      overflow-y: auto;
      padding: 20px;
    }

    .tab-content {
      display: none;
    }

    .tab-content.active {
      display: block;
    }
    
    .log-item {
      background: var(--card-bg);
      border: 1px solid var(--border-color);
      border-radius: 8px;
      margin-bottom: 12px;
      overflow: hidden;
    }
    
    .log-header {
      padding: 12px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      user-select: none;
    }
    
    .log-header:hover {
      background: rgba(255,255,255,0.02);
    }

    .log-meta-left {
      display: flex;
      align-items: center;
      gap: 8px;
      flex: 1;
      min-width: 0;
    }

    .method-badge {
      font-size: 10px;
      font-weight: 700;
      padding: 4px 6px;
      border-radius: 4px;
      min-width: 48px;
      text-align: center;
    }

    .method-badge.GET { background: rgba(166, 227, 161, 0.15); color: var(--success); }
    .method-badge.POST { background: rgba(137, 180, 250, 0.15); color: var(--primary); }
    .method-badge.PUT { background: rgba(250, 179, 135, 0.15); color: var(--accent); }
    .method-badge.DELETE { background: rgba(243, 139, 168, 0.15); color: var(--danger); }

    .status-badge {
      font-size: 10px;
      font-weight: 700;
      padding: 4px 6px;
      border-radius: 4px;
    }
    .status-badge.success { background: rgba(34, 197, 94, 0.12); color: var(--success); }
    .status-badge.error { background: rgba(239, 68, 68, 0.12); color: var(--danger); }

    .log-url {
      font-size: 12px;
      font-weight: 500;
      color: var(--text-color);
      word-break: break-all;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      flex: 1;
    }

    .log-duration {
      font-size: 11px;
      color: var(--text-secondary);
      white-space: nowrap;
    }
    
    .log-details {
      display: none;
      padding: 16px;
      border-top: 1px solid var(--divider);
      background: rgba(0,0,0,0.03);
    }
    
    .section-title {
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
      color: var(--text-secondary);
      margin: 12px 0 6px 0;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .copy-btn {
      font-size: 10px;
      color: var(--primary);
      background: transparent;
      border: none;
      cursor: pointer;
    }
    
    pre {
      background: #f0f4f8;
      color: #1a1d23;
      padding: 12px;
      border-radius: 6px;
      font-family: 'Fira Code', monospace;
      font-size: 11px;
      overflow-x: auto;
      border: 1px solid var(--border-color);
      white-space: pre-wrap;
      word-break: break-all;
    }

    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 11px;
      margin-bottom: 12px;
    }

    td {
      padding: 6px;
      border-bottom: 1px solid var(--divider);
      word-break: break-all;
    }

    td.key {
      color: var(--text-secondary);
      width: 30%;
      font-weight: 500;
    }
    .layout-selector {
      display: flex;
      background: var(--surface-color);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }

    .layout-btn {
      background: transparent;
      border: none;
      padding: 7px 12px;
      cursor: pointer;
      font-size: 11px;
      font-weight: 600;
      color: var(--text-secondary);
      transition: background 0.2s, color 0.2s;
      white-space: nowrap;
    }

    .layout-btn.active {
      background: var(--primary);
      color: #fff;
    }

    .layout-btn:not(.active):hover {
      background: rgba(0,0,0,0.05);
      color: var(--text-color);
    }
    /* Mini Map – hidden by default, shown only when JavaScript runs */
    #minimap-container {
      display: none; /* hide in Quick Look where JS is off */
    }
    body.js-enabled #minimap-container {
      display: block; /* show when JS is enabled */
      position: fixed;
      bottom: 20px;
      right: 20px;
      z-index: 400;
      background: var(--surface-color);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      box-shadow: 0 4px 16px rgba(0,0,0,0.12);
      overflow: hidden;
      transition: opacity 0.2s;
    }
    body.js-enabled #minimap-container:hover { opacity: 1 !important; }

    #minimap-canvas {
      display: block;
      cursor: crosshair;
    }
  </style>
</head>
<body>
  <div id="container">


    <div class="toolbar">
      <div class="search-box">
        <input type="text" id="search-input" placeholder="Tìm màn hình..." oninput="searchNodes(this.value)">
      </div>
      <div class="layout-selector" id="layout-selector">
        <button class="layout-btn active" id="layout-btn-tree" onclick="applyLayout('tree')" title="Dạng cây">Tree</button>
        <button class="layout-btn" id="layout-btn-grid" onclick="applyLayout('grid')" title="Dạng lưới">Grid</button>
        <button class="layout-btn" id="layout-btn-stream" onclick="applyLayout('stream')" title="Dạng dòng">Stream</button>
        <button class="layout-btn" id="layout-btn-circle" onclick="applyLayout('circle')" title="Dạng vòng tròn">Circle</button>
      </div>
      <button class="btn" onclick="recenterWorkspace()" title="Định vị lại tâm bản đồ">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="10"></circle>
          <circle cx="12" cy="12" r="3"></circle>
          <line x1="12" y1="1" x2="12" y2="3"></line>
          <line x1="12" y1="21" x2="12" y2="23"></line>
          <line x1="1" y1="12" x2="3" y2="12"></line>
          <line x1="21" y1="12" x2="23" y2="12"></line>
        </svg>
      </button>
    </div>
    <!-- Startup hint overlay for iOS Quick Look users -->
    <div id="startup-hint" style="position:fixed; bottom:24px; left:50%; transform:translateX(-50%); z-index:500; background:#fff; border:1px solid #dce1ea; border-radius:16px; padding:14px 20px; box-shadow:0 4px 20px rgba(0,0,0,0.15); display:flex; align-items:center; gap:12px; font-family:Inter,sans-serif;">
      <span style="font-size:13px; color:#1a1d23; font-weight:500;">Không thấy bản đồ?</span>
      <button onclick="recenterWorkspace(); document.getElementById('startup-hint').style.display='none';" style="background:#4f8ef7; color:#fff; border:none; border-radius:10px; padding:8px 16px; font-size:13px; font-weight:600; cursor:pointer;">Hiện bản đồ</button>
      <button onclick="document.getElementById('startup-hint').style.display='none';" style="background:transparent; border:none; color:#6b7280; font-size:18px; cursor:pointer; line-height:1;">×</button>
    </div>
    <!-- Mini Map -->
    <div id="minimap-container" style="opacity:0.85;">
      <canvas id="minimap-canvas" width="200" height="140"></canvas>
    </div>
    <div id="workspace">
      <svg id="svg-canvas" width="100%" height="100%" style="position:absolute; top:0; left:0; pointer-events:none; overflow:visible;">
        <defs>
          <marker id="arrow-blue" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
            <path d="M 0 2 L 8 5 L 0 8 z" fill="#2196f3"></path>
          </marker>
          <marker id="arrow-orange" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
            <path d="M 0 2 L 8 5 L 0 8 z" fill="#ff9800"></path>
          </marker>
        </defs>
        <!-- STATIC_PATHS -->
      </svg>
      <!-- STATIC_CARDS -->
    </div>
  </div>
  
  <div id="modal" class="modal">
    <div class="modal-header">
      <span id="modal-title" class="modal-title">Chi tiết màn hình</span>
      <button class="close-btn" onclick="closeModal()">&times;</button>
    </div>
    <div class="tab-bar">
      <button id="tab-apis" class="tab-btn active" onclick="switchTab('apis')">API Logs<span id="tab-apis-count"></span></button>
      <button id="tab-errors" class="tab-btn" onclick="switchTab('errors')">Lỗi Flutter<span id="tab-errors-count"></span></button>
    </div>
    <div class="modal-body">
      <div id="apis-list" class="tab-content active">
        <div style="margin-bottom: 12px;">
          <input type="text" id="api-search-input" placeholder="Tìm kiếm API (URL, Method, Status)..." oninput="filterModalApis(this.value)" style="width: 100%; background: var(--surface-color); border: 1px solid var(--border-color); border-radius: 8px; padding: 10px 14px; color: var(--text-color); outline: none; font-size: 13px;">
        </div>
        <div id="apis-list-inner"></div>
      </div>
      <div id="errors-list" class="tab-content"></div>
    </div>
  </div>

  <script id="map-data" type="application/json">''';

const String _kHtmlSuffix = '''</script>
  <script>
    // Flag body as js-enabled to hide static details fallback
    document.body.classList.add('js-enabled');
    document.body.style.overflow = 'hidden';
    document.documentElement.style.overflow = 'hidden';

    // Clear static pre-rendered fallback elements if JavaScript is enabled
    const workspace = document.getElementById('workspace');
    if (workspace) {
      const staticCards = workspace.querySelectorAll('.card');
      // Keep static cards for desktop browsers – they serve as links.
      // const svgCanvas = document.getElementById('svg-canvas');
      // if (svgCanvas) {
      //   const staticPaths = svgCanvas.querySelectorAll('path');
      //   // Keep static paths – they render connections.
      // }
    }

    // Disable native scrollbar overflow on container since custom pan/zoom is active
    const container = document.getElementById('container');
    if (container) {
      container.style.overflow = 'hidden';
    }
    
    const data = JSON.parse(document.getElementById('map-data').textContent);
    
    let scale = 0.8;
let globalViewportWidth = 0;
    let tx = 100;
    let ty = 100;
    let isDragging = false;
    let startX, startY;

    function updateTransform() {
      workspace.style.transform = "translate3d(" + tx + "px, " + ty + "px, 0px) scale(" + scale + ")";
      drawMinimap();
    }

    container.addEventListener('mousedown', (e) => {
      if (e.target.closest('.card') || e.target.closest('.modal')) return;
      isDragging = true;
      startX = e.clientX - tx;
      startY = e.clientY - ty;
    });

    container.addEventListener('mousemove', (e) => {
      if (!isDragging) return;
      tx = e.clientX - startX;
      ty = e.clientY - startY;
      updateTransform();
    });

    window.addEventListener('mouseup', () => {
      isDragging = false;
    });

    container.addEventListener('wheel', (e) => {
      e.preventDefault();
      const zoomFactor = 1.1;
      const rect = container.getBoundingClientRect();
      const mouseX = e.clientX - rect.left;
      const mouseY = e.clientY - rect.top;

      const xs = (mouseX - tx) / scale;
      const ys = (mouseY - ty) / scale;

      if (e.deltaY < 0) {
        scale = Math.min(2.0, scale * zoomFactor);
      } else {
        scale = Math.max(0.15, scale / zoomFactor);
      }

      tx = mouseX - xs * scale;
      ty = mouseY - ys * scale;
      updateTransform();
    });

    // Touch events for mobile zooming & panning
    let touchStartDist = 0;
    container.addEventListener('touchstart', (e) => {
      if (e.target.closest('.card') || e.target.closest('.modal')) return;
      if (e.touches.length === 1) {
        isDragging = true;
        startX = e.touches[0].clientX - tx;
        startY = e.touches[0].clientY - ty;
      } else if (e.touches.length === 2) {
        isDragging = false;
        touchStartDist = Math.hypot(
          e.touches[0].clientX - e.touches[1].clientX,
          e.touches[0].clientY - e.touches[1].clientY
        );
      }
    });

    container.addEventListener('touchmove', (e) => {
      if (e.touches.length === 1 && isDragging) {
        tx = e.touches[0].clientX - startX;
        ty = e.touches[0].clientY - startY;
        updateTransform();
      } else if (e.touches.length === 2) {
        const dist = Math.hypot(
          e.touches[0].clientX - e.touches[1].clientX,
          e.touches[0].clientY - e.touches[1].clientY
        );
        const factor = dist / touchStartDist;
        touchStartDist = dist;
        scale = Math.min(2.0, Math.max(0.15, scale * factor));
        updateTransform();
      }
    });

    container.addEventListener('touchend', () => {
      isDragging = false;
    });

    function drawConnections() {
      const svg = document.getElementById('svg-canvas');
      const paths = svg.querySelectorAll('path');
      paths.forEach(p => {
        if (p.parentNode === svg) {
          svg.removeChild(p);
        }
      });
      
      data.transitions.forEach(t => {
        const fromNode = data.nodes.find(n => n.route === t.from);
        const toNode = data.nodes.find(n => n.route === t.to);
        if (!fromNode || !toNode) return;
        
        const fromX = fromNode.x + 90;
        const fromY = fromNode.y + 65;
        const toX = toNode.x + 90;
        const toY = toNode.y;
        
        const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        
        let d;
        if (t.isBack) {
          const midX = (fromX + toX) / 2 - 80;
          const midY = (fromY + toY) / 2;
          d = "M " + fromX + " " + fromY + " Q " + midX + " " + midY + " " + toX + " " + toY;
        } else {
          const midY = (fromY + toY) / 2;
          d = "M " + fromX + " " + fromY + " C " + fromX + " " + midY + ", " + toX + " " + midY + ", " + toX + " " + toY;
        }
        
        path.setAttribute('d', d);
        path.setAttribute('fill', 'none');
        path.setAttribute('stroke', t.isBack ? '#ff9800' : '#2196f3');
        path.setAttribute('stroke-width', '2');
        path.setAttribute('marker-end', t.isBack ? 'url(#arrow-orange)' : 'url(#arrow-blue)');
        svg.appendChild(path);
      });
    }

function makeCardDraggable(cardEl, node) {
  let dragging = false;
  let startX = 0, startY = 0;

  const startDrag = (clientX, clientY) => {
    dragging = true;
    startX = clientX;
    startY = clientY;
    cardEl.dataset.dragging = 'false';
  };

  const doDrag = (clientX, clientY) => {
    if (!dragging) return;
    const dx = (clientX - startX) / scale;
    const dy = (clientY - startY) / scale;
    if (dx !== 0 || dy !== 0) {
      cardEl.dataset.dragging = 'true';
    }
    node.x += dx;
    node.y += dy;
    cardEl.style.left = node.x + 'px';
    cardEl.style.top = node.y + 'px';
    startX = clientX;
    startY = clientY;
    drawConnections();
  };

  const endDrag = () => {
    dragging = false;
  };

  // Mouse events
  cardEl.addEventListener('mousedown', (e) => {
    if (e.target.closest('button')) return;
    e.stopPropagation();
    startDrag(e.clientX, e.clientY);
  });
  window.addEventListener('mousemove', (e) => doDrag(e.clientX, e.clientY));
  window.addEventListener('mouseup', endDrag);

  // Touch events
  cardEl.addEventListener('touchstart', (e) => {
    if (e.target.closest('button')) return;
    if (e.touches.length !== 1) return;
    e.stopPropagation();
    startDrag(e.touches[0].clientX, e.touches[0].clientY);
  });
  cardEl.addEventListener('touchmove', (e) => {
    if (!dragging || e.touches.length !== 1) return;
    doDrag(e.touches[0].clientX, e.touches[0].clientY);
  });
  cardEl.addEventListener('touchend', endDrag);
  cardEl.addEventListener('touchcancel', endDrag);
}


    // Render nodes
    // Clear existing node cards to avoid duplication (preserve other UI elements)
    const existingCards = workspace.querySelectorAll('.card');
    existingCards.forEach(c => c.remove());
    data.nodes.forEach(node => {
      const card = document.createElement('div');
      
      const apiErrors = node.apis.filter(api => api.statusCode < 200 || api.statusCode >= 300);
      const hasSlow = node.apis.some(api => api.isSlow);
      const hasIssue = hasSlow || node.errors.length > 0 || apiErrors.length > 0;
      
      card.className = 'card' + (node.isCurrent ? ' active' : '') + (hasIssue ? ' error' : '');
      card.style.left = node.x + 'px';
      card.style.top = node.y + 'px';
      card.id = 'node-' + node.route.replace(/[^a-zA-Z0-9]/g, '_');
      
      const isPopup = node.route.includes('dialog') || node.route.includes('bottomSheet');
      const typeText = isPopup ? 'popup' : 'page';
      const typeClass = isPopup ? 'dialog' : 'page';
      
      const slowApis = node.apis.filter(api => api.isSlow);
      card.innerHTML =
        '<div class="card-header-row">' +
          '<span class="badge ' + typeClass + '">' + typeText + '</span>' +
          '<span class="card-title" title="' + node.title + '">' + node.title + '</span>' +
        '</div>' +
        '<div class="card-stats">' +
          '<span class="stat-badge" title="Visits">' + node.visitCount + ' visits</span>' +
          '<span class="stat-badge" title="API Requests">' + node.apis.length + ' requests</span>' +
          (apiErrors.length > 0 ? '<span class="stat-badge error" title="API Errors">' + apiErrors.length + ' api err</span>' : '') +
          (node.errors.length > 0 ? '<span class="stat-badge error" title="Flutter Errors">' + node.errors.length + ' err</span>' : '') +
        '</div>' +
        (slowApis.length > 0 ? '<div class="slow-apis">Slow: ' + slowApis.map(api => api.url).join(', ') + '</div>' : '');
        
      // Only open details if the card was not dragged
      card.addEventListener('click', (e) => {
        // If a drag occurred, the dataset flag will be set to 'true'
        if (card.dataset.dragging === 'true') {
          // Reset flag for future clicks
          card.dataset.dragging = 'false';
          return;
        }
        showDetails(node);
      });
      workspace.appendChild(card);
      
      makeCardDraggable(card, node);
    });

    drawConnections();
    
    function getViewportSize() {
      // Use the most reliable source available on each platform
      const sources = [
        { w: document.documentElement.clientWidth, h: document.documentElement.clientHeight },
        { w: window.innerWidth, h: window.innerHeight },
        { w: screen.width, h: screen.height },
      ];
      for (const s of sources) {
        if (s.w > 100 && s.h > 100) return s;
      }
      return { w: 375, h: 667 }; // iPhone SE fallback
    }

    function recenterWorkspace() {
      if (data.nodes.length === 0) return;
      
      let minX = Infinity;
      let maxX = -Infinity;
      let minY = Infinity;
      let maxY = -Infinity;
      
      data.nodes.forEach(node => {
        if (node.x < minX) minX = node.x;
        if (node.x > maxX) maxX = node.x;
        if (node.y < minY) minY = node.y;
        if (node.y > maxY) maxY = node.y;
      });
      
      const cardWidth = 180;
      const cardHeight = 65;
      const padding = 60;
      
      const graphWidth = (maxX - minX) + cardWidth + padding;
      const graphHeight = (maxY - minY) + cardHeight + padding;
      
      const contentW = maxX - minX + 200;
      const contentH = maxY - minY + 80;

      const vpW = container.clientWidth || window.innerWidth;
globalViewportWidth = vpW;
      const vpH = container.clientHeight || window.innerHeight;

      const scaleX = vpW / (contentW + 100);
      const scaleY = vpH / (contentH + 100);
      scale = Math.min(1.0, Math.min(scaleX, scaleY));
      // Allow scale to drop below 0.15 on mobile so the whole map fits
      if (scale < 0.02) scale = 0.02;

      tx = (vpW - (maxX + minX + 200) * scale) / 2;
      ty = (vpH - (maxY + minY + 80) * scale) / 2;
      
      updateTransform();
      
      // Hide startup hint after successful centering
      const hint = document.getElementById('startup-hint');
      if (hint) {
        setTimeout(() => { hint.style.display = 'none'; }, 1500);
      }
    }



    // ─── Mini Map ────────────────────────────────────────────────────
    const minimapCanvas = document.getElementById('minimap-canvas');
    const mmCtx = minimapCanvas ? minimapCanvas.getContext('2d') : null;
    const MM_W = 200;
    const MM_H = 140;
    const CARD_W = 180;
    const CARD_H = 65;

    function drawMinimap() {
      if (!mmCtx || data.nodes.length === 0) return;

      // Compute bounding box of all nodes
      let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
      data.nodes.forEach(n => {
        if (n.x < minX) minX = n.x;
        if (n.x + CARD_W > maxX) maxX = n.x + CARD_W;
        if (n.y < minY) minY = n.y;
        if (n.y + CARD_H > maxY) maxY = n.y + CARD_H;
      });
      const contentW = maxX - minX || 1;
      const contentH = maxY - minY || 1;

      const pad = 8;
      const mmScaleX = (MM_W - pad * 2) / contentW;
      const mmScaleY = (MM_H - pad * 2) / contentH;
      const mmScale = Math.min(mmScaleX, mmScaleY);

      // Detect light/dark
      const isDark = getComputedStyle(document.body).backgroundColor.includes('30,') ||
                     getComputedStyle(document.body).backgroundColor.includes('244') === false;

      mmCtx.clearRect(0, 0, MM_W, MM_H);

      // Background
      const bgColor = getComputedStyle(document.getElementById('minimap-container')).backgroundColor || '#fff';
      mmCtx.fillStyle = bgColor;
      mmCtx.fillRect(0, 0, MM_W, MM_H);

      // Draw dot grid
      mmCtx.fillStyle = 'rgba(0,0,0,0.06)';
      for (let gx = pad; gx < MM_W - pad; gx += 14) {
        for (let gy = pad; gy < MM_H - pad; gy += 14) {
          mmCtx.beginPath();
          mmCtx.arc(gx, gy, 0.6, 0, Math.PI * 2);
          mmCtx.fill();
        }
      }

      // Draw connections
      mmCtx.strokeStyle = 'rgba(79,142,247,0.25)';
      mmCtx.lineWidth = 0.8;
      data.transitions.forEach(t => {
        const fromNode = data.nodes.find(n => n.route === t.from);
        const toNode   = data.nodes.find(n => n.route === t.to);
        if (!fromNode || !toNode) return;
        const fx = pad + (fromNode.x + CARD_W / 2 - minX) * mmScale;
        const fy = pad + (fromNode.y + CARD_H / 2 - minY) * mmScale;
        const tx2 = pad + (toNode.x + CARD_W / 2 - minX) * mmScale;
        const ty2 = pad + (toNode.y + CARD_H / 2 - minY) * mmScale;
        mmCtx.beginPath();
        mmCtx.moveTo(fx, fy);
        mmCtx.lineTo(tx2, ty2);
        mmCtx.stroke();
      });

      // Draw nodes
      data.nodes.forEach(n => {
        const nx = pad + (n.x - minX) * mmScale;
        const ny = pad + (n.y - minY) * mmScale;
        const nw = Math.max(4, CARD_W * mmScale);
        const nh = Math.max(3, CARD_H * mmScale);
        
        const apiErrors = n.apis ? n.apis.filter(api => api.statusCode < 200 || api.statusCode >= 300) : [];
        const hasSlow = n.apis && n.apis.some(api => api.isSlow);
        const hasError = n.errors && n.errors.length > 0;
        const hasIssue = hasSlow || hasError || apiErrors.length > 0;

        mmCtx.fillStyle = '#4f8ef7';
        mmCtx.strokeStyle = 'rgba(79,142,247,0.6)';
        mmCtx.lineWidth = 0.5;
        const r = 2;
        mmCtx.beginPath();
        mmCtx.moveTo(nx + r, ny);
        mmCtx.lineTo(nx + nw - r, ny);
        mmCtx.quadraticCurveTo(nx + nw, ny, nx + nw, ny + r);
        mmCtx.lineTo(nx + nw, ny + nh - r);
        mmCtx.quadraticCurveTo(nx + nw, ny + nh, nx + nw - r, ny + nh);
        mmCtx.lineTo(nx + r, ny + nh);
        mmCtx.quadraticCurveTo(nx, ny + nh, nx, ny + nh - r);
        mmCtx.lineTo(nx, ny + r);
        mmCtx.quadraticCurveTo(nx, ny, nx + r, ny);
        mmCtx.closePath();
        mmCtx.globalAlpha = 0.7;
        mmCtx.fill();
        mmCtx.globalAlpha = 1;
        mmCtx.stroke();

        if (hasIssue) {
          const dotRadius = Math.max(1.5, Math.min(3, nw / 8));
          mmCtx.fillStyle = '#ef4444';
          mmCtx.beginPath();
          mmCtx.arc(nx + nw - dotRadius - 1, ny + dotRadius + 1, dotRadius, 0, Math.PI * 2);
          mmCtx.fill();
        }
      });

      // Draw viewport indicator
      const { w: vw, h: vh } = getViewportSize();
      // Viewport in world coords
      const vpLeft   = -tx / scale;
      const vpTop    = -ty / scale;
      const vpRight  = vpLeft + vw / scale;
      const vpBottom = vpTop  + vh / scale;

      const rx = pad + (vpLeft  - minX) * mmScale;
      const ry = pad + (vpTop   - minY) * mmScale;
      const rw =      (vpRight  - vpLeft) * mmScale;
      const rh =      (vpBottom - vpTop)  * mmScale;

      // Make camera box a constant small size (zoom invariant), centered at viewport position
      const cx = rx + rw / 2;
      const cy = ry + rh / 2;
      const boxW = 16;
      const boxH = 11;
      const drawX = cx - boxW / 2;
      const drawY = cy - boxH / 2;

      mmCtx.strokeStyle = '#ef4444';
      mmCtx.lineWidth = 1.5;
      mmCtx.setLineDash([3, 2]);
      mmCtx.fillStyle = 'rgba(239,68,68,0.07)';
      mmCtx.fillRect(drawX, drawY, boxW, boxH);
      mmCtx.strokeRect(drawX, drawY, boxW, boxH);
      mmCtx.setLineDash([]);

      // Store minimap geometry for click navigation
      minimapCanvas._mmScale = mmScale;
      minimapCanvas._minX = minX;
      minimapCanvas._minY = minY;
      minimapCanvas._pad = pad;
    }

    // Mini-map click + drag to navigate
    let mmDragging = false;

    function minimapNavigate(e) {
      const rect = minimapCanvas.getBoundingClientRect();
      const clientX = e.touches ? e.touches[0].clientX : e.clientX;
      const clientY = e.touches ? e.touches[0].clientY : e.clientY;
      const clickX = clientX - rect.left;
      const clickY = clientY - rect.top;

      const mmScale = minimapCanvas._mmScale || 0.05;
      const minX    = minimapCanvas._minX    || 0;
      const minY    = minimapCanvas._minY    || 0;
      const pad     = minimapCanvas._pad     || 8;

      // World coordinate clicked on mini-map
      const worldX = (clickX - pad) / mmScale + minX;
      const worldY = (clickY - pad) / mmScale + minY;

      const { w: vw, h: vh } = getViewportSize();
      tx = vw / 2 - worldX * scale;
      ty = vh / 2 - worldY * scale;
      updateTransform();
    }

    if (minimapCanvas) {
      minimapCanvas.addEventListener('mousedown', e => { mmDragging = true; minimapNavigate(e); });
      minimapCanvas.addEventListener('mousemove', e => { if (mmDragging) minimapNavigate(e); });
      minimapCanvas.addEventListener('mouseup',   () => { mmDragging = false; });
      minimapCanvas.addEventListener('mouseleave',() => { mmDragging = false; });
      minimapCanvas.addEventListener('touchstart', e => { e.preventDefault(); mmDragging = true; minimapNavigate(e); }, { passive: false });
      minimapCanvas.addEventListener('touchmove',  e => { e.preventDefault(); if (mmDragging) minimapNavigate(e); }, { passive: false });
      minimapCanvas.addEventListener('touchend',   () => { mmDragging = false; });
    }
    // ─────────────────────────────────────────────────────────────────

    // ─── Layout Algorithms ───────────────────────────────────────────
    let currentLayout = data.layoutMode || 'tree';

    function applyLayout(mode) {
      currentLayout = mode;

      // Update active button
      document.querySelectorAll('.layout-btn').forEach(b => b.classList.remove('active'));
      const activeBtn = document.getElementById('layout-btn-' + mode);
      if (activeBtn) activeBtn.classList.add('active');

      const nodes = data.nodes;
      if (nodes.length === 0) return;

      const cardW = 200;
      const cardH = 80;
      const gapX = 80;
      const gapY = 60;

      if (mode === 'tree') {
        // Build parent→children from transitions
        const children = {};
        const hasParent = new Set();
        nodes.forEach(n => { children[n.route] = []; });
        data.transitions.forEach(t => {
          if (!t.isBack && children[t.from] !== undefined) {
            children[t.from].push(t.to);
            hasParent.add(t.to);
          }
        });
        const roots = nodes.filter(n => !hasParent.has(n.route));
        if (roots.length === 0) roots.push(nodes[0]);

        const positioned = new Set();
        let maxDepth = 0;

        function getSubtreeWidth(route, depth) {
          const ch = (children[route] || []).filter(c => !positioned.has(c));
          if (ch.length === 0) return cardW + gapX;
          return ch.reduce((sum, c) => sum + getSubtreeWidth(c, depth + 1), 0);
        }

        function place(route, x, y, depth) {
          if (positioned.has(route)) return x;
          positioned.add(route);
          if (depth > maxDepth) maxDepth = depth;

          const node = nodes.find(n => n.route === route);
          if (!node) return x;

          const ch = (children[route] || []).filter(c => !positioned.has(c));
          let childX = x;
          ch.forEach(c => {
            childX = place(c, childX, y + cardH + gapY, depth + 1);
          });

          const totalW = ch.length > 0
            ? ch.reduce((sum, c) => sum + getSubtreeWidth(c, depth + 1), 0)
            : cardW + gapX;
          node.x = x + (totalW - cardW) / 2;
          node.y = y;

          return x + totalW;
        }

        let startX = 60;
        roots.forEach(r => {
          startX = place(r.route, startX, 60, 0) + gapX;
        });

        // Place any unpositioned nodes in a row at the bottom
        let extraX = 60;
        const extraY = (maxDepth + 2) * (cardH + gapY);
        nodes.filter(n => !positioned.has(n.route)).forEach(n => {
          n.x = extraX;
          n.y = extraY;
          extraX += cardW + gapX;
        });

      } else if (mode === 'grid') {
        const cols = Math.max(1, Math.ceil(Math.sqrt(nodes.length)));
        nodes.forEach((node, i) => {
          node.x = 60 + (i % cols) * (cardW + gapX);
          node.y = 60 + Math.floor(i / cols) * (cardH + gapY);
        });

      } else if (mode === 'stream') {
        // Topological order following transitions
        const inDegree = {};
        const adj = {};
        nodes.forEach(n => { inDegree[n.route] = 0; adj[n.route] = []; });
        data.transitions.forEach(t => {
          if (!t.isBack && adj[t.from] !== undefined) {
            adj[t.from].push(t.to);
            inDegree[t.to] = (inDegree[t.to] || 0) + 1;
          }
        });

        const queue = nodes.filter(n => inDegree[n.route] === 0).map(n => n.route);
        const order = [];
        const visited = new Set();
        while (queue.length > 0) {
          const cur = queue.shift();
          if (visited.has(cur)) continue;
          visited.add(cur);
          order.push(cur);
          (adj[cur] || []).forEach(next => {
            inDegree[next]--;
            if (inDegree[next] <= 0 && !visited.has(next)) queue.push(next);
          });
        }
        nodes.filter(n => !visited.has(n.route)).forEach(n => order.push(n.route));

        order.forEach((route, i) => {
          const node = nodes.find(n => n.route === route);
          if (node) {
            node.x = 60;
            node.y = 60 + i * (cardH + gapY);
          }
        });

      } else if (mode === 'circle') {
        const count = nodes.length;
        const radius = Math.max(220, count * (cardW + gapX) / (2 * Math.PI));
        const cx = radius + cardW;
        const cy = radius + cardH;
        nodes.forEach((node, i) => {
          const angle = (2 * Math.PI * i) / count - Math.PI / 2;
          node.x = cx + radius * Math.cos(angle);
          node.y = cy + radius * Math.sin(angle);
        });
      }

      // Dynamically resize workspace and SVG to prevent clipping on mobile Safari
      let maxNodeX = 0;
      let maxNodeY = 0;
      nodes.forEach(node => {
        if (node.x > maxNodeX) maxNodeX = node.x;
        if (node.y > maxNodeY) maxNodeY = node.y;
      });
      const newWidth = Math.max(1000, maxNodeX + 400);
      const newHeight = Math.max(1000, maxNodeY + 400);
      
      const workspaceEl = document.getElementById('workspace');
      if (workspaceEl) {
        workspaceEl.style.width = newWidth + 'px';
        workspaceEl.style.height = newHeight + 'px';
      }
      const svgEl = document.getElementById('svg-canvas');
      if (svgEl) {
        svgEl.setAttribute('width', newWidth);
        svgEl.setAttribute('height', newHeight);
        svgEl.style.width = newWidth + 'px';
        svgEl.style.height = newHeight + 'px';
      }

      // Update card DOM positions
      nodes.forEach(node => {
        const cardId = 'node-' + node.route.replace(/[^a-zA-Z0-9]/g, '_');
        const card = document.getElementById(cardId);
        if (card) {
          card.style.transition = 'left 0.45s cubic-bezier(0.16,1,0.3,1), top 0.45s cubic-bezier(0.16,1,0.3,1)';
          card.style.left = node.x + 'px';
          card.style.top = node.y + 'px';
          setTimeout(() => { card.style.transition = ''; }, 500);
        }
      });

      drawConnections();
      setTimeout(() => { recenterWorkspace(); }, 50);
    }
    // ─────────────────────────────────────────────────────────────────

    let currentNode = null;

    function showDetails(node) {
      currentNode = node;
      const modal = document.getElementById('modal');
      const modalTitle = document.getElementById('modal-title');
      modalTitle.textContent = node.title;
      
      document.getElementById('tab-apis-count').textContent = ' (' + node.apis.length + ')';
      document.getElementById('tab-errors-count').textContent = ' (' + node.errors.length + ')';
      
      document.getElementById('api-search-input').value = '';
      renderApis(node.apis);
      
      const errorsList = document.getElementById('errors-list');
      errorsList.innerHTML = '';
      if (node.errors.length === 0) {
        errorsList.innerHTML = '<div style="color:var(--text-secondary); text-align:center; padding:20px;">Không có lỗi Flutter/Dart nào.</div>';
      } else {
        node.errors.forEach(err => {
          const item = document.createElement('div');
          item.className = 'log-item';
          item.style.padding = '12px';
          
          const stackEncoded = encodeURIComponent(err.stackTrace);
          item.innerHTML = `
            <div style="color:var(--danger); font-weight:bold; font-size:13px; margin-bottom:8px;">[\${err.type}] \${err.message}</div>
            <div style="font-size:11px; color:var(--text-secondary); margin-bottom:8px;">\${err.timestamp}</div>
            <div class="section-title">Stack Trace <button class="copy-btn" onclick="copyValue(decodeURIComponent('\${stackEncoded}'), this)">Copy</button></div>
            <pre style="max-height: 250px; overflow-y: auto;">\${escapeHtml(err.stackTrace)}</pre>
          `;
          errorsList.appendChild(item);
        });
      }
      
      modal.style.display = 'flex';
      switchTab('apis');
    }

    function filterModalApis(query) {
      if (!currentNode) return;
      query = query.toLowerCase().trim();
      const filtered = currentNode.apis.filter(api => 
        api.url.toLowerCase().includes(query) || 
        api.method.toLowerCase().includes(query) ||
        String(api.statusCode).includes(query)
      );
      renderApis(filtered);
    }

    function renderApis(apisListArray) {
      const apisListInner = document.getElementById('apis-list-inner');
      apisListInner.innerHTML = '';
      if (apisListArray.length === 0) {
        apisListInner.innerHTML = '<div style="color:var(--text-secondary); text-align:center; padding:20px;">Không tìm thấy API log nào.</div>';
      } else {
        apisListArray.forEach((api, index) => {
          const item = document.createElement('div');
          item.className = 'log-item';
          
          const isErr = api.statusCode < 200 || api.statusCode >= 300;
          const statusClass = isErr ? 'error' : 'success';
          const durationText = api.duration + ' ms';
          
          const reqHeadersStr = JSON.stringify(api.requestHeaders, null, 2);
          const resHeadersStr = JSON.stringify(api.responseHeaders, null, 2);
          const reqBodyStr = formatJson(api.requestBody);
          const resBodyStr = formatJson(api.responseBody);
          const generalText = `Method: \${api.method}
Status: \${api.statusCode}
Thời gian: \${api.timestamp}
Thời gian chạy: \${durationText}
Kích thước phản hồi: \${formatBytes(api.responseBytes)}
Pha (Phase): \${api.phase}`;

          const urlEncoded = encodeURIComponent(api.url);
          const generalEncoded = encodeURIComponent(generalText);
          const reqHeadersEncoded = encodeURIComponent(reqHeadersStr);
          const resHeadersEncoded = encodeURIComponent(resHeadersStr);
          const reqBodyEncoded = encodeURIComponent(reqBodyStr);
          const resBodyEncoded = encodeURIComponent(resBodyStr);

          item.innerHTML = `
            <div class="log-header" onclick="toggleAccordion(\${index})">
              <div class="log-meta-left">
                <span class="method-badge \${api.method}">\${api.method}</span>
                <span class="status-badge \${statusClass}">\${api.statusCode}</span>
                <span class="log-url" title="\${api.url}">\${api.url}</span>
              </div>
              <span class="log-duration">\${durationText}</span>
            </div>
            <div class="log-details" id="log-details-\${index}">
              <div class="section-title">URL <button class="copy-btn" onclick="copyValue(decodeURIComponent('\${urlEncoded}'), this)">Copy</button></div>
              <pre style="white-space:pre-wrap;word-break:break-all;">\${escapeHtml(api.url)}</pre>
              <div class="section-title">Thông tin chung <button class="copy-btn" onclick="copyValue(decodeURIComponent('\${generalEncoded}'), this)">Copy</button></div>
              <table>
                <tr><td class="key">Method</td><td>\${api.method}</td></tr>
                <tr><td class="key">Status</td><td>\${api.statusCode}</td></tr>
                <tr><td class="key">Thời gian</td><td>\${api.timestamp}</td></tr>
                <tr><td class="key">Thời gian chạy</td><td>\${durationText}</td></tr>
                <tr><td class="key">Kích thước phản hồi</td><td>\${formatBytes(api.responseBytes)}</td></tr>
                <tr><td class="key">Pha (Phase)</td><td>\${api.phase}</td></tr>
              </table>
              \${Object.keys(api.requestHeaders).length > 0 ? `
                <div class="section-title">Request Headers <button class="copy-btn" onclick="copyValue(decodeURIComponent('\${reqHeadersEncoded}'), this)">Copy</button></div>
                \${renderTable(api.requestHeaders)}
              ` : ''}
              \${api.requestBody ? `
                <div class="section-title">Request Body <button class="copy-btn" onclick="copyValue(decodeURIComponent('\${reqBodyEncoded}'), this)">Copy</button></div>
                <pre>\${escapeHtml(formatJson(api.requestBody))}</pre>
              ` : ''}
              \${Object.keys(api.responseHeaders).length > 0 ? `
                <div class="section-title">Response Headers <button class="copy-btn" onclick="copyValue(decodeURIComponent('\${resHeadersEncoded}'), this)">Copy</button></div>
                \${renderTable(api.responseHeaders)}
              ` : ''}
              \${api.responseBody ? `
                <div class="section-title">Response Body <button class="copy-btn" onclick="copyValue(decodeURIComponent('\${resBodyEncoded}'), this)">Copy</button></div>
                <pre>\${escapeHtml(formatJson(api.responseBody))}</pre>
              ` : ''}
            </div>
          `;
            
          apisListInner.appendChild(item);
        });
      }
    }

    function closeModal() {
      document.getElementById('modal').style.display = 'none';
    }

    function formatBytes(bytes) {
      if (!bytes || bytes <= 0) return '0 B';
      const k = 1024;
      const sizes = ['B', 'KB', 'MB', 'GB'];
      const i = Math.floor(Math.log(bytes) / Math.log(k));
      return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    function toggleAccordion(index) {
      const details = document.getElementById('log-details-' + index);
      if (details.style.display === 'block') {
        details.style.display = 'none';
      } else {
        details.style.display = 'block';
      }
    }

    function escapeHtml(text) {
      if (text === null || text === undefined) return '';
      if (typeof text !== 'string') text = String(text);
      return text
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
    }

    function formatJson(body) {
      if (!body) return '';
      if (typeof body === 'object') {
        return JSON.stringify(body, null, 2);
      }
      try {
        const parsed = JSON.parse(body);
        return JSON.stringify(parsed, null, 2);
      } catch (e) {
        return body;
      }
    }

    function renderTable(headers) {
      if (!headers || Object.keys(headers).length === 0) return '';
      let html = '<table>';
      for (const [key, value] of Object.entries(headers)) {
        html += '<tr><td class="key">' + escapeHtml(key) + '</td><td>' + escapeHtml(value) + '</td></tr>';
      }
      html += '</table>';
      return html;
    }

    // Tab switching functionality
    function switchTab(tab) {
      const activeTabBtn = document.getElementById('tab-' + tab);
      const activeTabContent = document.getElementById(tab + '-list');
      
      document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
      
      activeTabBtn.classList.add('active');
      activeTabContent.classList.add('active');
    }

    function copyValue(text, btn) {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(() => {
          showCopied(btn);
        });
      } else {
        const textArea = document.createElement("textarea");
        textArea.value = text;
        textArea.style.position = "fixed";
        document.body.appendChild(textArea);
        textArea.focus();
        textArea.select();
        try {
          document.execCommand('copy');
          showCopied(btn);
        } catch (err) {
          console.error('Lỗi sao chép: ', err);
        }
        document.body.removeChild(textArea);
      }
    }

    function showCopied(btn) {
      const oldText = btn.textContent;
      btn.textContent = 'Copied!';
      setTimeout(() => btn.textContent = oldText, 1500);
    }

    function searchNodes(query) {
      query = query.toLowerCase().trim();
      
      data.nodes.forEach(node => {
        const cardId = 'node-' + node.route.replace(/[^a-zA-Z0-9]/g, '_');
        const card = document.getElementById(cardId);
        if (card) {
          card.style.borderColor = node.isCurrent ? 'var(--success)' : 'var(--border-color)';
          card.style.boxShadow = '';
        }
      });
      
      if (query === '') return;
      
      const match = data.nodes.find(node => 
        node.title.toLowerCase().includes(query) || 
        node.route.toLowerCase().includes(query)
      );
      
      if (match) {
        const cardId = 'node-' + match.route.replace(/[^a-zA-Z0-9]/g, '_');
        const card = document.getElementById(cardId);
        if (card) {
          card.style.borderColor = 'var(--primary)';
          card.style.boxShadow = '0 0 20px var(--primary)';
          
          const rect = container.getBoundingClientRect();
          scale = 1.0;
          tx = rect.width / 2 - match.x - 90;
          ty = rect.height / 2 - match.y - 32;
          updateTransform();
        }
      }
    }

    // Trigger centering on every possible event that signals the page is ready
    document.addEventListener('DOMContentLoaded', recenterWorkspace);
    window.addEventListener('load', recenterWorkspace);
    window.addEventListener('resize', recenterWorkspace);
    document.addEventListener('visibilitychange', () => {
      if (!document.hidden) recenterWorkspace();
    });
    
    // Use ResizeObserver to auto-recenter as soon as the container size gets computed
    if (window.ResizeObserver && container) {
      let firstNonZero = false;
      const ro = new ResizeObserver(entries => {
        for (let entry of entries) {
          const { width, height } = entry.contentRect;
          if (width > 0 && height > 0) {
            recenterWorkspace();
            if (!firstNonZero) {
              firstNonZero = true;
            }
          }
        }
      });
      ro.observe(container);
    }
    
    // Delayed fallbacks for iOS Quick Look and sandboxed webviews
    recenterWorkspace();
    [50, 200, 500, 1000, 2000].forEach(ms => setTimeout(recenterWorkspace, ms));
  </script>
  <!-- STATIC_DETAILS -->
</body>
</html>''';
