import '../../domain/error_log_item.dart';

class ErrorLogController {
  final List<ErrorLogItem> _errors = [];
  int _nextId = 1;

  static const int _maxErrors = 50;

  List<ErrorLogItem> get errors => List.unmodifiable(_errors);
  int get count => _errors.length;

  void addError(String message, String stackTrace, String type, String screen) {
    _errors.insert(
      0,
      ErrorLogItem(
        id: _nextId++,
        message: message,
        stackTrace: stackTrace,
        type: type,
        timestamp: DateTime.now(),
        screen: screen,
      ),
    );
    if (_errors.length > _maxErrors) _errors.removeLast();
  }

  void renameSession(String oldScreen, String newScreen) {
    if (oldScreen == newScreen) return;
    for (int i = 0; i < _errors.length; i++) {
      final err = _errors[i];
      if (err.screen == oldScreen) {
        _errors[i] = ErrorLogItem(
          id: err.id,
          message: err.message,
          stackTrace: err.stackTrace,
          type: err.type,
          timestamp: err.timestamp,
          screen: newScreen,
        );
      }
    }
  }

  void clearAll() {
    _errors.clear();
  }
}
