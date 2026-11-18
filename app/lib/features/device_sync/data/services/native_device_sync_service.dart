import '../../../../core/platform/native_api.g.dart';
import '../../../../core/platform/native_call.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/device_sync_result.dart';
import '../../domain/services/i_device_sync_service.dart';

/// Pede a sincronizacao ao agente nativo ([ChildAgentApi]).
class NativeDeviceSyncService implements IDeviceSyncService {
  const NativeDeviceSyncService(this._api);

  final ChildAgentApi _api;

  @override
  Future<Result<DeviceSyncResult>> syncNow() async {
    final Result<SyncOutcome> outcome = await callNative<SyncOutcome>(_api.syncNow);
    return outcome.map(
      (SyncOutcome value) =>
          DeviceSyncResult(ok: value.ok, atMs: value.atMs, errorCode: value.errorCode),
    );
  }
}
