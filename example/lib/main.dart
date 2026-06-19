import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dev_monitor/flutter_dev_monitor.dart';

void main() {
  runApp(const MyApp());
}

// ── Dio setup ────────────────────────────────────────────────────────────────

final dio = Dio(
  BaseOptions(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    headers: {
      'Authorization': 'Bearer fake-token-for-testing',
      'X-App-Version': '1.1.1',
      'Accept': 'application/json',
    },
  ),
)..interceptors.add(DevMonitor.interceptor);

// ── App root ─────────────────────────────────────────────────────────────────

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitor Example',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [DevMonitor.observer],
      builder: DevMonitor.builder(),
      home: const HomeScreen(),
    );
  }
}

// ── Home screen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _posts = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() => _loading = true);
    final res = await dio.get(
      '/posts',
      queryParameters: {'_limit': 10, '_page': 1},
    );
    setState(() {
      _posts = res.data as List;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_on),
            tooltip: 'Alignment Test',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/AlignmentTestScreen'),
                builder: (_) => const AlignmentTestScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.science_outlined),
            tooltip: 'API Lab',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/ApiLabScreen'),
                builder: (_) => const ApiLabScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Open Monitor',
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchPosts,
              child: ListView.builder(
                itemCount: _posts.length,
                itemBuilder: (_, i) => ListTile(
                  leading: CircleAvatar(child: Text('${_posts[i]['id']}')),
                  title: Text(_posts[i]['title'] ?? ''),
                  subtitle: Text('User ${_posts[i]['userId']}'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings:
                          RouteSettings(name: '/PostDetail/${_posts[i]['id']}'),
                      builder: (_) => PostDetailScreen(post: _posts[i]),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

// ── Post detail screen ────────────────────────────────────────────────────────

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  List<dynamic> _comments = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    final res = await dio.get(
      '/comments',
      queryParameters: {'postId': widget.post['id'], '_limit': 5},
    );
    setState(() => _comments = res.data as List);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Post ${widget.post['id']}')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.post['title'] ?? '',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(widget.post['body'] ?? ''),
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child:
                Text('Comments', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _comments.length,
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.comment),
                title: Text(_comments[i]['name'] ?? ''),
                subtitle: Text(_comments[i]['email'] ?? ''),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── API Lab screen ────────────────────────────────────────────────────────────

class ApiLabScreen extends StatefulWidget {
  const ApiLabScreen({super.key});

  @override
  State<ApiLabScreen> createState() => _ApiLabScreenState();
}

class _ApiLabScreenState extends State<ApiLabScreen> {
  String _status = 'Tap a button to fire an API call.';
  bool _busy = false;

  Future<void> _run(String label, Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _status = '⏳ $label…';
    });
    try {
      await fn();
      setState(() => _status = '✓ $label done.');
    } catch (e) {
      setState(() => _status = '✗ $label error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  // ── Test calls ───────────────────────────────────────────────────────────

  /// GET with query params → tests QUERY PARAMS tab
  Future<void> _getWithQuery() => _run('GET with query params', () async {
        await dio.get(
          '/posts',
          queryParameters: {
            '_limit': 3,
            '_page': 2,
            '_sort': 'id',
            '_order': 'desc',
          },
        );
      });

  /// GET single resource → small JSON response body
  Future<void> _getSingle() => _run('GET single user', () async {
        await dio.get('/users/1');
      });

  /// POST with JSON body → tests REQUEST BODY tab
  Future<void> _postWithBody() => _run('POST create post', () async {
        await dio.post(
          '/posts',
          data: {
            'title': 'Monitor Test Post',
            'body':
                'This is a test post created from flutter_dev_monitor example.',
            'userId': 1,
            'tags': ['flutter', 'monitor', 'test'],
            'meta': {'createdAt': '2025-01-01', 'version': '1.1.1'},
          },
        );
      });

  /// PUT with full body → tests REQUEST BODY + RESPONSE tabs
  Future<void> _putUpdate() => _run('PUT update post', () async {
        await dio.put(
          '/posts/1',
          data: {
            'id': 1,
            'title': 'Updated Title via Monitor',
            'body': 'Updated body content.',
            'userId': 1,
          },
        );
      });

  /// PATCH with partial body
  Future<void> _patch() => _run('PATCH partial update', () async {
        await dio.patch(
          '/posts/1',
          data: {'title': 'Patched title only'},
        );
      });

  /// DELETE → tests minimal response
  Future<void> _delete() => _run('DELETE post', () async {
        await dio.delete('/posts/1');
      });

  /// 404 → tests error state (red tile)
  Future<void> _notFound() => _run('GET 404 not found', () async {
        try {
          await dio.get('/posts/9999999');
        } on DioException {
          // expected
        }
      });

  /// Large list → tests response body truncation (25-item cap)
  Future<void> _largeList() => _run('GET large list (100 posts)', () async {
        await dio.get('/posts');
      });

  /// Slow endpoint (todos has ~200 items)
  Future<void> _slow() => _run('GET todos (slow-ish)', () async {
        await dio.get(
          '/todos',
          queryParameters: {'userId': 1},
        );
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Lab'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/MonitorDashboardPage'),
                builder: (_) => const MonitorDashboardPage(
                  initialScreen: '/ApiLabScreen',
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(_status, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader('GET'),
                _LabButton(
                  icon: Icons.list_alt,
                  label: 'GET with query params',
                  subtitle: '_limit=3 _page=2 _sort=id _order=desc',
                  color: Colors.blue,
                  onTap: _busy ? null : _getWithQuery,
                ),
                _LabButton(
                  icon: Icons.person,
                  label: 'GET single user',
                  subtitle: '/users/1 — full user object',
                  color: Colors.blue,
                  onTap: _busy ? null : _getSingle,
                ),
                _LabButton(
                  icon: Icons.format_list_numbered,
                  label: 'GET large list (100 items)',
                  subtitle: '/posts — tests body truncation at 25 items',
                  color: Colors.blue,
                  onTap: _busy ? null : _largeList,
                ),
                _LabButton(
                  icon: Icons.hourglass_bottom,
                  label: 'GET todos (slow-ish)',
                  subtitle: '/todos?userId=1 — 20 items',
                  color: Colors.blue,
                  onTap: _busy ? null : _slow,
                ),
                const SizedBox(height: 8),
                _SectionHeader('POST / PUT / PATCH / DELETE'),
                _LabButton(
                  icon: Icons.add_circle_outline,
                  label: 'POST create post',
                  subtitle: 'JSON body with nested object + array',
                  color: Colors.green,
                  onTap: _busy ? null : _postWithBody,
                ),
                _LabButton(
                  icon: Icons.edit,
                  label: 'PUT full update',
                  subtitle: '/posts/1 — full body replacement',
                  color: Colors.orange,
                  onTap: _busy ? null : _putUpdate,
                ),
                _LabButton(
                  icon: Icons.edit_note,
                  label: 'PATCH partial',
                  subtitle: '/posts/1 — title field only',
                  color: Colors.orange,
                  onTap: _busy ? null : _patch,
                ),
                _LabButton(
                  icon: Icons.delete_outline,
                  label: 'DELETE post',
                  subtitle: '/posts/1 — empty {} response',
                  color: Colors.red,
                  onTap: _busy ? null : _delete,
                ),
                const SizedBox(height: 8),
                _SectionHeader('Error cases'),
                _LabButton(
                  icon: Icons.error_outline,
                  label: 'GET 404 not found',
                  subtitle: '/posts/9999999 — red error tile',
                  color: Colors.red,
                  onTap: _busy ? null : _notFound,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.primary,
          )),
    );
  }
}

class _LabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _LabButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: onTap == null ? Colors.grey : color),
        title: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: onTap == null ? Colors.grey : null)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: Icon(Icons.chevron_right,
            color: onTap == null ? Colors.grey : Colors.grey[400]),
        onTap: onTap,
      ),
    );
  }
}

// ─── Alignment Test Screen ────────────────────────────────────────────────────

class AlignmentTestScreen extends StatelessWidget {
  const AlignmentTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alignment Test Lab'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Card(
              color: Colors.blueAccent,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Hold the FpsOverlay -> Expand it -> Tap the Grid button to toggle 8px/16px Grid or Crosshair. Check if the elements below are aligned.',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle('1. Horizontal Alignment (Standard 8px Grid)'),
            const SizedBox(height: 8),
            // Correctly aligned row
            const Text('Correctly aligned (16px start padding):', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                border: Border.all(color: Colors.green.withValues(alpha: 0.5), width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Container(width: 40, height: 40, color: Colors.green),
                  const SizedBox(width: 16),
                  const Text('Aligned Title', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  const Text('Right text', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Misaligned row (e.g. 13px padding, icon shifted by 3px)
            const Text('Misaligned (13px padding, icon shifted by 3px):', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.only(left: 13, right: 19, top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                border: Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Container(width: 40, height: 40, color: Colors.red),
                  const SizedBox(width: 19),
                  const Text('Lefthand Shifted Title', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5), // Vertical shift
                    child: Text('Shifted text', style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle('2. Vertical Grid (Center Guidelines)'),
            const SizedBox(height: 8),
            // Horizontal row of boxes that should center perfectly
            const Text('Perfect Center vs Offset Center:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: [
                  // Perfect Center
                  Container(
                    width: 200,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.5), width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Center(child: Text('Perfect Center')),
                  ),
                  const SizedBox(height: 8),
                  // Shifted Center
                  Transform.translate(
                    offset: const Offset(4, 0), // 4px off center
                    child: Container(
                      width: 200,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(child: Text('Offset Center (4px Right)')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle('3. Padding Verification (8px multiples)'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SpacingBox(label: '8px', size: 8, color: Colors.orange),
                _SpacingBox(label: '16px', size: 16, color: Colors.orange),
                _SpacingBox(label: '24px', size: 24, color: Colors.orange),
                _SpacingBox(label: '32px', size: 32, color: Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
    );
  }
}

class _SpacingBox extends StatelessWidget {
  final String label;
  final double size;
  final Color color;

  const _SpacingBox({required this.label, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
