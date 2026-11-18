import '../../../../core/result/result.dart';
import '../../../authentication/domain/usecases/run_elevated.dart';
import '../repositories/i_child_device_repository.dart';

/// Apaga o aparelho, as regras e todo o historico. Operacao administrativa.
class DeleteChildDevice {
  const DeleteChildDevice({required this._repository, required this._elevated});

  final IChildDeviceRepository _repository;
  final RunElevated _elevated;

  Future<Result<void>> call(String deviceId) async {
    final Result<void> result = await _elevated<void>(() => _repository.delete(deviceId));
    if (result.isOk) {
      await _repository.refresh();
    }
    return result;
  }
}
