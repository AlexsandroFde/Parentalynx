import '../../../../core/result/result.dart';
import '../../../authentication/domain/usecases/run_elevated.dart';
import '../repositories/i_child_device_repository.dart';

/// Apaga so o historico do aparelho (sessoes, eventos, navegacao). Operacao administrativa.
class DeleteChildDeviceData {
  const DeleteChildDeviceData({required this._repository, required this._elevated});

  final IChildDeviceRepository _repository;
  final RunElevated _elevated;

  Future<Result<void>> call(String deviceId) {
    return _elevated<void>(() => _repository.deleteData(deviceId));
  }
}
