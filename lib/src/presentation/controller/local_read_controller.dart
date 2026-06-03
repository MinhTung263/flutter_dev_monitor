import 'dart:convert';

import '../../domain/local_read_item.dart';

class LocalReadController {
  final List<LocalReadItem> _reads = [];
  int _nextId = 1;
  static const int _max = 100;
  static const int _maxValueChars = 10 * 1024; // 10 KB display cap

  List<LocalReadItem> get reads => List.unmodifiable(_reads);
  int get count => _reads.length;

  void add({
    required String source,
    required String key,
    dynamic value,
    required String screen,
    bool isWrite = false,
  }) {
    _reads.insert(
      0,
      LocalReadItem(
        id: _nextId++,
        source: source.toUpperCase(),
        key: key,
        value: _serialize(value),
        timestamp: DateTime.now(),
        screen: screen,
        isWrite: isWrite,
      ),
    );
    if (_reads.length > _max) _reads.removeLast();
  }

  static String? _serialize(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    try {
      if (v is Map || v is List) {
        final str = const JsonEncoder.withIndent('  ').convert(v);
        return str.length > _maxValueChars
            ? '${str.substring(0, _maxValueChars)}\n… (truncated)'
            : str;
      }
      return v.toString();
    } catch (_) {
      return v.toString();
    }
  }

  void clearAll() => _reads.clear();
}
