import '../../domain/error_log_item.dart';

class ErrorLogController {
  final List<ErrorLogItem> _errors = [];
  int _nextId = 1;

  static const int _maxErrors = 50;

  List<ErrorLogItem> get errors => List.unmodifiable(_errors);
  int get count => _errors.length;

  void addError(String message, String stackTrace, String type) {
    _errors.insert(
      0,
      ErrorLogItem(
        id: _nextId++,
        message: message,
        stackTrace: stackTrace,
        type: type,
        timestamp: DateTime.now(),
      ),
    );
    if (_errors.length > _maxErrors) _errors.removeLast();
  }

  void clearAll() {
    _errors.clear();
  }
}
