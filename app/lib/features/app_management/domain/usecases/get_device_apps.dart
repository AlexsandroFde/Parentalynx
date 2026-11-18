import '../../../../core/result/result.dart';
import '../entities/app_entry.dart';
import '../repositories/i_app_inventory_repository.dart';

/// Apps instalados em um aparelho (lista de regras, apps mais usados no painel).
class GetDeviceApps {
  const GetDeviceApps(this._repository);

  final IAppInventoryRepository _repository;

  Future<Result<DeviceApps>> call(String deviceId) => _repository.listApps(deviceId);
}
