
const mockElement = {
  style: {},
  addEventListener: () => {},
  appendChild: () => {},
  removeChild: () => {},
  querySelectorAll: () => [],
  getContext: () => ({
    clearRect: () => {},
    fillRect: () => {},
    beginPath: () => {},
    arc: () => {},
    fill: () => {},
    stroke: () => {},
    moveTo: () => {},
    lineTo: () => {},
    quadraticCurveTo: () => {},
    closePath: () => {},
    strokeRect: () => {},
    setLineDash: () => {},
  }),
  getBoundingClientRect: () => ({ width: 1024, height: 768, left: 0, top: 0 }),
};

const document = {
  addEventListener: () => {},
  getElementById: (id) => {
    if (id === 'map-data') {
      return { textContent: '{"nodes":[{"route":"/test","title":"Test","x":100,"y":100,"visitCount":1,"apis":[{"method":"GET","url":"http://test.com","statusCode":200,"duration":10,"phase":"Request","timestamp":"2023-01-01","requestHeaders":{"x-test":"1"},"requestBody":"test","responseHeaders":{"content-type":"text/plain"},"responseBody":"ok","responseBytes":2}],"errors":[],"isCurrent":true}],"transitions":[]}' };
    }
    return mockElement;
  },
  documentElement: { clientWidth: 1024, clientHeight: 768 },
  body: {
    addEventListener: () => {},
    appendChild: () => {},
    removeChild: () => {},
  },
  querySelectorAll: () => [mockElement],
  createElement: () => mockElement,
  createElementNS: () => ({
    setAttribute: () => {},
    ...mockElement,
  }),
};
const window = {
  addEventListener: () => {},
  innerWidth: 1024,
  innerHeight: 768,
};
const screen = { width: 1024, height: 768 };
const navigator = { clipboard: { writeText: () => Promise.resolve() } };
const getComputedStyle = () => ({
  backgroundColor: 'rgb(255, 255, 255)',
  color: 'rgb(0,0,0)',
});

    const data = JSON.parse(document.getElementById('map-data').textContent);
    
    let scale = 0.8;
    let tx = 100;
    let ty = 100;
    let isDragging = false;
    let startX, startY;

    const workspace = document.getElementById('workspace');
    const container = document.getElementById('container');

    function updateTransform() {
      workspace.style.transform = "translate(" + tx + "px, " + ty + "px) scale(" + scale + ")";
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
      let cardDrag = false;
      let cx, cy;
      
      cardEl.addEventListener('mousedown', (e) => {
        if (e.target.closest('button')) return;
        cardDrag = true;
        e.stopPropagation();
        cx = e.clientX;
        cy = e.clientY;
      });
      
      window.addEventListener('mousemove', (e) => {
        if (!cardDrag) return;
        const dx = (e.clientX - cx) / scale;
        const dy = (e.clientY - cy) / scale;
        node.x += dx;
        node.y += dy;
        cardEl.style.left = node.x + 'px';
        cardEl.style.top = node.y + 'px';
        cx = e.clientX;
        cy = e.clientY;
        drawConnections();
      });
      
      window.addEventListener('mouseup', () => {
        cardDrag = false;
      });
      
      // Mobile touch drag
      cardEl.addEventListener('touchstart', (e) => {
        if (e.target.closest('button')) return;
        if (e.touches.length === 1) {
          cardDrag = true;
          e.stopPropagation();
          cx = e.touches[0].clientX;
          cy = e.touches[0].clientY;
        }
      });
      
      cardEl.addEventListener('touchmove', (e) => {
        if (!cardDrag || e.touches.length !== 1) return;
        const dx = (e.touches[0].clientX - cx) / scale;
        const dy = (e.touches[0].clientY - cy) / scale;
        node.x += dx;
        node.y += dy;
        cardEl.style.left = node.x + 'px';
        cardEl.style.top = node.y + 'px';
        cx = e.touches[0].clientX;
        cy = e.touches[0].clientY;
        drawConnections();
      });
      
      cardEl.addEventListener('touchend', () => {
        cardDrag = false;
      });
    }

    // Render nodes
    data.nodes.forEach(node => {
      const card = document.createElement('div');
      card.className = 'card' + (node.isCurrent ? ' active' : '');
      card.style.left = node.x + 'px';
      card.style.top = node.y + 'px';
      card.id = 'node-' + node.route.replace(/[^a-zA-Z0-9]/g, '_');
      
      const isPopup = node.route.includes('dialog') || node.route.includes('bottomSheet');
      const typeText = isPopup ? 'popup' : 'page';
      const typeClass = isPopup ? 'dialog' : 'page';
      
      card.innerHTML = 
        '<div class="card-header-row">' +
          '<span class="badge ' + typeClass + '">' + typeText + '</span>' +
          '<span class="card-title" title="' + node.title + '">' + node.title + '</span>' +
        '</div>' +
        '<div class="card-stats">' +
          '<span class="stat-badge">' + node.visitCount + ' v</span>' +
          '<span class="stat-badge">' + node.apis.length + ' req</span>' +
          (node.errors.length > 0 ? '<span class="stat-badge error">' + node.errors.length + ' err</span>' : '') +
        '</div>';
        
      card.addEventListener('click', () => showDetails(node));
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
      
      const graphCenterX = (minX + maxX) / 2 + cardWidth / 2;
      const graphCenterY = (minY + maxY) / 2 + cardHeight / 2;
      
      const { w: viewportWidth, h: viewportHeight } = getViewportSize();
      
      const scaleX = (viewportWidth - padding) / graphWidth;
      const scaleY = (viewportHeight - padding) / graphHeight;
      
      scale = Math.min(scaleX, scaleY);
      scale = Math.max(0.2, Math.min(1.2, scale));
      
      tx = (viewportWidth / 2) - (graphCenterX * scale);
      ty = (viewportHeight / 2) - (graphCenterY * scale);
      
      updateTransform();
      
      // Hide startup hint after successful centering
      const hint = document.getElementById('startup-hint');
      if (hint && viewportWidth > 100) {
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

      mmCtx.strokeStyle = '#ef4444';
      mmCtx.lineWidth = 1.5;
      mmCtx.setLineDash([3, 2]);
      mmCtx.fillStyle = 'rgba(239,68,68,0.07)';
      mmCtx.fillRect(rx, ry, rw, rh);
      mmCtx.strokeRect(rx, ry, rw, rh);
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
        node.errors.forEach((err, index) => {
          const item = document.createElement('div');
          item.className = 'log-item';
          item.style.padding = '12px';
          
          window.__copyStore = window.__copyStore || {};
          const copyId = 'err_' + index + '_' + Math.random().toString(36).substr(2, 9);
          window.__copyStore[copyId] = err.stackTrace || '';
          
          let html = '<div style="color:var(--danger); font-weight:bold; font-size:13px; margin-bottom:8px;">[' + escapeHtml(err.type) + '] ' + escapeHtml(err.message) + '</div>';
          html += '<div style="font-size:11px; color:var(--text-secondary); margin-bottom:8px;">' + escapeHtml(err.timestamp) + '</div>';
          html += '<div class="section-title">Stack Trace <button class="copy-btn" onclick="copyValue(window.__copyStore[\'' + copyId + '\'], this)">Copy</button></div>';
          html += '<pre style="max-height: 250px; overflow-y: auto;">' + escapeHtml(err.stackTrace) + '</pre>';
          
          item.innerHTML = html;
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
        window.__copyStore = window.__copyStore || {};

        window.__copyStore = window.__copyStore || {};

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
          const curlCmd = generateCurl(api);
          const generalText = 'Method: ' + api.method + '\\n' +
                              'Status: ' + api.statusCode + '\\n' +
                              'Thời gian: ' + api.timestamp + '\\n' +
                              'Thời gian chạy: ' + durationText + '\\n' +
                              'Kích thước phản hồi: ' + formatBytes(api.responseBytes) + '\\n' +
                              'Pha (Phase): ' + api.phase;

          const copyIdUrl = 'url_' + index;
          const copyIdGen = 'gen_' + index;
          const copyIdReqH = 'reqh_' + index;
          const copyIdResH = 'resh_' + index;
          const copyIdReqB = 'reqb_' + index;
          const copyIdResB = 'resb_' + index;
          const copyIdCurl = 'curl_' + index;
          
          window.__copyStore[copyIdUrl] = api.url || '';
          window.__copyStore[copyIdGen] = generalText || '';
          window.__copyStore[copyIdReqH] = reqHeadersStr || '';
          window.__copyStore[copyIdResH] = resHeadersStr || '';
          window.__copyStore[copyIdReqB] = reqBodyStr || '';
          window.__copyStore[copyIdResB] = resBodyStr || '';
          window.__copyStore[copyIdCurl] = curlCmd || '';

          let html = '<div class="log-header" onclick="toggleAccordion(' + index + ')">';
          html += '<div class="log-meta-left">';
          html += '<span class="method-badge ' + escapeHtml(api.method) + '">' + escapeHtml(api.method) + '</span>';
          html += '<span class="status-badge ' + statusClass + '">' + api.statusCode + '</span>';
          html += '<span class="log-url" title="' + escapeHtml(api.url) + '">' + escapeHtml(api.url) + '</span>';
          html += '</div>';
          html += '<span class="log-duration">' + escapeHtml(durationText) + '</span>';
          html += '</div>';
          
          html += '<div class="log-details" id="log-details-' + index + '">';
          
          // Tabs definition
          html += '<div class="api-tabs">';
          html += '<button id="api-btn-general-' + index + '" class="api-tab-btn active" onclick="switchApiTab(' + index + ', \'general\')">General</button>';
          html += '<button id="api-btn-request-' + index + '" class="api-tab-btn" onclick="switchApiTab(' + index + ', \'request\')">Request</button>';
          html += '<button id="api-btn-response-' + index + '" class="api-tab-btn" onclick="switchApiTab(' + index + ', \'response\')">Response</button>';
          html += '</div>';
          
          // --- GENERAL TAB ---
          html += '<div id="api-tab-general-' + index + '" class="api-tab-content active">';
          html += '<div class="section-title">URL <button class="copy-btn" onclick="copyValue(window.__copyStore[\'' + copyIdUrl + '\'], this)">Copy</button></div>';
          html += '<pre style="white-space:pre-wrap;word-break:break-all;">' + escapeHtml(api.url) + '</pre>';
          
          html += '<div class="section-title">cURL <button class="copy-btn" onclick="copyValue(window.__copyStore[\'' + copyIdCurl + '\'], this)">Copy</button></div>';
          html += '<pre style="white-space:pre-wrap;word-break:break-all;">' + escapeHtml(curlCmd) + '</pre>';
          
          html += '<div class="section-title">Thông tin chung <button class="copy-btn" onclick="copyValue(window.__copyStore[\'' + copyIdGen + '\'], this)">Copy</button></div>';
          html += '<table>';
          html += '<tr><td class="key">Method</td><td>' + escapeHtml(api.method) + '</td></tr>';
          html += '<tr><td class="key">Status</td><td>' + api.statusCode + '</td></tr>';
          html += '<tr><td class="key">Thời gian</td><td>' + escapeHtml(api.timestamp) + '</td></tr>';
          html += '<tr><td class="key">Thời gian chạy</td><td>' + escapeHtml(durationText) + '</td></tr>';
          html += '<tr><td class="key">Kích thước phản hồi</td><td>' + formatBytes(api.responseBytes) + '</td></tr>';
          html += '<tr><td class="key">Pha (Phase)</td><td>' + escapeHtml(api.phase) + '</td></tr>';
          html += '</table>';
          html += '</div>';
          
          // --- REQUEST TAB ---
          html += '<div id="api-tab-request-' + index + '" class="api-tab-content">';
          if (api.requestHeaders && Object.keys(api.requestHeaders).length > 0) {
            html += '<div class="section-title">Request Headers <button class="copy-btn" onclick="copyValue(window.__copyStore[\'' + copyIdReqH + '\'], this)">Copy</button></div>';
            html += renderTable(api.requestHeaders);
          } else {
            html += '<div style="color: var(--text-secondary); font-size: 13px; font-style: italic;">No request headers</div>';
          }
          
          if (api.requestBody) {
            html += '<div class="section-title" style="margin-top: 12px;">Request Body <button class="copy-btn" onclick="copyValue(window.__copyStore[\'' + copyIdReqB + '\'], this)">Copy</button></div>';
            html += '<pre>' + escapeHtml(reqBodyStr) + '</pre>';
          } else {
            html += '<div style="margin-top: 12px; color: var(--text-secondary); font-size: 13px; font-style: italic;">No request body</div>';
          }
          html += '</div>';
          
          // --- RESPONSE TAB ---
          html += '<div id="api-tab-response-' + index + '" class="api-tab-content">';
          if (api.responseHeaders && Object.keys(api.responseHeaders).length > 0) {
            html += '<div class="section-title">Response Headers <button class="copy-btn" onclick="copyValue(window.__copyStore[\'' + copyIdResH + '\'], this)">Copy</button></div>';
            html += renderTable(api.responseHeaders);
          } else {
            html += '<div style="color: var(--text-secondary); font-size: 13px; font-style: italic;">No response headers</div>';
          }
          
          if (api.responseBody) {
            html += '<div class="section-title" style="margin-top: 12px;">Response Body <button class="copy-btn" onclick="copyValue(window.__copyStore[\'' + copyIdResB + '\'], this)">Copy</button></div>';
            html += '<pre>' + escapeHtml(resBodyStr) + '</pre>';
          } else {
            html += '<div style="margin-top: 12px; color: var(--text-secondary); font-size: 13px; font-style: italic;">No response body</div>';
          }
          html += '</div>';
          
          html += '</div>';
          item.innerHTML = html;
            
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
    function switchApiTab(index, tab) {
      document.querySelectorAll('#log-details-' + index + ' .api-tab-btn').forEach(btn => btn.classList.remove('active'));
      document.querySelectorAll('#log-details-' + index + ' .api-tab-content').forEach(content => content.classList.remove('active'));
      
      document.getElementById('api-btn-' + tab + '-' + index).classList.add('active');
      document.getElementById('api-tab-' + tab + '-' + index).classList.add('active');
    }

    function generateCurl(api) {
      let curl = "curl -X " + api.method + " '" + api.url + "'";
      if (api.requestHeaders) {
        for (const [key, value] of Object.entries(api.requestHeaders)) {
          curl += " -H '" + key + ": " + value + "'";
        }
      }
      if (api.requestBody) {
        let body = api.requestBody;
        if (typeof body === 'object') {
          body = JSON.stringify(body);
        }
        body = body.replace(/'/g, "'\''");
        curl += " -d '" + body + "'";
      }
      return curl;
    }

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
    
    // Delayed fallbacks for iOS Quick Look and sandboxed webviews
    recenterWorkspace();
    [50, 200, 500, 1000, 2000].forEach(ms => setTimeout(recenterWorkspace, ms));
  
  setTimeout(() => {
    showDetails(data.nodes[0]);
    console.log("showDetails executed successfully");
  }, 100);
