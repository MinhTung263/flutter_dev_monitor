import '../domain/overlay_state_entity.dart';
import '../domain/overlay_storage_repository.dart';
import 'overlay_storage_datasource.dart';

class OverlayStorageRepositoryImpl implements OverlayStorageRepository {
  final OverlayStorageDatasource _datasource;

  OverlayStorageRepositoryImpl(this._datasource);

  @override
  Future<OverlayStateEntity?> load() async {
    try {
      final config = await _datasource.load();
      if (config == null) return null;

      // Parse grid mode safely
      GridMode gridMode = GridMode.off;
      if (config.gridModeIndex != null &&
          config.gridModeIndex! >= 0 &&
          config.gridModeIndex! < GridMode.values.length) {
        gridMode = GridMode.values[config.gridModeIndex!];
      }

      return OverlayStateEntity(
        top: config.top,
        left: config.left,
        positionInit: config.positionInit,
        isExpanded: config.isExpanded ?? false,
        gridMode: gridMode,
        isTucked: config.isTucked,
        tuckedLeft: config.tuckedLeft,
        wasExpandedBeforeTuck: config.wasExpandedBeforeTuck,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(OverlayStateEntity state) async {
    try {
      final config = OverlayConfig(
        top: state.top,
        left: state.left,
        positionInit: state.positionInit,
        isExpanded: state.isExpanded,
        gridModeIndex: state.gridMode.index,
        isTucked: state.isTucked,
        tuckedLeft: state.tuckedLeft,
        wasExpandedBeforeTuck: state.wasExpandedBeforeTuck,
      );
      await _datasource.save(config);
    } catch (_) {}
  }
}
