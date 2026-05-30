import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dev_monitor/flutter_dev_monitor.dart';

void main() {
  runApp(const MyApp());
}

// ── Dio setup ────────────────────────────────────────────────────────────────

// 1. Add the interceptor to capture all API calls.
final dio = Dio(BaseOptions(baseUrl: 'https://jsonplaceholder.typicode.com'))
  ..interceptors.add(DevMonitor.interceptor);

// ── App root ─────────────────────────────────────────────────────────────────

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitor Example',
      debugShowCheckedModeBanner: false,
      // 2. These two params are all you need — no FpsOverlay wrapper required.
      navigatorObservers: [DevMonitor.observer],
      builder: DevMonitor.appBuilder,
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
    // 3. All API calls via this Dio instance are automatically captured.
    final res = await dio.get('/posts');
    setState(() {
      _posts = res.data as List;
      _loading = false;
    });
  }

  Future<void> _fetchComments() async {
    await dio.get('/comments?postId=1');
    await dio.get('/users/1');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Open Monitor Dashboard',
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
          : ListView.builder(
              itemCount: _posts.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(_posts[i]['title'] ?? ''),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: RouteSettings(
                      name: '/PostDetail/${_posts[i]['id']}',
                    ),
                    builder: (_) => PostDetailScreen(post: _posts[i]),
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _fetchComments,
        label: const Text('Fetch more'),
        icon: const Icon(Icons.refresh),
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
    final res = await dio.get('/comments?postId=${widget.post['id']}');
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
            child: Text(
              widget.post['title'] ?? '',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(widget.post['body'] ?? ''),
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Comments', style: TextStyle(fontWeight: FontWeight.bold)),
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
