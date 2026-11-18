import '../../../../core/result/result.dart';
import '../entities/child_device.dart';
import '../repositories/i_child_device_repository.dart';

/// Busca a lista de aparelhos no servidor. Quem observa a lista recebe a versao nova.
class RefreshChildDevices {
  const RefreshChildDevices(this._repository);

  final IChildDeviceRepository _repository;

  Future<Result<List<ChildDevice>>> call() => _repository.refresh();
}
