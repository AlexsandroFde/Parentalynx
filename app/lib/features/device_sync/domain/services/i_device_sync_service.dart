import '../../../../core/result/result.dart';
import '../entities/device_sync_result.dart';

/// Sincronizacao do agente no aparelho da crianca.
abstract interface class IDeviceSyncService {
  /// Pede ao agente nativo que sincronize agora (politica, uso, eventos e pedidos).
  Future<Result<DeviceSyncResult>> syncNow();
}
