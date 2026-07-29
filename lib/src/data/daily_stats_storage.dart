import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../domain/daily_stat_item.dart';

/// Manages daily statistics data persistence using a rolling JSON file.
class DailyStatsStorage {
  static const String _fileName = 'dev_monitor_stats_24h.json';
  static const int _maxEntries = 10000;
  static const int _retentionMs = 86400000 * 3; // 3 days in milliseconds

  static String _encodeStatsCache(List<Map<String, dynamic>> data) {
    return jsonEncode(data);
  }

  List<DailyStatItem> _cache = [];
  final List<DailyStatItem> _pendingQueue = [];
  bool _loaded = false;
  File? _file;
  Timer? _debounceTimer;
  Completer<void>? _loadCompleter;

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final directory = Directory.systemTemp;
    _file = File('${directory.path}/$_fileName');
    return _file!;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    if (_loadCompleter != null) {
      return _loadCompleter!.future;
    }

    _loadCompleter = Completer<void>();
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(content);
          _cache = decoded
              .map((e) => DailyStatItem.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
      _loaded = true;
      if (_pendingQueue.isNotEmpty) {
        _cache.addAll(_pendingQueue);
        _pendingQueue.clear();
      }
      _pruneInMemory();
    } catch (_) {
      // Note: We do NOT set _loaded to true so we can retry on the next call.
    }
    _loadCompleter!.complete();
    _loadCompleter = null;
  }

  void _pruneInMemory() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final limit = now - _retentionMs;

    // Filter out items older than the retention period
    _cache = _cache.where((item) => item.timestamp >= limit).toList();

    // Cap the maximum number of entries to prevent massive files
    if (_cache.length > _maxEntries) {
      _cache = _cache.sublist(_cache.length - _maxEntries);
    }
  }

  /// Loads the statistics logs, prunes entries older than 24 hours, and returns them.
  Future<List<DailyStatItem>> loadAndPrune() async {
    // Flush any pending write first so we return the latest data
    await flush();
    await _ensureLoaded();
    _pruneInMemory();
    _saveToDiskDebounced();
    return List.unmodifiable(_cache);
  }

  /// Appends a new statistics item to the rolling log.
  Future<void> saveItem(DailyStatItem item) async {
    await _ensureLoaded();
    if (!_loaded) {
      _pendingQueue.add(item);
      return;
    }
    _cache.add(item);
    _saveToDiskDebounced();
  }

  void _saveToDiskDebounced() {
    if (!_loaded) return; // Never write to disk if the file wasn't loaded successfully
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () async {
      try {
        final file = await _getFile();
        _pruneInMemory();
        final data = _cache.map((e) => e.toMap()).toList();
        final content = await compute(_encodeStatsCache, data);
        await file.writeAsString(content);
      } catch (_) {}
    });
  }

  /// Forces any pending in-memory write to execute immediately.
  Future<void> flush() async {
    if (!_loaded) return;
    if (_debounceTimer?.isActive == true) {
      _debounceTimer?.cancel();
      try {
        final file = await _getFile();
        _pruneInMemory();
        final data = _cache.map((e) => e.toMap()).toList();
        final content = await compute(_encodeStatsCache, data);
        await file.writeAsString(content);
      } catch (_) {}
    }
  }

  /// Clears all statistics cache and deletes the persistent file.
  Future<void> clearAll() async {
    _debounceTimer?.cancel();
    _cache.clear();
    _pendingQueue.clear();
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
