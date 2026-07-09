import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dev_monitor/flutter_dev_monitor.dart';
import '../services/dio_client.dart';

class ApiLabScreen extends StatefulWidget {
  const ApiLabScreen({super.key});

  @override
  State<ApiLabScreen> createState() => _ApiLabScreenState();
}

class _ApiLabScreenState extends State<ApiLabScreen> {
  String _status = 'Ready. Tap any action below to trigger an API request.';
  bool _busy = false;

  Future<void> _run(String label, Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _status = 'Executing: $label...';
    });
    try {
      await fn();
      setState(() => _status = 'Success: $label completed.');
    } catch (e) {
      setState(() => _status = 'Error: $label failed.\n$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  // ── Test calls ───────────────────────────────────────────────────────────

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

  Future<void> _getSingle() => _run('GET single user', () async {
        await dio.get('/users/1');
      });

  Future<void> _largeList() => _run('GET large list (100 posts)', () async {
        await dio.get('/posts');
      });

  Future<void> _slow() => _run('GET todos (slow)', () async {
        await dio.get(
          '/todos',
          queryParameters: {'userId': 1},
        );
      });

  Future<void> _postWithBody() => _run('POST create post', () async {
        await dio.post(
          '/posts',
          data: {
            'title': 'Monitor Test Post',
            'body': 'This is a test post created from flutter_dev_monitor example.',
            'userId': 1,
            'tags': ['flutter', 'monitor', 'test'],
            'meta': {'createdAt': '2025-01-01', 'version': '1.1.1'},
          },
        );
      });

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

  Future<void> _patch() => _run('PATCH partial update', () async {
        await dio.patch(
          '/posts/1',
          data: {'title': 'Patched title only'},
        );
      });

  Future<void> _delete() => _run('DELETE post', () async {
        await dio.delete('/posts/1');
      });

  Future<void> _postFormData() => _run('POST with FormData (File)', () async {
        final formData = FormData.fromMap({
          'name': 'mario',
          'age': '25',
          'file': MultipartFile.fromString(
            'Hello world this is a test file content!',
            filename: 'test_upload.txt',
          ),
          'avatar': MultipartFile.fromString(
            'fake image data',
            filename: 'avatar.png',
          ),
        });
        await dio.post(
          'https://httpbin.org/post',
          data: formData,
        );
      });

  Future<void> _notFound() => _run('GET 404 not found', () async {
        try {
          await dio.get('/posts/9999999');
        } on DioException {
          // expected
        }
      });

  void _triggerFlutterError() {
    throw StateError('Simulated Flutter UI Error: widget state crash!');
  }

  void _triggerAsyncDartError() {
    Future.delayed(Duration.zero, () {
      throw ArgumentError('Simulated Async Dart Error: background task failed!');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'API Request Lab',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.bar_chart_rounded, color: theme.colorScheme.primary, size: 20),
              tooltip: 'Open Monitor',
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
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Virtual Terminal Console ──
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A), // Slate 900
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Red/Orange/Green Window dots
                      _dot(Colors.red),
                      const SizedBox(width: 6),
                      _dot(Colors.amber),
                      const SizedBox(width: 6),
                      _dot(Colors.green),
                      const Spacer(),
                      // Pulse Status Dot
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _busy ? Colors.orange : Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _busy ? 'BUSY' : 'READY',
                        style: TextStyle(
                          color: _busy ? Colors.orange : Colors.green,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(height: 1, color: Colors.white10),
                  const SizedBox(height: 12),
                  Text(
                    _status,
                    style: const TextStyle(
                      color: Color(0xFF38BDF8), // Light blue
                      fontSize: 12,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Action Buttons List ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const _SectionHeader('GET Requests'),
                _LabButton(
                  icon: Icons.list_alt,
                  label: 'GET List with Query Params',
                  subtitle: '_limit=3 _page=2 _sort=id _order=desc',
                  color: const Color(0xFF3B82F6),
                  onTap: _busy ? null : _getWithQuery,
                ),
                _LabButton(
                  icon: Icons.person_outline,
                  label: 'GET Single Resource',
                  subtitle: '/users/1 — retrieves user data object',
                  color: const Color(0xFF3B82F6),
                  onTap: _busy ? null : _getSingle,
                ),
                _LabButton(
                  icon: Icons.format_list_numbered,
                  label: 'GET Large Payload List',
                  subtitle: '/posts — tests JSON parser limits',
                  color: const Color(0xFF3B82F6),
                  onTap: _busy ? null : _largeList,
                ),
                _LabButton(
                  icon: Icons.hourglass_bottom,
                  label: 'GET High-Latency Endpoint',
                  subtitle: '/todos?userId=1 — simulated slow route',
                  color: const Color(0xFF3B82F6),
                  onTap: _busy ? null : _slow,
                ),
                const SizedBox(height: 16),
                const _SectionHeader('Write Requests (Mutations)'),
                _LabButton(
                  icon: Icons.add_circle_outline,
                  label: 'POST Create Record',
                  subtitle: 'Send JSON payload body',
                  color: const Color(0xFF10B981),
                  onTap: _busy ? null : _postWithBody,
                ),
                _LabButton(
                  icon: Icons.edit_outlined,
                  label: 'PUT Update Record',
                  subtitle: '/posts/1 — replaces entire item structure',
                  color: const Color(0xFFF59E0B),
                  onTap: _busy ? null : _putUpdate,
                ),
                _LabButton(
                  icon: Icons.edit_note_outlined,
                  label: 'PATCH Partial Update',
                  subtitle: '/posts/1 — updates title field selectively',
                  color: const Color(0xFFF59E0B),
                  onTap: _busy ? null : _patch,
                ),
                _LabButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'DELETE Remove Record',
                  subtitle: '/posts/1 — deletes resource',
                  color: const Color(0xFFEF4444),
                  onTap: _busy ? null : _delete,
                ),
                _LabButton(
                  icon: Icons.cloud_upload_outlined,
                  label: 'POST Multi-part FormData',
                  subtitle: 'Send FormData fields and files to httpbin.org',
                  color: const Color(0xFF06B6D4),
                  onTap: _busy ? null : _postFormData,
                ),
                const SizedBox(height: 16),
                const _SectionHeader('Exceptions & Failures'),
                _LabButton(
                  icon: Icons.error_outline_rounded,
                  label: 'GET 404 Resource Not Found',
                  subtitle: '/posts/9999999 — forces error response',
                  color: const Color(0xFFEF4444),
                  onTap: _busy ? null : _notFound,
                ),
                _LabButton(
                  icon: Icons.bug_report_outlined,
                  label: 'Throw Unhandled UI Error',
                  subtitle: 'Causes a crash on Flutter framework layout',
                  color: const Color(0xFFDC2626),
                  onTap: _triggerFlutterError,
                ),
                _LabButton(
                  icon: Icons.bolt_rounded,
                  label: 'Throw Async Exception',
                  subtitle: 'Throws exception inside Future callback task',
                  color: const Color(0xFFDC2626),
                  onTap: _triggerAsyncDartError,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 12,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
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
    final disabled = onTap == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          child: Opacity(
            opacity: disabled ? 0.5 : 1.0,
            child: Row(
              children: [
                // Left Accent Line
                Container(
                  width: 5,
                  height: 64,
                  color: color,
                ),
                const SizedBox(width: 12),
                // Icon Container
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                // Texts
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Chevron
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: Colors.black26,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
