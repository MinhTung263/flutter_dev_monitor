import 'package:flutter/material.dart';
import '../../data/overlay_storage_datasource.dart';
import '../../data/overlay_storage_repository_impl.dart';
import '../../domain/overlay_state_entity.dart';
import '../../domain/overlay_storage_repository.dart';

class OverlayController extends ChangeNotifier {
  static final OverlayController instance = OverlayController._(
    OverlayStorageRepositoryImpl(OverlayStorageDatasource()),
  );

  final OverlayStorageRepository _repository;
  OverlayStateEntity _state = const OverlayStateEntity();
  bool _isInitialized = false;

  OverlayController._(this._repository) {
    _loadConfig();
  }

  OverlayStateEntity get state => _state;
  bool get isInitialized => _isInitialized;

  Future<void> _loadConfig() async {
    try {
      final loadedState = await _repository.load();
      if (loadedState != null) {
        _state = loadedState;
      }
    } catch (_) {
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _saveConfig() async {
    await _repository.save(_state);
  }

  void initializePosition(double top, double left) {
    if (_state.positionInit) return;
    _state = _state.copyWith(
      top: top,
      left: left,
      positionInit: true,
    );
    notifyListeners();
    _saveConfig();
  }

  void updatePosition(double top, double left) {
    _state = _state.copyWith(
      top: top,
      left: left,
    );
    notifyListeners();
  }

  void finalizePosition(double top, double left) {
    _state = _state.copyWith(
      top: top,
      left: left,
    );
    notifyListeners();
    _saveConfig();
  }

  void toggleGrid() {
    final nextGrid = switch (_state.gridMode) {
      GridMode.off => GridMode.margins,
      GridMode.margins => GridMode.grid8,
      GridMode.grid8 => GridMode.grid16,
      GridMode.grid16 => GridMode.crosshair,
      GridMode.crosshair => GridMode.off,
    };
    _state = _state.copyWith(gridMode: nextGrid);
    notifyListeners();
    _saveConfig();
  }

  void expand() {
    _state = _state.copyWith(isExpanded: true);
    notifyListeners();
    _saveConfig();
  }

  void collapse(double sw, double pillW, double edgeMargin) {
    _state = _state.copyWith(
      isExpanded: false,
      left: sw - pillW - edgeMargin,
    );
    notifyListeners();
    _saveConfig();
  }

  void tuck(bool left, double sw, double handleW) {
    _state = _state.copyWith(
      isTucked: true,
      tuckedLeft: left,
      isExpanded: false,
      wasExpandedBeforeTuck: _state.isExpanded,
      left: left ? 0.0 : sw - handleW,
    );
    notifyListeners();
    _saveConfig();
  }

  void untuck(double sw, double pillW, double expandedW, double edgeMargin,
      {double? dragX}) {
    final wasExpanded = _state.wasExpandedBeforeTuck;
    final targetW = wasExpanded ? expandedW : pillW;

    double targetLeft;
    if (dragX != null) {
      targetLeft =
          (dragX - targetW / 2).clamp(edgeMargin, sw - targetW - edgeMargin);
    } else {
      targetLeft = _state.tuckedLeft ? edgeMargin : sw - targetW - edgeMargin;
    }

    _state = _state.copyWith(
      isTucked: false,
      isExpanded: wasExpanded,
      left: targetLeft,
    );
    notifyListeners();
    _saveConfig();
  }

  void openDashboard(double top) {
    _state = _state.copyWith(
      isExpanded: false,
      top: top,
    );
    notifyListeners();
    _saveConfig();
  }
}
