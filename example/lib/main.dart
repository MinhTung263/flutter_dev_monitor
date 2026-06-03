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
            icon: const Icon(Icons.storage_outlined),
            tooltip: 'Local Lab',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/LocalLabScreen'),
                builder: (_) => const LocalLabScreen(),
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

// ── Mock singletons ───────────────────────────────────────────────────────────

class AppState {
  AppState._();
  static final AppState instance = AppState._();

  final List<String> _cart = [];

  void login(String userId) {
    DevMonitor.trackSingleton('AppState', 'userId', userId);
    DevMonitor.trackSingleton('AppState', 'isLoggedIn', 'true');
  }

  void logout() {
    DevMonitor.trackSingleton('AppState', 'userId', null);
    DevMonitor.trackSingleton('AppState', 'isLoggedIn', 'false');
  }

  void setTheme(String theme) {
    DevMonitor.trackSingleton('AppState', 'theme', theme);
  }

  void addToCart(String productId) {
    _cart.add(productId);
    DevMonitor.trackSingleton('AppState', 'cart', '${_cart.length} items');
  }

  void clearCart() {
    _cart.clear();
    DevMonitor.trackSingleton('AppState', 'cart', 'cleared (0 items)');
  }
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  void saveTokens(String access, String refresh) {
    DevMonitor.trackSingleton('AuthService', 'accessToken',
        '${access.substring(0, access.length.clamp(0, 12))}…');
    DevMonitor.trackSingleton('AuthService', 'refreshToken',
        '${refresh.substring(0, refresh.length.clamp(0, 12))}…');
  }

  void saveProfile(Map<String, dynamic> profile) {
    DevMonitor.trackSingleton(
        'AuthService', 'profile', 'id=${profile['id']} name=${profile['name']}');
  }

  void clearSession() {
    DevMonitor.trackSingleton('AuthService', 'accessToken', null);
    DevMonitor.trackSingleton('AuthService', 'profile', null);
  }
}

// ── Local Lab screen ──────────────────────────────────────────────────────────

class LocalLabScreen extends StatefulWidget {
  const LocalLabScreen({super.key});

  @override
  State<LocalLabScreen> createState() => _LocalLabScreenState();
}

class _LocalLabScreenState extends State<LocalLabScreen> {
  String _status = 'Tap a button to simulate a local storage operation.';

  void _act(String label, VoidCallback fn) {
    fn();
    setState(() => _status = '✓ $label logged → check LOCAL tab');
  }

  // ── SharedPreferences (simulated) ───────────────────────────────────────

  void _prefsReadToken() => _act('Read auth_token', () {
        DevMonitor.trackLocal(
            source: 'SharedPreferences', key: 'auth_token',
            value: 'eyJhbGciOi…');
      });

  void _prefsWriteOnboarding() => _act('Write onboarding_done', () {
        DevMonitor.trackLocal(
            source: 'SharedPreferences', key: 'onboarding_done',
            value: 'true');
      });

  void _prefsReadLocale() => _act('Read locale', () {
        DevMonitor.trackLocal(
            source: 'SharedPreferences', key: 'app_locale', value: 'vi_VN');
      });

  // ── Hive (simulated) ─────────────────────────────────────────────────────

  void _hiveGetProducts() => _act('Hive get products', () {
        DevMonitor.trackLocal(
            source: 'Hive', key: 'products', value: '42 items cached');
      });

  void _hivePutUser() => _act('Hive put user', () {
        DevMonitor.trackLocal(
            source: 'Hive', key: 'current_user', value: 'id=7 name=Nguyen Van A');
      });

  void _hiveGetCart() => _act('Hive get cart', () {
        DevMonitor.trackLocal(
            source: 'Hive', key: 'cart_items', value: '3 items · 250,000đ');
      });

  // ── SQLite (simulated) ───────────────────────────────────────────────────

  void _sqlSelectMessages() => _act('SQLite SELECT messages', () {
        DevMonitor.trackLocal(
            source: 'SQLite',
            key: 'SELECT * FROM messages WHERE thread_id=12',
            value: '18 rows');
      });

  void _sqlInsertOrder() => _act('SQLite INSERT order', () {
        DevMonitor.trackLocal(
            source: 'SQLite',
            key: 'INSERT INTO orders (user_id, total)',
            value: 'rowId=88');
      });

  // ── Singleton ────────────────────────────────────────────────────────────

  void _singletonLogin() => _act('AppState.login', () {
        AppState.instance.login('user_42');
      });

  void _singletonSetTheme() => _act('AppState.setTheme', () {
        AppState.instance.setTheme('dark');
      });

  void _singletonAddCart() => _act('AppState.addToCart', () {
        AppState.instance.addToCart('prod_${DateTime.now().second}');
      });

  void _singletonClearCart() => _act('AppState.clearCart', () {
        AppState.instance.clearCart();
      });

  void _authSaveTokens() => _act('AuthService.saveTokens', () {
        AuthService.instance.saveTokens(
            'eyJhbGciOiJSUzI1NiJ9.user42', 'rt_9f8e7d6c5b4a');
      });

  void _authSaveProfile() => _act('AuthService.saveProfile', () {
        AuthService.instance
            .saveProfile({'id': 42, 'name': 'Nguyen Van A', 'role': 'admin'});
      });

  void _authClear() => _act('AuthService.clearSession', () {
        AuthService.instance.clearSession();
        AppState.instance.logout();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Lab'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/MonitorDashboardPage'),
                builder: (_) => const MonitorDashboardPage(
                    initialScreen: '/LocalLabScreen'),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child:
                Text(_status, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader('Singleton'),
                _LabButton(
                  icon: Icons.login,
                  label: 'AppState.login()',
                  subtitle: 'userId + isLoggedIn → SINGLETON:APPSTATE',
                  color: const Color(0xFFA78BFA),
                  onTap: _singletonLogin,
                ),
                _LabButton(
                  icon: Icons.palette_outlined,
                  label: 'AppState.setTheme()',
                  subtitle: 'theme=dark → SINGLETON:APPSTATE',
                  color: const Color(0xFFA78BFA),
                  onTap: _singletonSetTheme,
                ),
                _LabButton(
                  icon: Icons.add_shopping_cart,
                  label: 'AppState.addToCart()',
                  subtitle: 'cart N items → SINGLETON:APPSTATE',
                  color: const Color(0xFFA78BFA),
                  onTap: _singletonAddCart,
                ),
                _LabButton(
                  icon: Icons.remove_shopping_cart_outlined,
                  label: 'AppState.clearCart()',
                  subtitle: 'cart cleared → SINGLETON:APPSTATE',
                  color: const Color(0xFFA78BFA),
                  onTap: _singletonClearCart,
                ),
                _LabButton(
                  icon: Icons.key_rounded,
                  label: 'AuthService.saveTokens()',
                  subtitle: 'accessToken + refreshToken → SINGLETON:AUTHSERVICE',
                  color: const Color(0xFFA78BFA),
                  onTap: _authSaveTokens,
                ),
                _LabButton(
                  icon: Icons.person_outline,
                  label: 'AuthService.saveProfile()',
                  subtitle: 'id + name + role → SINGLETON:AUTHSERVICE',
                  color: const Color(0xFFA78BFA),
                  onTap: _authSaveProfile,
                ),
                _LabButton(
                  icon: Icons.logout,
                  label: 'AuthService.clearSession()',
                  subtitle: 'tokens=null, profile=null, logout',
                  color: Colors.red,
                  onTap: _authClear,
                ),
                const SizedBox(height: 8),
                _SectionHeader('SharedPreferences'),
                _LabButton(
                  icon: Icons.vpn_key_outlined,
                  label: 'Read auth_token',
                  subtitle: 'getString(auth_token) → SHAREDPREFERENCES',
                  color: const Color(0xFF2DD4BF),
                  onTap: _prefsReadToken,
                ),
                _LabButton(
                  icon: Icons.check_circle_outline,
                  label: 'Write onboarding_done',
                  subtitle: 'setBool(onboarding_done, true)',
                  color: const Color(0xFF2DD4BF),
                  onTap: _prefsWriteOnboarding,
                ),
                _LabButton(
                  icon: Icons.language,
                  label: 'Read app_locale',
                  subtitle: 'getString(app_locale) → vi_VN',
                  color: const Color(0xFF2DD4BF),
                  onTap: _prefsReadLocale,
                ),
                const SizedBox(height: 8),
                _SectionHeader('Hive'),
                _LabButton(
                  icon: Icons.inventory_2_outlined,
                  label: 'Get products box',
                  subtitle: 'box.get(products) → 42 items cached',
                  color: const Color(0xFFFBBF24),
                  onTap: _hiveGetProducts,
                ),
                _LabButton(
                  icon: Icons.person_outline,
                  label: 'Put current_user',
                  subtitle: 'box.put(current_user, User{id=7})',
                  color: const Color(0xFFFBBF24),
                  onTap: _hivePutUser,
                ),
                _LabButton(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Get cart_items',
                  subtitle: 'box.get(cart_items) → 3 items',
                  color: const Color(0xFFFBBF24),
                  onTap: _hiveGetCart,
                ),
                const SizedBox(height: 8),
                _SectionHeader('SQLite'),
                _LabButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'SELECT messages',
                  subtitle: 'WHERE thread_id=12 → 18 rows',
                  color: const Color(0xFF60A5FA),
                  onTap: _sqlSelectMessages,
                ),
                _LabButton(
                  icon: Icons.receipt_long_outlined,
                  label: 'INSERT order',
                  subtitle: 'orders (user_id, total) → rowId=88',
                  color: const Color(0xFF60A5FA),
                  onTap: _sqlInsertOrder,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
