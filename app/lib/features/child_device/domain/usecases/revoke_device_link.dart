import '../../../../core/result/result.dart';
import '../../../authentication/domain/usecases/run_elevated.dart';
import '../repositories/i_child_device_repository.dart';

/// Revoga o vinculo de um aparelho. Ele desativa o controle na proxima sincronizacao; o
/// historico continua guardado. Operacao administrativa.
class RevokeDeviceLink {
  const RevokeDeviceLink({required this._repository, required this._elevated});

  final IChildDeviceRepository _repository;
  final RunElevated _elevated;

  Future<Result<void>> call(String deviceId) async {
    final Result<void> result = await _elevated<void>(() => _repository.revoke(deviceId));
    if (result.isOk) {
      await _repository.refresh();
    }
    return result;
  }
}
