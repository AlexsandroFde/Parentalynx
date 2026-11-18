import '../../../../core/result/result.dart';
import '../entities/device_sync_result.dart';
import '../services/i_device_sync_service.dart';

/// Pede ao agente do aparelho da crianca que sincronize agora ("Sincronizar agora").
class TriggerDeviceSync {
  const TriggerDeviceSync(this._service);

  final IDeviceSyncService _service;

  Future<Result<DeviceSyncResult>> call() => _service.syncNow();
}
