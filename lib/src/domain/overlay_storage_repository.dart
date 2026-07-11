import 'overlay_state_entity.dart';

abstract class OverlayStorageRepository {
  Future<void> save(OverlayStateEntity state);
  Future<OverlayStateEntity?> load();
}
